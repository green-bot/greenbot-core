# Description
#
# Session connects users with shell scripts. All inbound messages are handled by
# this script, and each inbound message is sent to an arbitrary unix shell
# script for handling. When a user sends his first message, Session will create
# a new process and run the specified script, saving pointers to stdin, stdout
# and stderr. Session will then pass this message into the script through stdin.
# Any more messages from that user will be passed into the same script. If the
# script sends messages back out, this script will forward those to the original
# user. When the script ends, the session will also end, and the first new
# message from that user will create a new session. Every session is identified
# by a unique short session_id; scripts that write data to a JSON file with that
# will be collected by this script. # As a convenience, and for further
# processing, Session will emits events to handle session life cycle (start and
# finish), messaging in the session (stdin, stdout, stderr) and listen for any
# JSON file and emit that as an event as well. # Configuration: command_path:
# The default path of the file to be executed. command: The command line to
# execute # Notes: - This script will listen for all messages, and disregards
# any naming of the bot, etc. In short, I don't think it will play all that well
# with other scripts. YMMV
# Author: howethomas
#

ShortUUID = require 'shortid'
Redis = require "redis"
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
Request = require("request")
Mailer = require("nodemailer")
Moment = require("moment")
Us = require("underscore.string")
Parse = require('node-parse-api').Parse
Async = require('async')
BitlyAPI = require('node-bitlyapi')

