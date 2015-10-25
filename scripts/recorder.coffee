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

Async = require('async')
_ = require('underscore')

module.exports = (robot) ->
  active_sessions = {}
  active_transcripts = {}

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
    robot.logger "Removed session #{sessionId} from lc"
