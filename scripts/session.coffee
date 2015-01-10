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
# is identified by a unique short key; scripts that write data to a JSON file with that 
# will be collected by this script.
#
# As a convenience, and for further processing, Session will emits events to handle
# session life cycle (start and finish), messaging in the session (stdin, stdout, stderr)
# and listen for any JSON file and emit that as an event as well.
# 
#  Configuration:
#    DEFAULT_PATH: The default path of the file to be executed.
#    DEFAULT_CMD: The command line to execute
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

module.exports = (robot) ->
  robot.sessions = {}
  redis_client = Redis.createClient()
  console.log "Sessions are currently supported."
  robot.hear /(.*)/i, (msg) =>
    session_name = msg.message.user.name + "_" + msg.message.room
    console.log "Looking for session named #{session_name}"
    for session in robot.sessions
      console.log session.session_name()

    session = robot.sessions[session_name]
    if session
      console.log "Found session for #{session_name}"
      session.send_cmd_to_session(msg.message.text)
    else
      console.log "Did not find session for #{session_name}"
      new_session = new Session msg.message
      new_session.start_session()
 
  class Session
    constructor: (message)->
      @user = message.user
      @room = message.room

      @default_path = process.env.DEFAULT_PATH or '/Users/thomashowe/Documents/src/green_hubot'
      @default_cmd = process.env.DEFAULT_CMD or 'ruby example_script.rb'
  
      # Process the default path so we can use it for spawn. 
      @default_script_cmd = @default_cmd.split(" ")[0]
      @split_args = @default_cmd.split(" ")
      @split_args.shift()
      @default_args = @split_args.join(" ")
      @key = ShortUUID.generate()

    isJsonString: (str) ->
      # When a text message comes from a session, if it's a valid JSON 
      # string, we will treat it as a command or data. This function
      # allows us to figure that out.
      try
        JSON.parse str
      catch e
        return false
      true
    
    session_name: () -> 
      @user.name + "_" + @room

    add_to_list: (list_key, session_key) ->
      redis_client.sadd(list_key, session_key)

    transcript_key: () -> 
      "session_transcript:#{@key}"

    session_data_key: () -> 
      "session_data:#{@key}"

    record_transcript:  (line) -> 
      #Update the transcript
      redis_client.get(@transcript_key(), (err, transcript) =>
        line += "\n"
        if transcript?
          transcript = transcript + line
        else
          transcript = line
        redis_client.set(@transcript_key(), transcript)
      )
    
    handle_incoming_msg: (text) =>
      # If the message is a valid JSON object, treat it as if it were collected data
      # If so, stick it in a key in REDIS for somebody else to handle.
      lines = text.toString().split("\n")
      for line in lines
        if @isJsonString(line)
          redis_client.set @session_data_key(), line
        else
          # It's not JSON.
          robot.send @user, line
          @record_transcript(line)


    send_cmd_to_session: (cmd ) =>
      @process.stdin.write("#{cmd}\n")
      @record_transcript(cmd)

    start_session: () ->
      console.log "Starting new session for #{@session_name()}"
      @username = @user.name
      @env = process.env
      @env.SESSION_ID = @key
      @env.SRC = @user.name
      @env.DST = @user.room 
      redis_client.get("DEFAULT_SETTINGS", (err, reply) => 
        if reply?
          reply = JSON.parse reply.toString()
          for attrname of reply
            console.log "Applying #{attrname} to #{reply[attrname]}"
            @env[attrname] = reply[attrname]

          # Do this again, but for settings for this particular room
          redis_client.get("room_settings:#{@user.room}", (err, reply) =>
            if reply?
              reply = JSON.parse reply.toString()
              for attrname of reply
                console.log "Applying #{attrname} to #{reply[attrname]}"
                @env[attrname] = reply[attrname]
            @.spawn_shell()
          )
        else
          @.spawn_shell()
      )

    spawn_shell: () ->
      console.log "Spawning shell #{@default_script_cmd} #{@default_args} for #{@user.name} in directory #{@default_path}"
      spawn = require("child_process").spawn
      opts = {
        cwd: @default_path
        env: @env
      }
      @process = spawn(@default_script_cmd, @split_args, opts)
      @process.stdout.on "data", (buffer) => @handle_incoming_msg(buffer)
      @process.stderr.on "data", (buffer) => @handle_incoming_msg(buffer)
      @process.on "exit", (code, signal) =>
        @add_to_list("ENDED_SESSION", @key)
        console.log("Session ended for #{@username} with #{code}")
        delete robot.sessions[@username]

      robot.sessions[@session_name()] = @
      @add_to_list("STARTED_SESSION", @key)
      console.log "Started session for #{@session_name()}"


     
