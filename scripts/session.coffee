# Description
#
# Session connects users with shell scripts.
# Author: howethomas
#

ShortUUID = require 'shortid'
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
Request = require("request")
Mailer = require("nodemailer")
Us = require("underscore.string")
Async = require('async')
_ = require('underscore')
Events = require('events')
Util = require('util')

connectionString = process.env.MONGO_URL or 'localhost/greenbot'
Db = require('monk')(connectionString)
Rooms = Db.get('Rooms')
Sessions = Db.get('Sessions')


module.exports = (robot) ->
  robot.sessions = {}

  # Helper functions
  info = (text) ->
    robot.emit 'log', text

  robot_emit = (key, text) ->
    robot.emit key, text

  respToHelp = (msg) ->
    info "Handle helpish message #{JSON.stringify msg.message}"

  genSessionKey = (msg) ->
    visitor_name(msg) + "_" + msg.message.room.toLowerCase()

  cleanText = (msg) ->
    msg_text(msg).trim().toLowerCase()

  msg_text = (msg) ->
    msg.message.text

  visitor_name = (msg) ->
    msg.message.user.name.toLowerCase()

  sessionUpdate = Async.queue (session, callback) ->
    q = { sessionId: session.sessionId }
    update = session.information()
    opts = { upsert: true }
    Sessions.findAndModify(q,update,opts).then (err, session) ->
      info "Threw error on database update #{util.inspect err}" if err
      callback()


  class Session
    constructor: (initial_msg, room, robot)->
      # The variables that make up a Session
      @transcript = []
      @user = initial_msg.user    # This is the user structure from hubot.
      @src = visitor_name(initial_msg)
      @roomName = room.name
      @sessionKey = genSessionKey(initial_msg)
      @sessionId = ShortUUID.generate()
      @room = room
      @commandPath = @room.default_path
      @arguments = @assembleArgs()
      @command = @arguments[0]
      @arguments.shift()
      @initialMsg = cleanText(initial_msg)
      @env = @cmdSettings()
      @env.INITIAL_MSG = @initialMsg
      opts =
        cwd: @commandPath
        env: @env

      # All setup, we now spawn the process.
      @process = ChildProcess.spawn(@command, @arguments, opts)
      @process.stdout.on "data", (buffer) => @egressMsg(buffer)
      @process.on "exit", (code, signal) => @endSession()
      @process.on "error", (err) ->
        info "Error thrown from session"
        info err
      @process.stderr.on "data", (buffer) ->
        info "Received from stderr #{buffer}"

      # Now save it in the database
    updateDb: () ->
      sessionUpdate.push @

    assembleArgs: () ->
      if @isOwner()
        info "Running as the owner"
        if @room.test_mode is true
          @room.test_mode = false
          Db.update 'Rooms', @room.objectId,
            { test_mode: false }, (err, response) ->
            if err
              info "Error trying to turn off test mode : #{err}"
          args = @room.default_cmd.split(" ")
        else
          args = @room.owner_cmd.split(" ")
      else
        info "Running as a visitor"
        args = @room.default_cmd.split(" ")
      return args

    information: () ->
      transcript:     @transcript
      src:            @src
      roomName:       @roomName
      sessionKey:     @sessionKey
      sessionId:      @sessionId
      commandPath:    @commandPath
      arguments:      @arguments
      roomId:         @room.objectId
      collectedData:  @collectedData

    endSession: () =>
      info "Ending and recording session #{@sessionId}"
      robot.emit 'session:ended', @sessionId
      delete robot.sessions[@sessionKey]

    cmdSettings: () ->
      env_settings = _.clone(process.env)
      env_settings.sessionId = @sessionId
      env_settings.SRC = @src
      env_settings.DST = @roomName
      env_settings.ROOM_OBJECT_ID = @room.objectId
      for attrname of @room.settings
        env_settings[attrname] = @room.settings[attrname]
      return env_settings

    isOwner: () ->
      if @room.owners? and @src in @room.owners
        info "Running session #{@sessionId} as the owner"
        true
      else
        info "Running session #{@sessionId} as a visitor"
        false

    isJson: (str) ->
      # When a text message comes from a session, if it's a valid JSON
      # string, we will treat it as a command or data. This function
      # allows us to figure that out.
      try
        JSON.parse str
      catch e
        return false
      true


    egressMsg: (text) =>
      lines = text.toString().split("\n")
      for line in lines
        line = line.trim()
        if @isJson line
          # If the message is JSON, treat it as if it were collected data
          @collectedData = JSON.parse line
          @updateDb()
        else
          # It's not JSON, gotta be a message.
          if line.length > 0
            robot.send @user, line
            @transcript.push { direction: 'egress', text: line}
            @updateDb()

    ingressMsg: (text) =>
      @process.stdin.write("#{text}\n")
      @transcript.push { direction: 'ingress', text: text}
      @updateDb()

  createSession = (msg, room, robot) ->
    new_session = new Session(msg, room, robot)
    robot.sessions[new_session.sessionKey] = new_session

  robot.hear /(.*)/i, (msg) ->
    # All messages that come from the network end up here.
    session_name = genSessionKey(msg)
    session = robot.sessions[session_name]
    if session
      session.ingressMsg(msg_text msg)
      return

    # If this is a command to handle the directory, handle it.
    helpCmds = ["help", "?", "rooms", "/help", "/rooms"]
    if  msg in helpCmds
      respToHelp msg
      return

    name = msg.message.room.toLowerCase()
    keyword = cleanText(msg)
    Rooms.findOne {name: name, keyword: keyword}, (err, room) ->
      if err
        info "Can't find #{name}:#{keyword}"
        return
      if room
        info "Found room #{roomName msg}, starting session"
        createSession msg, room, robot
        return
      # No room and keyword combination matched
      # Return the default if there's one.
      info 'No room/keyword found. Check for default'
      Rooms.findOne {name: name, default: true}, (err, room) ->
        if room
          info "Found room #{name}, starting session"
          createSession msg, room, robot
          return
        else
          info 'No default room, no matching keyword. Fail.'
