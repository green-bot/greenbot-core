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
Us = require("underscore")
Wellknown = require("nodemailer-wellknown")
Winston = require('winston')
Papertrail = require('winston-papertrail').Papertrail
Parse = require('node-parse-api').Parse

module.exports = (robot) ->
  session_tracker = { }
  options =
    app_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI"
    api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7"
  @parse = new Parse(options)


  robot.on "session:transcript", (transcript_key, transcript) =>
    if transcript_key in Us.keys(session_tracker)
      stored_transcript = session_tracker[transcript_key]
      stored_transcript.transcript = transcript
      @parse.update 'Transcript', stored_transcript.id, { transcript: transcript}
    else
      stored_transcript =
        transcript_key: transcript_key
        transcript: transcript
      @parse.insert 'Transcript', stored_transcript, (err, response) ->
        if err
          robot.emit "log", err
        else
          session_tracker[transcript_key] = stored_transcript
