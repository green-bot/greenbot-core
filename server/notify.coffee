# Description:
#   Handles notifcations after a session is complete.
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
# Author:
#   Thomas Howe - ghostofbasho@gmail.com
#
Request = require("request")
Mailer = require("nodemailer")
Util = require('util')
Pubsub = require('./pubsub')
ObjectId = require('mongodb').ObjectID
events = Pubsub.pubsub

connectionString = process.env.MONGO_URL or 'localhost:27017/greenbot'
Db = require('monk')(connectionString)
Bots = Db.get('Bots')
Sessions = Db.get('Sessions')
Integrations = Db.get('Integrations')

info = (text) ->
  events.emit 'log', text

sendEmail = (session, bot) ->
  info "Sending emails for session #{session.sessionId}"
  q = Integrations.find
    type: 'mail'
    provider: 'google'
  q.then (int) ->
    transporter = Mailer.createTransport
      service: int.provider
      auth:
        user: int.auth.username
        pass: int.auth.password

    message =
      to:       bot.notification_emails.join(',')
      from:     int.auth.username
      subject:  'Conversation Complete'
      text:     formatEmail(session)

    info "Sending " + message.text

    transporter.sendMail message, (error, res) ->
      if error
        info "Email err for session #{session.sessionId}"
        info error.message
      else
        info "Sent email for session #{session.sessionId}"


sendHook = (session, bot) ->
  webhook_options =
    form:
      transcript: session.transcript
      botId: bot._id
      scriptId: bot.scriptId
      settings: bot.settings
      data: session.collectedData
  if !! bot.webhook_authtoken
    webhook_options.headers =
      Authorization: bot.webhook_authtoken

  info "Webhook #{bot.webhook_url} sent for session #{session.sessionId}"
  Request.post(bot.webhook_url, webhook_options)
  .on 'response', (response) ->
    info "Completed."
    info response.statusCode
    info response.headers['content-type']

formatEmail = (session) ->
  txt = "#{session.src.trim()}\n,
  You have a new conversation from #{session.dst}.\n
  \n
  "

  txt += "\nTranscript\n"
  for line in session.transcript
    do (line) ->
      output = session.dst if line.direction is 'egress'
      output = session.src if line.direction is 'ingress'
      output += ": " + line.text + "\n"
      txt += output

  txt += "\nCollected Data\n"
  for k,v of session.collectedData
    txt += "#{k}:#{v}\n"
  txt


events.on 'session:ended', (sessionId) ->
  info "Notifying on the end of session #{sessionId}"
  q = Sessions.findOne sessionId: sessionId
  q.on 'error', (err) -> info "Session search fail in notify? #{err}"
  q.on 'success', (session) ->
    info "Notifying session #{sessionId} for bot #{session.botId}"
    info session
    q2 = Bots.findOne _id: ObjectId(session.botId)
    q2.on 'error', (err) -> info "Error thrown in noticiations : #{err}"
    q2.on 'success', (bot) ->
      info bot
      sendHook(session, bot) if bot.webhook_url?
      sendEmail(session, bot) if bot.notification_emails?
