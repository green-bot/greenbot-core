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
Request        = require("request-promise")
Mailer         = require("nodemailer")
Util           = require('util')
Pubsub         = require('./pubsub')
Logger         = require('./logger')
MongoClient    = require('mongodb').MongoClient
ObjectID       = require('mongodb').ObjectID
events         = Pubsub.pubsub

errorHandler = (desc, err) ->
  Logger.info desc
  Logger.info err

trace = (desc, obj) ->
  Logger.info desc
  Logger.info Util.inspect(obj) if obj?


# Global scope so we can get it later.
botsDb = undefined
sessionsDb = undefined
integrationsDb= undefined

CONNECTION_STRING = process.env.MONGO_URL or 'mongodb://localhost:27017/greenbot'

MongoClient.connect(CONNECTION_STRING)
.then (db) ->
  Logger.info "Connected to the DB"
  botsDb          = db.collection('Bots')
  sessionsDb      = db.collection('Sessions')
  integrationsDb  = db.collection('Integrations')

info = (text) ->
  events.emit 'log', text

formatEmail = (session) ->
  trace "Formatting email for session", session
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

sendEmail = (session, bot) =>
  info "Sending emails for session #{session.sessionId}"
  emailText = formatEmail(session)
  integrationsDb.findOne { type: 'mail', provider: 'mailgun'}
  .then (int) =>
    trace "Found email integration", int
    trace "Applying it to bot", bot
    smtpConfig =
      host: int.serviceUrl
      port: 465
      secure: true
      auth:
        user: int.auth.credentials.username
        pass: int.auth.credentials.password

    transporter = Mailer.createTransport(smtpConfig)
    message =
      to:       bot.notificationEmails
      from:     int.auth.credentials.username
      subject:  'Conversation Complete'
      text:     emailText

    info "Sending " + message.text
    transporter.sendMail message
  .then (res) ->
    info "Sent email for session #{session.sessionId}"
  .catch (error) -> trace("Email err for session #{session.sessionId}", error)

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

  info "Webhook #{bot.postConversationWebhook} sent for session #{session.sessionId}"
  Request.post(bot.postConversationWebhook, webhook_options)
  .then (response) ->
    info "Completed."
    info response.statusCode
    info response.headers['content-type']
  .catch (error) -> trace("Hook error:  #{bot.webhook_url}", error)


events.on 'session:ended', (sessionId) ->
  info "Notifying on the end of session #{sessionId}"
  session = undefined
  sessionsDb.findOne sessionId: sessionId
  .then (sess) =>
    session = sess
    info "Notifying session #{sessionId} for bot #{session.botId}"
    info session
    q2 = botsDb.findOne _id: session.botId
  .then (bot) =>
    trace "Found the bot, notifying", bot
    trace "for session ", session
    sendHook(session, bot) if bot.postConversationWebhook
    sendEmail(session, bot) if bot.notificationEmails
  .catch (error) -> trace("Session end error:  #{sessionId}", error)
