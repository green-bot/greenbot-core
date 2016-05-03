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
events         = Pubsub.pubsub

errorHandler = (desc, err) ->
  Logger.info desc
  Logger.info err

trace = (desc, obj) ->
  if process.env.TRACE_MESSAGES?
    Logger.info desc
    Logger.info Util.inspect(obj) if obj?


# Global scope so we can get it later.
botsDb = undefined
sessionsDb = undefined
integrationsDb= undefined

CONNECTION_STRING = process.env.MONGO_URL or
                    'mongodb://localhost:27017/greenbot'

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

sendEmail = (session, bot) ->
  info "Sending emails for session #{session.sessionId}"
  emailText = formatEmail(session)
  integrationsDb.find({ type: 'mail', provider: 'mailgun'}).limit(1).next()
  .then (int) ->
    unless int
      trace "No email integration found. Returning"
      return

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
      subject:  bot.notificationEmailSubject
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

  info "Webhook #{bot.postConversationWebhook} sent for #{session.sessionId}"
  Request.post(bot.postConversationWebhook, webhook_options)
  .then (response) ->
    info "Completed."
    trace response.statusCode
    trace response.headers['content-type']
  .catch (error) -> trace("Hook error:  #{bot.webhook_url}", error)


events.on 'session:ended', (session) ->
  info "Notifying on the end of session #{session.sessionId}"
  info "Notifying session #{session.sessionId} for bot #{session.botId}"
  trace session
  botsDb.find({_id: session.botId}).limit(1).next()
  .then (bot) ->
    trace "Found the bot, notifying", bot
    sendHook(session, bot) if bot.postConversationWebhook
    sendEmail(session, bot) if bot.notificationEmails
  .catch (error) ->
    trace(error.stack)
    trace("Session end error:  #{session.sessionId}", error)
