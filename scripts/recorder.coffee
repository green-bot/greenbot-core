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

Parse = require('node-parse-api').Parse
module.exports = (robot) ->
  options =
    app_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI"
    api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7"
  parse = new Parse(options)

  fetch_session = (session_key) ->
    query = {
      where: {
        sessionId: session_key
      }
    }
    robot.emit "log", "Looking for session " + session_key
    robot.emit "log", "with query " + JSON.stringify query
    parse.find "Sessions", query, (err,response) ->
        if err || response.results.length == 0
          robot.emit "log", "Cannot find session with key #{session_key}"
        else
          robot.emit "log", "Fetched response : " + JSON.stringify response
          robot.emit "log", "Fetched session : " + JSON.stringify session
          session = response[0]
          return session


  robot.on "session:start", (session) ->
    session_object=
      room:
        __type:     'Pointer'
        className:  'Rooms'
        objectId:   session.room.objectId
      sessionId:  session.session_id
      src:        session.src
      language:   session.room.language
    robot.emit "log", "Creating session #{JSON.stringify session_object}"
    parse.insert 'Sessions', session_object, (err, response) ->
      if err
        robot.emit "log", "Threw error during data save : #{err} #{response}"
      else
        robot.emit "log", "New session started ; #{session.session_id}"

  robot.on "session:ingress_msg", (msg) ->
    session = fetch_session msg.session
    new_line =
      ingress: true
      text: msg.text
    transcript = session.transcript ? [ ]
    transcript.push(new_line)
    parse.update "Sessions", session.objectId,
      { transcript: transcript }, (err, response) ->
        if err
          robot.emit "log",
            "Unable to update ingress msg #{err}"

  robot.on "session:egress_msg", (msg) ->
    session = fetch_session msg.session
    new_line =
      ingress: false
      text: msg.text
    transcript = session.transcript ? [ ]
    transcript.push(new_line)
    parse.update "Sessions", session.objectId,
      { transcript: transcript }, (err, response) ->
        if err
          robot.emit "log",
            "Unable to update ingress msg #{err}"


  robot.on "session:data", (msg) ->
    session = fetch_session msg.session
    parse.update "Sessions", session.objectId,
      { data: msg.data }, (err, response) ->
        if err
          robot.emit "log", "Unable to update data #{err}"
