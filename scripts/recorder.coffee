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

connectionString = process.env.MONGO_URL or 'localhost/greenbot'
Db = require('monk')(connectionString)
Sessions = Db.get('Sessions')

module.exports = (robot) ->
  update_q = Async.queue (task, callback) ->
    console.log task
    if task.type == 'session:start'
      # Can't find a session with that keyword. Make one.
      s =
        sessionId: task.session.sessionId
        src: task.session.src
        dst: task.session.dst
        roomId: task.session.roomId
        transcript: []
      Sessions.insert(s).then () ->
        callback()
    else
      sessionId = task.sessionId
      query = Sessions.findOne { 'sessionId': sessionId }
      query.on 'success', (s) ->
        if s
          switch task.type
            when 'session:ingress_msg'
              new_line =
                direction: 'ingress'
                text: task.text
              s.transcript.push(new_line)
            when 'session:egress_msg'
              new_line =
                direction: 'egress'
                text: task.text
              s.transcript.push(new_line)
            when 'session:collected_data'
              s.collected_data = collected_data
          Sessions.update {sessionId: s.sessionId}, s
        callback()
  , 1

  robot.on 'session:ingress_msg', (sessionId, text) ->
    new_task =
      type: 'session:ingress_msg'
      sessionId: sessionId
      text: text
    update_q.push new_task

  robot.on 'session:egress_msg', (sessionId, text) ->
    new_task =
      type: 'session:egress_msg'
      sessionId: sessionId
      text: text
    update_q.push new_task

  robot.on 'session:data', (msg) ->
    new_task =
      type: 'session:data'
      sessionId: msg.session.sessionId
      collected_data: msg.collected_data
    update_q.push new_task

  robot.on 'session:start', (session) ->
    new_task =
      type: 'session:start'
      session: session
    update_q.push new_task
