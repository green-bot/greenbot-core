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

module.exports = (robot) ->
  robot.sessions = {}
  redis_client = Redis.createClient()

  class Session
    constructor: (message)->
      @user = message.user
      @room = message.room.toLowerCase()
      @session_name = @user.name.toLowerCase() + "_" + @room
      @session_id = ShortUUID.generate()
      @transcript_key = "session_transcript:#{@session_id}"
      @data_key = "session_data:#{@session_id}"
      @settings_key = "room:#{@room}"
      @transcript = ""
      
      # Fetch the settings for this session from Redis.
      # Settings are defined per room.
      redis_client.get @settings_key, (err, settings) =>
        #Need to do a better job of handling this error condition
        #FIX
        if not settings
          console.log "Did not find settings!"
          return
        else
          console.log "Settings: #{settings}"

        # Prepare the settings, start the process.
        @settings = JSON.parse settings.toString()
        @command_path = @settings.default_path
        if @isOwner()
          if @settings.test_mode = "true"
            @arguments = @settings.default_cmd.split(" ")
            @settings.test_mode = "false"
            redis_client.set @settings_key, JSON.stringify(@settings, null, 2)
          else
            @arguments = @settings.owner_cmd.split(" ")
        else
          @arguments = @settings.default_cmd.split(" ")

        @command = @arguments[0]
        @arguments.shift()
        @env = @commandSettings()
        # send the inital message to the script
        @env.INITIAL_MESSAGE = message
        opts = 
          cwd: @command_path
          env: @env
        @process = ChildProcess.spawn(@command, @arguments, opts)

        # Setup callbacks for incoming data
        @process.stdout.on "data", (buffer) => @handle_incoming_msg(buffer)
        @process.stderr.on "data", (buffer) => @handle_incoming_msg(buffer)
        @process.on "exit", (code, signal) =>
          robot.emit "conversation_ended", @
          @add_to_list("ENDED_SESSION", @session_id)
          delete robot.sessions[@session_name]
          console.log "Session instance #{@session_id} for #{@session_name} has ended."
       
        # Add this session session_id to the started session list
        @add_to_list("STARTED_SESSION", @session_id)
        
        # Tell the world that the blessed event has occured
        robot.emit "conversation_started", @

    commandSettings: () ->
      env = process.env
      env.SESSION_ID = @session_id
      env.SRC = @user.name
      env.DST = @user.room
      for attrname of @settings.settings 
        env[attrname] = @settings.settings[attrname]
      return env
    
    isOwner: () ->
      if @settings.owners? and @user.name in @settings.owners
        true
      else
        false

    isJsonString: (str) ->
      # When a text message comes from a session, if it's a valid JSON 
      # string, we will treat it as a command or data. This function
      # allows us to figure that out.
      try
        JSON.parse str
      catch e
        return false
      true
    
    add_to_list: (list_session_id, session_session_id) ->
      redis_client.sadd(list_session_id, session_session_id)

    record_transcript:  (src, line) -> 
      #Update the transcript
      line = "#{Moment().format('lll')}|#{src}|#{line}\n"
      @transcript += line
      redis_client.set(@transcript_key, @transcript)
    
    handle_incoming_msg: (text) =>
      # If the message is a valid JSON object, treat it as if it were collected data
      # If so, stick it in a session_id in REDIS for somebody else to handle.
      lines = text.toString().split("\n")
      for line in lines
        console.log "Received from process : #{line}"
        if @isJsonString(line)
          redis_client.set @data_key, line
        else
          # It's not JSON.
          robot.send @user, line
          @record_transcript("bot", line)

    send_cmd_to_session: (cmd ) =>
      console.log "Sending to process :#{cmd}"
      @process.stdin.write("#{cmd}\n")
      @record_transcript(cmd)

 #end Session Class


  robot.hear /(.*)/i, (msg) =>
    room_name = msg.message.user.name.toLowerCase() + "_" + msg.message.room.toLowerCase()
    session = robot.sessions[room_name]
    if session
      session.send_cmd_to_session(msg.message.text)
    else
      new_session = new Session msg.message
      console.log "Created new session #{room_name} with session_id #{new_session.session_id}"
      robot.sessions[room_name] = new_session


  robot.on "conversation_ended", (session) =>
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
          host: session.settings.mail_host
          port: session.settings.mail_port
          auth:
            user: session.settings.mail_user
            pass: session.settings.mail_pass
        )
        # Message object
        message =          
          from: "notifier@green-bot.com"
          to: session.settings.notification_emails.join(",")
          subject: "Conversation Complete"
          text: session.transcript
          html: "<p><b>Hello</b> to myself <img src=\"cid:note@example.com\"/></p>" + "<p>Here's a nyan cat for you as an embedded attachment:<br/><img src=\"cid:nyan@example.com\"/></p>"

        console.log "Sending Mail"
        transporter.sendMail message, (error, info) ->
          if error
            console.log "Error occurred"
            console.log error.message
            return
          console.log "Message sent successfully!"
          console.log "Server responded with \"%s\"", info.response
          return
         
