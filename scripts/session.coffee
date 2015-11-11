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
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
Request = require("request")
Mailer = require("nodemailer")
Us = require("underscore.string")
Async = require('async')
_ = require('underscore')
Events = require('events')
DB = require('mongo')
Rooms = DB.client.get('Rooms')

# Helper functions
info = (text) ->
  console.log text


module.exports = (robot) ->
  robot.sessions = {}

  respond_to_help = (msg) ->
    info "Handle helpish message #{JSON.stringify msg.message}"

  generate_session_key = (msg) ->
    visitor_name(msg) + "_" + room_name(msg)

  clean_text = (msg) ->
    msg_text(msg).trim().toLowerCase()

  msg_text = (msg) ->
    msg.message.text

  room_name = (msg) ->
    name = process.env.DEV_ROOM_NAME or msg.message.room.toLowerCase()
    name

  visitor_name = (msg) ->
    msg.message.user.name.toLowerCase()

  class Session
    constructor: (initial_msg, room, robot)->
      # The variables that make up a Session
      @transcript = ""
      @user = initial_msg.user    # This is the user structure from hubot.
      @src = visitor_name(initial_msg)
      @room_name = room_name(initial_msg)
      @session_key = generate_session_key(initial_msg)
      @session_id = ShortUUID.generate()
      @room = room
      @command_path = @room.default_path
      @arguments = @assemble_args()
      @robot = robot
      @command = @arguments[0]
      @arguments.shift()
      @env = @command_settings()
      @env.INITIAL_msg = initial_msg
      opts =
        cwd: @command_path
        env: @env

      # All setup, we now spawn the process.
      @process = ChildProcess.spawn(@command, @arguments, opts)
      @process.stdout.on "data", (buffer) => @handle_incoming_msg(buffer)
      @process.on "exit", (code, signal) => @end_session()
      @process.on "error", (err) ->
        info "Error thrown from session"
        info err
      @process.stderr.on "data", (buffer) ->
        info "Received from stderr #{buffer}"

      # Tell the world that the blessed event has occured
      robot.emit "session:start", @

    assemble_args: () ->
      if @is_owner()
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
        info 'Arguments taken from ' + JSON.stringify @room
        args = @room.default_cmd.split(" ")
      return args

    transcribe: (line) ->
      @transcript += line

    describe: () =>
      info "Describing session : #{@session_id}"
      info "ID: #{@process.pid}"
      info "NAME: #{@process.title}"
      info "UPTIME: #{@process.uptime}"

    end_session: () =>
      info "Ending and recording session #{@session_id}"
      Async.series([
        @send_webhook,
        @send_email,
        @delete_session])

    send_webhook: (callback) =>
      info "Webhook #{@room.webhook_url}" if !! @room.webhook_url
      if !! @room.webhook_url
        webhook_options =
          form:
            transcript: @transcript
            room_id: @room.objectId
            script_id: @room.script.objectId
            settings: @room.settings
            data: @collected_data
        if !! @room.webhook_authtoken
          webhook_options.headers =
            Authorization: @room.webhook_authtoken

        info "Sending JSON as #{JSON.stringify webhook_options}"
        Request.post(@room.webhook_url, webhook_options)
        .on 'response', (response) ->
          info "Completed."
          info response.statusCode
          info response.headers['content-type']
          callback(null, "Sent hook")
      else
        info "No webhook_url"
        callback(null, "No webhook")

    send_email: (callback) =>
      info "Sending emails"
      if @room.notification_emails?
        # Create a SMTP transporter object
        info "Sending notification email"
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

        info "Sending Mail to #{recipients}"
        transporter.sendMail message, (error, res) ->
          if error
            info "Error occurred"
            info error.message
            return
          info "Message sent successfully!"
          info "Server responded with #{res.response}"
          callback(null, "Mail sent")
      else
        info "No notification emails"
        callback(null, "No mails to send")


    delete_session: (callback) =>
      info "Session ended. Who do we have to tell?"
      delete robot.sessions[@session_key]
      robot.emit "session:end", @session_key
      #Add the collected data. That's a great idea.
      callback(null, "No goodbyes")

    command_settings: () ->
      env_settings = _.clone(process.env)
      env_settings.SESSION_ID = @session_id
      env_settings.SRC = @src
      env_settings.DST = @room_name
      env_settings.ROOM_OBJECT_ID = @room.objectId
      for attrname of @room.settings
        env_settings[attrname] = @room.settings[attrname]
      return env_settings

    is_owner: () ->
      info "Thinking I'm #{@src}"
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
      lines = text.toString().split("\n")
      for line in lines
        line = line.trim()
        if @is_json_string line
          @collected_data = JSON.parse line
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
            @transcribe("#{@room_name}:#{line}\n")

    send_cmd_to_session: (text) =>
      info "Received #{text}"
      @robot.emit "session:ingress_msg",
          session: @
          text: text
      @transcribe("#{@src}:#{text}\n")
      info "Error cmd #{text} to a disconnected session" if @process.connected
      @describe()
      @process.stdin.write("#{text}\n")
      @robot.emit "session:inbound_msg", @, text

  create_session = (msg, room, robot) ->
    new_session = new Session(msg, room, robot)
    robot.sessions[new_session.session_key] = new_session

  robot.hear /(.*)/i, (msg) ->
    # All messages that come from the network end up here.
    session_name = generate_session_key(msg)
    session = robot.sessions[session_name]
    if session
      session.send_cmd_to_session(msg_text msg)
      return

    # If this is a command to handle the directory, handle it.
    help_commands = ["help", "?", "rooms", "/help", "/rooms"]
    if  msg in help_commands
      respond_to_help msg
      return

    name = room_name(msg)
    keyword = clean_text(msg)
    Rooms.findOne {name: name, keyword: keyword}, (err, room) ->
      if err
        info "Can't find #{name}:#{keyword}"
        return
      if room
        info "Found room #{room_name msg}, starting session"
        create_session msg, room, robot
        return
      # No room and keyword combination matched
      # Return the default if there's one.
      info 'No room/keyword found. Check for default'
      Rooms.findOne {name: name, default: true}, (err, room) ->
        if room
          info "Found room #{name}, starting session"
          create_session msg, room, robot
          return
        else
          info 'No default room, no matching keyword. Fail.'


  robot.on "session:chat_arrived", (session_key, chat_msg) ->
    session = robot.sessions[session_key]
    session.handle_incoming_msg(chat_msg)
