# Description:
#   Handles logging.
#
# Dependencies:
#   Winston, Papertrail
#
# Configuration:
#   Done through ports
#
#
# Author:
#   Thomas Howe
#


Parse = require('node-parse-api').Parse
Async = require('async')
_ = require('underscore')

module.exports = (robot) ->
  options =
    app_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI"
    api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7"
  parse = new Parse(options)
  active_sessions = {}
  active_transcripts = {}

  visitor_data_q = Async.queue (task, callback) ->
    parse.insert "VisitorData",
      visitor:
        __type: "Pointer"
        className: "Visitors"
        objectId: task.visitor_id
      key: task.key
      value: task.value,
      (err, response) ->
        if err
          robot.emit "log", "Error with visitor data save : #{err} #{response}"
        else
          robot.emit "log", "Rembered : #{task.key} as #{task.value}"
        callback()

  update_q = Async.queue (task, callback) ->
    sessionId = task.session.session_id
    unless sessionId of active_sessions
      robot.emit "log", "New session with key #{task.session.session_id}"
      session_object=
        room:
          __type:     'Pointer'
          className:  'Rooms'
          objectId:   task.session.room.objectId
        sessionId:  sessionId
        src:        task.session.src
        language:   task.session.room.language
      parse.insert 'Sessions', session_object, (err, response) ->
        if err
          robot.emit "log", "Threw error with data save : #{err} #{response}"
        else
          active_sessions[sessionId] = response.objectId
        callback()
    else
      objectId = active_sessions[sessionId]
      transcript = active_transcripts[sessionId] ? []
      update = {}

      if task.ingress_msg?
        new_line =
          direction: "ingress"
          text: task.ingress_msg
        transcript.push(new_line)
        update["transcript"] = JSON.stringify transcript
      if task.egress_msg?
        new_line =
          direction: "egress"
          text: task.egress_msg
        transcript.push(new_line)
        update["transcript"] = JSON.stringify transcript
      if task.collected_data?
        update["collected_data"] = task.collected_data
      active_transcripts[sessionId] = transcript
      parse.update "Sessions", objectId, update,
        (err, response) ->
          if err
            robot.emit "log", "Unable error #{sessionId} #{err}"
        callback()
  , 1


  robot.on "session:ingress_msg", (msg) ->
    new_task =
      session: msg.session
      ingress_msg: msg.text
    update_q.push new_task

  robot.on "session:egress_msg", (msg) ->
    new_task =
      session: msg.session
      egress_msg: msg.text
    update_q.push new_task

  robot.on "session:data", (msg) ->
    new_task =
      session: msg.session
      collected_data: msg.collected_data
    update_q.push new_task

  robot.on "session:end", (sessionId) ->
    delete active_sessions[sessionId]
    delete active_transcripts[sessionId]
    robot.emit "log", "Removed session #{sessionId} from lc"
