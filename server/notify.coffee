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
MongoConnection = require('./mongo-singleton')
debug          = require('debug')('notify')
events         = Pubsub.pubsub

errorHandler = (desc, err) ->
  Logger.debug desc
  Logger.debug err

# Global scope so we can get it later.
botsDb = undefined
integrationsDb= undefined

MongoConnection()
.then (db) ->
  debug "Connected to the DB"
  botsDb          = db.collection('Bots')
  integrationsDb  = db.collection('Integrations')

formatEmail = (session) ->
  debug "Formatting email for session", session
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
  debug "Sending emails for session #{session.sessionId}"
  emailText = formatEmail(session)
  integrationsDb.find({ type: 'mail', provider: 'mailgun'}).limit(1).next()
  .then (int) ->
    unless int
      debug "No email integration found. Returning"
      return

    debug "Found email integration", int
    debug "Applying it to bot", bot
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

    debug "Sending " + message.text
    transporter.sendMail message
  .then (res) ->
    debug "Sent email for session #{session.sessionId}"
  .catch (error) -> debug("Email err for session #{session.sessionId}", error)

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

  debug "Webhook #{bot.postConversationWebhook} sent for #{session.sessionId}"
  Request.post(bot.postConversationWebhook, webhook_options)
  .then (response) ->
    debug "Completed."
    debug response.statusCode
    debug response.headers['content-type']
  .catch (error) -> debug("Hook error:  #{bot.webhook_url}", error)


events.on 'session:ended', (session) ->
  debug "Notifying on the end of session #{session.sessionId}"
  debug "Notifying session #{session.sessionId} for bot #{session.botId}"
  botsDb.find({_id: session.botId}).limit(1).next()
  .then (bot) ->
    debug "Found the bot, notifying"
    sendHook(session, bot) if bot.postConversationWebhook
    sendEmail(session, bot) if bot.notificationEmails
  .catch (error) ->
    debug(error.stack)
    debug("Session end error:  #{session.sessionId}", error)
