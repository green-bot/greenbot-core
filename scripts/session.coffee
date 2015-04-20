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
Winston = require('winston')
Papertrail = require('winston-papertrail').Papertrail
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

  robot.emit "log", "Session loaded"
  class Session
    STR_PAD_LEFT = 1
    STR_PAD_RIGHT = 2
    STR_PAD_BOTH = 3

    constructor: (message, room)->
      # The variables that make up a Session
      console.log("Setting up a new session with settings")
      console.log JSON.stringify(room, null, 4)
      @user = message.user    # This is the user structure from hubot.
      @src = @user.name.toLowerCase()
      @room_name = message.room.toLowerCase() # this is a string.
      @session_key = @src + "_" + @room_name
      @session_id = ShortUUID.generate()
      @transcript_key = @session_id
      @data_key = "session_data:#{@session_id}"
      @transcript = ""
      @room = room
      @command_path = @room.default_path


      # There are generally two different people who text in
      # The first is the owner of the number, and he is
      # texting into the system to configure it.
      # The second are the customers, who are there to use it.
      if @is_owner()
        console.log "Running as the owner"
        if @room.test_mode is true
          @room.test_mode = false
          parse.update 'Room', @room.objectId, { test_mode: false }, (err, response) =>
            if err
              console.log("Found an error trying to turn off test mode : #{err}")
            else
              console.log("Turned off test mode on room #{@room.objectId}")
          @arguments = @room.default_cmd.split(" ")
        else
          @arguments = @room.owner_cmd.split(" ")
      else
        @arguments = @room.default_cmd.split(" ")

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
      @process.on "exit", (code, signal) => @end_and_record_session()

      # Tell the world that the blessed event has occured
      robot.emit "session:start", @
      robot.emit "log", "New session started : #{@user}|#{@room_name}|#{@arguments}"

    end_and_record_session: () =>
      console.log "Ending and recording session #{@session_id}"
      Async.series([
        @send_goodbye,
        @save_collected_data,
        @save_transcript,
        @save_session,
        @delete_session])

    send_goodbye: (callback) =>
      base_link = @room.goodbye_link or "http://www.justkisst.me"
      url = Url.parse(base_link, true)
      url.query["src"] = @src
      url.query["dst"] = @room_name
      url.query["session_id"] = @session_id
      url.query["reseller"] = @room.reseller

      console.log("Using the closing link #{Url.format(url)}")
      Bitly.shortenLink encodeURIComponent(Url.format(url)), (err, results) =>
        console.log("Shortened info is #{results}")
        throw err if err
        # See http://code.google.com/p/bitly-api/wiki/ApiDocumentation for format of returned object
        short_url = JSON.parse(results).data.url
        # Do something with data
        @handle_incoming_msg(@room.closing_message + short_url)
        callback(null, "Saved object")


    save_transcript: (callback) =>
      console.log("Saving transcript")
      for k,v of JSON.parse @collected_data
        @update_transcript "collected_data", "#{k}:#{v}"
      transcript_object=
        transcript:       @transcript
        transcript_key:   @session_id
      parse.insert 'Transcript', transcript_object, (err, response) =>
        if err
          callback("Could not create object.", null)
        else
          parse.addRelation("room", "Transcript", response.objectId, "Room", @room.objectId,
            () =>
              @transcript_data_id = response.objectId
              console.log("Object saved")
              callback(null, "Saved object"))

    save_collected_data: (callback) =>
      console.log("Saving collected data for room #{@room.objectId}")
      console.log(@collected_data)
      if @collected_data?
        collected_data_object=
          src:   @src
          data:  JSON.parse @collected_data
        parse.insert 'CollectedData', collected_data_object, (err, response) =>
          if err
            console.log("Threw error during data save : #{err} #{response}")
            callback("Could not create object.", null)
          else
            # Saved object, now add relation
            console.log response
            @collected_data_object_id = response.objectId
            parse.addRelation("room", "CollectedData", response.objectId, "Room", @room.objectId,
              () =>
                console.log("Object saved")
                callback(null, "Saved object"))
      else
        callback(null, "No data to save")

    save_session: (callback) =>
      console.log("Saving session for room #{@room.objectId}")
      session_object=
        src:          @src
        sessionId:   @session_id
      parse.insert 'Session', session_object, (err, response) =>
        if err
          console.log("Threw error during data save : #{err} #{response}")
          callback("Could not create object.", null)
        else
          # Saved object, now add relation
          console.log response
          @session_object_id = response.objectId
          parse.addRelation("room", "Session", @session_object_id, "Room", @room.objectId,
            () =>
              parse.addRelation("collectedData", "Session", @session_object_id, "CollectedData", @collected_data_object_id,
                () =>
                  parse.addRelation("transcript", "Session", @session_object_id, "Transcript", @transcript_data_id,
                    () =>
                      parse.addRelation("session", "CollectedData", @collected_data_object_id, "Session", @session_object_id,
                        () =>
                          console.log("Object saved")
                          callback(null, "Saved object")))))

    delete_session: (callback) =>
      console.log("Ending session...")
      delete robot.sessions[@session_key]
      robot.emit "session:end", @
      console.log "Session instance #{@session_id} for #{@session_key} has ended."
      callback(null, "Ended session")


    command_settings: () ->
      env = process.env
      env.SESSION_ID = @session_id
      env.SRC = @src
      env.DST = @user.room
      for attrname of @room.settings
        env[attrname] = @room.settings[attrname]
      return env

    is_owner: () ->
      console.log "Thinking I'm #{@src}"
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

    update_transcript:  (src, line) ->
      #Update the transcript
      line = "#{Moment().format('lll')}|#{@pad(src, 15, ' ', STR_PAD_LEFT)}|#{line}\n"
      @transcript += line


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
            @update_transcript("bot", line)
            robot.emit("session:outbound_msg", @, line)


    send_cmd_to_session: (cmd ) =>
      @process.stdin.write("#{cmd}\n")
      @update_transcript(@src, cmd)
      robot.emit("session:inbound_msg", @, cmd)



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
    new_session = new Session(msg.message, settings)
    console.log "New session #{new_session.session_key} (session_id #{new_session.session_id}) between #{new_session.user.name} and #{new_session.user.room}"
    robot.sessions[new_session.session_key] = new_session


  robot.hear /(.*)/i, (msg) =>
    session_key = msg.message.user.name.toLowerCase() + "_" + msg.message.room.toLowerCase()
    session = robot.sessions[session_key]
    if session
      clean_text = msg.message.text.trim().toLowerCase()
      switch clean_text
        when "/quit"
          session.process.kill("SIGHUP")
        else
          console.log("Sending #{msg.message.text}")
          session.send_cmd_to_session(msg.message.text)
    else
      # This is a new session. See if there are settings defined for it.
      # If there are not, then create an empty template for this room
      # That allows the named owner the ability to set it up.
      room_name =  "#{msg.message.room.toLowerCase()}"
      console.log("Looking for " + room_name)
      parse.findMany 'Room', { name: room_name }, (err, response) ->
        rooms = response.results
        console.log JSON.stringify(rooms, null, 4)
        if err or (rooms.length == 0)
          console.log "Cannot setup room - no room defined"
        else
          room = rooms.shift()
          console.log "Found room with id " + room.objectId.toString()
          create_session(msg, room)

  robot.on "session:end", (session) =>
      #Add the collected data. That's a great idea.
      console.log("Session ended. Who do we have to tell?")
      if session.room.webhook_url?
        console.log "Completed. Notifying #{session.settings.webhook_url}"
        Request.get "#{session.settings.webhook_url}?session_id=#{session.session_id}", null,
          (error, response, body) =>
            if error
              console.log "Webhook returned error"
              console.log body
              console.log error
      if session.room.notification_emails?
        # Create a SMTP transporter object
        console.log("Sending notification email")
        transporter = Mailer.createTransport(
          service: "gmail"
          auth:
            user: session.room.mail_user
            pass: session.room.mail_pass
        )
        # Message object
        recipients = session.room.notification_emails.join(",")
        message =
          from: session.room.mail_user
          to: recipients
          subject: "Conversation Complete"
          text: session.transcript

        console.log "Sending Mail to #{recipients}"
        transporter.sendMail message, (error, info) ->
          if error
            console.log "Error occurred"
            console.log error.message
            return
          console.log "Message sent successfully!"
          console.log "Server responded with \"%s\"", info.response
          return
