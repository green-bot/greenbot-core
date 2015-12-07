# Description
#
# Session connects users with shell scripts.
# Author: howethomas
#

ShortUUID = require 'shortid'
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
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
  # Helper functions
  info = (text) ->
    robot.emit 'log', text

  genSessionKey = (msg) ->
    visitor_name(msg) + "_" + msg.message.room.toLowerCase()

  cleanText = (text) ->
    text.trim().toLowerCase()

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
    @active = []

    @findOrCreate: (hubotMsg) ->
      # All messages that come from the network end up here.
      session_name = genSessionKey(hubotMsg)
      session = @active[session_name]
      if session
        # We already have a session, so send it off.
        session.ingressMsg(msg_text hubotMsg)
      else
        # No session active. Kick one off.
        name = process.env.DEV_ROOM_NAME or hubotMsg.message.room.toLowerCase()
        keyword = cleanText(msg_text(hubotMsg))
        Rooms.findOne {name: name, keyword: keyword}, (err, room) ->
          info "Can't find #{name}:#{keyword}" if err
          if room
            info "Found room #{name}, starting session"
            new Session(hubotMsg, room)
          return if room or err

          # No room and keyword combination matched
          # Return the default if there's one.
          info 'No room/keyword found. Check for default'
          Rooms.findOne {name: name, default: true}, (err, room) ->
            if room
              info "Found room #{name}, starting session"
              new Session(hubotMsg, room)
            else
              info 'No default room, no matching keyword. Fail.'

    constructor: (@hubotMsg, @room) ->
      # The variables that make up a Session
      @transcript = []
      @user = @hubotMsg.user    # This is the user structure from hubot.
      @src = visitor_name(@hubotMsg)
      @sessionKey = genSessionKey(@hubotMsg)
      @sessionId = ShortUUID.generate()
      Session.active[@sessionKey] = @
      @automated = true
      @createSessionEnv()
      @startProcess()

    createSessionEnv: () ->
      if @isOwner()
        info "Running as the owner"
        if @room.test_mode is true
          @room.test_mode = false
          Db.update 'Rooms', @room.objectId,
            { test_mode: false }, (err, response) ->
            if err
              info "Error trying to turn off test mode : #{err}"
          @arguments  = @room.default_cmd.split(" ")
        else
          @arguments  = @room.owner_cmd.split(" ")
      else
        info "Running as a visitor"
        @arguments  = @room.default_cmd.split(" ")
      @command = @arguments[0]
      @arguments.shift()
      @env = @cmdSettings()
      @env.INITIAL_MSG = cleanText(msg_text(@hubotMsg))
      @opts =
        cwd: @room.default_path
        env: @env

    startProcess: () ->
      # All setup, we now spawn the process.
      @process = ChildProcess.spawn(@command, @arguments, @opts)
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

    information: () ->
      transcript:     @transcript
      src:            @src
      sessionKey:     @sessionKey
      sessionId:      @sessionId
      roomId:         @room.objectId
      collectedData:  @collectedData

    endSession: () ->
      info "Ending and recording session #{@sessionId}"
      robot.emit 'session:ended', @sessionId
      delete Session.active[@sessionKey]

    cmdSettings: () ->
      env_settings = _.clone(process.env)
      env_settings.sessionId = @sessionId
      env_settings.SRC = @src
      env_settings.DST = @room.name
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
            info "#{@sessionId}: #{@room.name}: #{line}"
            @transcript.push { direction: 'egress', text: line}
            @updateDb()

    ingressMsg: (text) =>
      if cleanText(text) == '/human'
        @automated = false
        robot.emit 'livechat:newsession', @information()
      if @automated
        @process.stdin.write("#{text}\n")
      else
        robot.emit 'livechat:ingress', @information(), text
      @transcript.push { direction: 'ingress', text: text}
      info "#{@sessionId}: #{@src}: #{text}"
      @updateDb()

  robot.hear /(.*)/i, (msg) ->
    Session.findOrCreate(msg)

  robot.on 'livechat:egress', (sessionKey, text) ->
    console.log "Received #{text} for #{sessionKey}"
