# Description
#
# Session connects users with shell scripts. All inbound messages are handled by this
# script, and each inbound message is sent to an arbitrary unix shell script for handling.
# When a user sends his first message, Session will create a new process and run the
# specified script, saving pointers to stdin, stdout and stderr. Session will then pass
# this message into the script through stdin. Any more messages from that user will be
# passed into the same script. If the script sends messages back out, this script will
# forward those to the original user. When the script ends, the session will also end,
# and the first new message from that user will create a new session. Every session
# is identified by a unique short session_id; scripts that write data to a JSON file with that
# will be collected by this script.
#
# As a convenience, and for further processing, Session will emits events to handle
# session life cycle (start and finish), messaging in the session (stdin, stdout, stderr)
# and listen for any JSON file and emit that as an event as well.
#
#  Configuration:
#    command_path: The default path of the file to be executed.
#    command: The command line to execute
#
# Notes:
#   - This script will listen for all messages, and disregards any naming of the bot, etc.
#     In short, I don't think it will play all that well with other scripts. YMMV
#
# Author:
#   howethomas
#
#
Readline = require 'readline'
ShortUUID = require 'shortid'
Redis = require "redis"
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
Request = require("request")
Mailer = require("nodemailer")
Moment = require("moment")
Us = require("underscore.string")
Wellknown = require("nodemailer-wellknown")

module.exports = (robot) ->
  robot.sessions = {}
  redis_client = Redis.createClient()

  class Session
    STR_PAD_LEFT = 1
    STR_PAD_RIGHT = 2
    STR_PAD_BOTH = 3

    constructor: (message, settings)->
      # The variables that make up a Session
      @user = message.user    # This is the user structure from hubot.
      @room = message.room.toLowerCase() # this is a string.
      @session_key = @user.name.toLowerCase() + "_" + @room
      @session_id = ShortUUID.generate()
      @transcript_key = "session_transcript:#{@session_id}"
      @data_key = "session_data:#{@session_id}"
      @settings_key = "room:#{@room}"
      @transcript = ""
      @settings = settings
      @command_path = @settings.default_path

      # There are generally two different people who text in
      # The first is the owner of the number, and he is
      # texting into the system to configure it.
      # The second are the customers, who are there to use it.
      if @is_owner()
        console.log "Running as the owner"
        if @settings.test_mode is "true"
          @settings.test_mode = "false"
          redis_client.set @settings_key, JSON.stringify @settings
          @arguments = @settings.default_cmd.split(" ")
        else
          @arguments = @settings.owner_cmd.split(" ")
      else
        @arguments = @settings.default_cmd.split(" ")

      console.log "Running #{@arguments}"

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
      @process.stderr.on "data", (buffer) => @handle_incoming_msg(buffer)
      @process.on "exit", (code, signal) =>
        for k,v of JSON.parse @collected_data
          @record_transcript "collected_data", "#{k}:#{v}"
        @add_session_to_list("ENDED_SESSION", @session_id)
        delete robot.sessions[@session_key]
        robot.emit "conversation_ended", @
        console.log "Session instance #{@session_id} for #{@session_key} has ended."

      # Add this session session_id to the started session list
      @add_session_to_list("STARTED_SESSION", @session_id)

      # Tell the world that the blessed event has occured
      robot.emit "conversation_started", @

    command_settings: () ->
      env = process.env
      env.SESSION_ID = @session_id
      env.SRC = @user.name
      env.DST = @user.room
      for attrname of @settings.settings
        env[attrname] = @settings.settings[attrname]
      return env

    is_owner: () ->
      console.log "Thinking I'm #{@user.name}"
      if @settings.owners? and @user.name in @settings.owners
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

    add_session_to_list: (list_session_id, session_session_id) ->
      redis_client.sadd(list_session_id, session_session_id)


    record_transcript:  (src, line) ->
      #Update the transcript
      line = "#{Moment().format('lll')}|#{@pad(src, 15, ' ', STR_PAD_LEFT)}|#{line}\n"
      @transcript += line
      redis_client.set(@transcript_key, @transcript)

    handle_incoming_msg: (text) =>
      # If the message is a valid JSON object, treat it as if it were collected data
      # If so, stick it in a session_id in REDIS for somebody else to handle.
      lines = text.toString().split("\n")
      for line in lines
        line = line.trim()
        if @is_json_string(line)
          redis_client.set @data_key, line
          @collected_data = line
        else
          # It's not JSON, gotta be a message.
          # because this might be a throttled service, we put this message in an
          # array that holds the outbound messages.  Peridoically, and for a service
          # like Nexmo, this is a one message per second rate.
          if line.length > 0
            robot.send @user, line
            @record_transcript("bot", line)

    send_cmd_to_session: (cmd ) =>
      @process.stdin.write("#{cmd}\n")
      @record_transcript(@user.name, cmd)

    pad: (str, len, pad, dir) ->
      if typeof len == 'undefined'
        len = 0
      if typeof pad == 'undefined'
        pad = ' '
      if typeof dir == 'undefined'
        dir = STR_PAD_RIGHT
      if len + 1 >= str.length
        switch dir
          when STR_PAD_LEFT
            str = Array(len + 1 - str.length).join(pad) + str
          when STR_PAD_BOTH
            right = Math.ceil((padlen = len - str.length) / 2)
            left = padlen - right
            str = Array(left + 1).join(pad) + str + Array(right + 1).join(pad)
          else
            str = str + Array(len + 1 - str.length).join(pad)
            break
        # switch
      str

 #end Session Class

  create_session = (msg, settings) ->
    new_session = new Session(msg.message, JSON.parse(settings))
    console.log "Created new session #{new_session.session_key} with session_id #{new_session.session_id}"
    robot.sessions[new_session.session_key] = new_session


  robot.hear /(.*)/i, (msg) =>
    session_key = msg.message.user.name.toLowerCase() + "_" + msg.message.room.toLowerCase()
    session = robot.sessions[session_key]
    if session
      session.send_cmd_to_session(msg.message.text)
    else
      # This is a new session. See if there are settings defined for it.
      # If there are not, then create an empty template for this room
      # That allows the named owner the ability to set it up.
      settings_key =  "room:#{msg.message.room.toLowerCase()}"

      # Fetch the settings for this session from Redis.
      # Settings are defined per room.
      redis_client.get settings_key, (err, settings) =>
        if not settings
          console.log "Cannot setup room - no room:template defined"
          return
        else
          create_session(msg, settings)

  robot.on "conversation_ended", (session) =>
      #Add the collected data. That's a great idea.
      if session.settings.webhook_url?
        console.log "Completed. Notifying #{session.settings.webhook_url}"
        Request.get "#{session.settings.webhook_url}?session_id=#{session.session_id}", null,
          (error, response, body) =>
            if error
              console.log "Webhook returned error"
              console.log body
              console.log error
      if session.settings.notification_emails?
        # Create a SMTP transporter object
        transporter = Mailer.createTransport(
          service: "gmail"
          auth:
            user: session.settings.mail_user
            pass: session.settings.mail_pass
        )
        # Message object
        message =
          from: session.settings.mail_user
          to: session.settings.notification_emails.join(",")
          subject: "Conversation Complete"
          text: session.transcript

        console.log "Sending Mail"
        transporter.sendMail message, (error, info) ->
          if error
            console.log "Error occurred"
            console.log error.message
            return
          console.log "Message sent successfully!"
          console.log "Server responded with \"%s\"", info.response
          return