module.exports = (robot) ->
  robot.sessions = {}
  redis_client = Redis.createClient()
  options =
    app_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI"
    api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7"
  parse = new Parse(options)
  Bitly = new BitlyAPI(
    client_id: 'a491e6dd824dd4f070fd810898e939fcb583028b'
    client_secret: '7478c375e2e2b96df5ce7d05178e3ff8cc2bd61e'
  )
  Bitly.setAccessToken('dae862bf86adea3e7f950f8bc1239ca6d75cdac1')

  class Session
    STR_PAD_LEFT = 1
    STR_PAD_RIGHT = 2
    STR_PAD_BOTH = 3

    constructor: (message, room, @visitor, @visitor_settings)->
      # The variables that make up a Session
      @user = message.user    # This is the user structure from hubot.
      @src = @user.name.toLowerCase()
      @room_name = message.room.toLowerCase() # this is a string.
      @session_key = @src + "_" + @room_name
      @session_id = ShortUUID.generate()
      @room = room
      @command_path = @room.default_path
      @arguments = @assemble_args()
      @log "Running #{@arguments}"

      # @arguments is an array of words, the first one is the command. Like ruby
      # The rest are parameters, and we send them down as an array.
      @command = @arguments[0]
      @arguments.shift()
      @env = @command_settings()
      # send the inital message to the script
      @env.INITIAL_MESSAGE = message
      opts =
        cwd: @command_path
        env: @env

      # All setup, we now spawn the process.
      @process = ChildProcess.spawn(@command, @arguments, opts)

      # Setup callbacks for incoming data
      @process.stdout.on "data", (buffer) => @handle_incoming_msg(buffer)
      @process.on "exit", (code, signal) => @end_session()
      @process.on "error", (err) ->
        @log "Error thrown from session"
        @log err
      @process.stderr.on "data", (buffer) =>
        @log "Received from stderr #{buffer}"

      # Tell the world that the blessed event has occured
      robot.emit "session:start", @

    assemble_args: () ->
      if @is_owner()
        @log "Running as the owner"
        if @room.test_mode is true
          @room.test_mode = false
          parse.update 'Rooms', @room.objectId,
            { test_mode: false }, (err, response) ->
            if err
              @log "Error trying to turn off test mode : #{err}"
          args = @room.default_cmd.split(" ")
        else
          args = @room.owner_cmd.split(" ")
      else
        args = @room.default_cmd.split(" ")
      return args

    log: (text) ->
      robot.emit "log", "#{@session_id}:#{text}"

    describe: () =>
      @log "Describing session : #{@session_id}"
      @log "ID: #{@process.pid}"
      @log "NAME: #{@process.title}"
      @log "UPTIME: #{@process.uptime}"

    end_session: () =>
      @log "Ending and recording session #{@session_id}"
      Async.series([
        @send_goodbye,
        @delete_session])

    send_goodbye: (callback) =>
      if @room.show_ad == true
        base_link = @room.goodbye_link or "http://www.justkisst.me"
        url = Url.parse(base_link, true)
        url.query["src"] = @src
        url.query["dst"] = @room_name
        url.query["session_id"] = @session_id
        url.query["reseller"] = @room.reseller

        @log "Using the closing link #{Url.format(url)}"
        Bitly.shortenLink encodeURIComponent(Url.format(url)), (err, results) =>
          @log "Shortened info is #{results}"
          throw err if err
          short_url = JSON.parse(results).data.url
          # Do something with data
          @handle_incoming_msg(@room.closing_message + short_url)
          callback(null, "Saved object")
      else
        callback(null, "No goodbyes")

    delete_session: (callback) =>
      delete robot.sessions[@session_key]
      robot.emit "session:end", @session_key
      #Add the collected data. That's a great idea.
      @log "Session ended. Who do we have to tell?"
      if @room.webhook_url?
        @log "Completed. Notifying #{session.room.webhook_url}"
        Request.post(@room.webhook_url).form(session)
          .on 'response', (response) ->
            @log response.statusCode
            @log response.headers['content-type']
      else
        @log "No webhook_url"
        @log JSON.stringify @room

      if @room.notification_emails?
        # Create a SMTP transporter object
        @log "Sending notification email"
        transporter = Mailer.createTransport(
          service: "gmail"
          auth:
            user: @room.mail_user
            pass: @room.mail_pass
        )
        # Message object
        recipients = @room.notification_emails.join(",")
        message =
          from: @room.mail_user
          to: recipients
          subject: "Conversation Complete"
          text: @transcript

        @log "Sending Mail to #{recipients}"
        transporter.sendMail message, (error, info) =>
          if error
            @log "Error occurred"
            @log error.message
            return
          @log "Message sent successfully!"
          @log "Server responded with \"%s\"", info.response
          return
      callback(null, "No goodbyes")

    command_settings: () ->
      env = process.env
      env.SESSION_ID = @session_id
      env.SRC = @src
      env.DST = @user.room
      for attrname of @room.settings
        env[attrname] = @room.settings[attrname]
      # for key, value of @visitor_settings
      #  env[key] = value
      @log "Settings: #{JSON.stringify env}"
      return env

    is_owner: () ->
      @log "Thinking I'm #{@src}"
      if @room.owners? and @src in @room.owners
        true
      else
        false

    is_json_string: (str) ->
      # When a text message comes from a session, if it's a valid JSON
      # string, we will treat it as a command or data. This function
      # allows us to figure that out.
      try
        JSON.parse str
      catch e
        return false
      true


    handle_incoming_msg: (text) =>
      # If the message is JSON, treat it as if it were collected data
      # If so, stick it in a session_id in REDIS for somebody else to handle.

      @log "Working with #{text}"
      lines = text.toString().split("\n")
      for line in lines
        line = line.trim()
        if @is_json_string line
          msg =
            session:  @
            collected_data:     line
          robot.emit "session:data", msg
        else
          # It's not JSON, gotta be a message.
          # because this might be a throttled service, we put this message in an
          # array that holds the outbound messages.  Peridoically,
          # and for a service
          # like Nexmo, this is a one message per second rate.
          if line.length > 0
            robot.send @user, line
            robot.emit "session:egress_msg",
                session: @
                text: line

    send_cmd_to_session: (cmd ) =>
      log "Error cmd #{cmd} to a disconnected session" if @process.connected
      @describe
      @process.stdin.write("#{cmd}\n")
      robot.emit("session:inbound_msg", @, cmd)

  create_session = (msg, room, visitor, visitor_settings) ->
    new_session = new Session(msg.message, room, visitor, visitor_settings)
    robot.sessions[new_session.session_key] = new_session


  robot.hear /(.*)/i, (msg) ->
    visitor_name = msg.message.user.name.toLowerCase()
    room_name = msg.message.room.toLowerCase()
    session_key =  visitor_name + "_" + room_name
    robot.emit "log", "Looking for existing session #{session_key}"
    session = robot.sessions[session_key]
    clean_text = msg.message.text.trim().toLowerCase()
    if session
      switch clean_text
        when "/quit"
          session.process.kill("SIGHUP")
        else
          robot.emit "log", "Sending #{msg.message.text}"
          robot.emit "session:ingress_msg",
              session: session
              text: msg.message.text

          session.send_cmd_to_session(msg.message.text)
    else
      # This is a new session. See if there are settings defined for it.
      # If there are not, then create an empty template for this room
      # That allows the named owner the ability to set it up.
      robot.emit "log", "Starting a new session"
      visitor_settings = {}
      visitor = null

      Async.series [
        (callback) ->
          parse.findMany 'Visitors', { where: {name: visitor_name }}, (err, response) ->
            visitors = response.results
            robot.emit "log", "Visitors :#{ JSON.stringify response.results}"
            if visitors.length == 0
              # This is a new visitor. Make him
              visitor_data =
                name: visitor_name
                anonymous: false
              parse.insert 'Visitors', visitor_data, (err, response) ->
                visitor = response.results
                robot.emit "log", "New visitor : #{JSON.stringify visitor}"
                callback null, true
            else
              visitor = visitors[0]
              robot.emit "log", "Returning visitor : #{JSON.stringify visitor}"
              parse.findMany 'VisitorData',
                visitor:
                  __type: "Pointer"
                  className: "Visitors"
                  objectId: visitor.objectId
                , (err, response) ->
                  if err
                    robot.emit "log", "Setting error : #{err}"
                  else
                    settings = response.results
                    robot.emit "log", "Settings: #{JSON.stringify settings}"
                    for setting in settings
                      visitor_settings[setting.key] = setting.value
                  callback null, true
        , (callback) ->
          parse.findMany 'Rooms', { where: {name: room_name}}, (err, response) ->
            rooms = response.results
            robot.emit "log", "Found rooms : #{JSON.stringify rooms}"
            # We support /commands on startup as well.
            # If they say /help, or /rooms, give them a list of them
            help_commands = ["help", "?", "rooms", "/help", "/rooms"]
            if clean_text in help_commands
              avail_rooms = (room.keyword for room in rooms)
              msg.reply "Supported options: #{avail_rooms.toString()}"
              return
            if err or (rooms.length == 0)
              robot.emit "log", "Cannot setup room - no room defined"
            else
              keywords = (room.keyword for room in rooms)
              robot.emit "log", "Found keywords: #{keywords} for #{clean_text}"
              if clean_text in keywords
                room = (room for room in rooms when room.keyword is clean_text)
                robot.emit "log", "Found room #{room.desc} for #{clean_text}"
              unless room?
                # No room matched. Use the default room
                room = (room for room in rooms when room.default)
              unless room?
                # No default room? Take the first room we found.
                room = rooms[0]
              robot.emit "log", "Found room #{room.name}"
              create_session(msg, room, visitor, visitor_settings)
      ]

  robot.on "session:chat_arrived", (session_key, chat_msg) ->
    session = robot.sessions[session_key]
    session.handle_incoming_msg(chat_msg)
