# Description
#
# Notify on session completion.
# Author: howethomas
#

Request = require("request")
Mailer = require("nodemailer")
Events = require('events')

connectionString = process.env.MONGO_URL or 'localhost/greenbot'
Db = require('monk')(connectionString)
Sessions = Db.get('Sessions')
Rooms = Db.get('Rooms')


module.exports = (robot) ->
  info = (text) ->
    robot.emit 'log', text

  sendEmail = (session, room) ->
    info "Sending emails for session #{session.sessionId}"
    transporter = Mailer.createTransport(
      service: "gmail"
      auth:
        user: room.mail_user
        pass: room.mail_pass
    )
    message =
      to:       room.notification_emails.join(',')
      from:     room.mail_user
      subject:  'Conversation Complete'
      text:      session.transcript.join(',')

    transporter.sendMail message, (error, res) ->
      if error
        info "Email err for session #{session.sessionId}"
        info error.message
      else
        info "Sent email for session #{session.sessionId}"


  sendHook = (session, room) ->
    webhook_options =
      form:
        transcript: session.transcript
        room_id: room.objectId
        script_id: room.script.objectId
        settings: room.settings
        data: session.collectedData
    if !! room.webhook_authtoken
      webhook_options.headers =
        Authorization: room.webhook_authtoken

    info "Webhook #{room.webhook_url} sent for session #{session.sessionId}"
    Request.post(room.webhook_url, webhook_options)
    .on 'response', (response) ->
      info "Completed."
      info response.statusCode
      info response.headers['content-type']


  robot.on 'session:ended', (sessionId) ->
    Sessions.findOne { sessionId: sessionId }, (err, session) ->
      if err or not session?
        info "Can't find the session record to update. Odd"
        return
        
      info "Notifying session #{sessionId} in room #{session.roomId}"
      Rooms.findOne { objectId: session.roomId }, (err, room) ->
        sendHook(session, room) if room.webhook_url?
        sendEmail(session, room) if room.notification_emails?
