# Description:
#   Connects greenbot to live chat.
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

Request = require('request-promise')
Slack = require('slack-client')
Util = require('util')

# Global events object
Pubsub = require('./pubsub')
events = Pubsub.pubsub


module.exports = ->
  # Don't run this unless SLACK_TOKEN and SLACK_ANNOUNCE are set
  unless process.env.SLACK_TOKEN and process.env.SLACK_ANNOUNCE
    events.emit 'log',  "Not running slack chat. No credentials"
    return

  autoReconnect = true
  autoMark = true
  slackClient = new Slack(process.env.SLACK_TOKEN, autoReconnect, autoMark)
  announceChannel = process.env.SLACK_ANNOUNCE
  announceId = ''

  sendToChannel = (channelName, text) ->
    options =
      uri: 'https://slack.com/api/channels.join'
      qs:
        token: process.env.SLACK_TOKEN
        name: channelName
    Request(options).then((response) ->
      events.emit 'log',  Util.inspect response
      options.uri = 'https://slack.com/api/chat.postMessage'
      options.qs.text = text
      options.qs.channel = JSON.parse(response).channel.id
      Request(options).then((response) ->
        events.emit 'log',  Util.inspect options
        events.emit 'log',  Util.inspect response
        events.emit 'log',  "#{text} sent to #{channelName}"
      )
    )

  slackClient.login()

  slackClient.on 'send', (channel, msg) ->
    channel.send(msg)

  slackClient.on 'message', (message) ->
    channel = slackClient.getChannelGroupOrDMByID(message.channel)
    {type, ts, text} = message
    events.emit 'log', ("---\nSLACK: New chat arrived : #{text} from #{channel}")

  slackClient.on 'error', (error) ->
    console.error "Slack client error: #{JSON.stringify(error)}"

  events.on 'livechat:ingress', (session, text) ->
    events.emit 'log',  "livechat msg: #{text} #{session.src}"
    sendToChannel(session.src, text)

  events.on 'livechat:newsession', (session) ->
    events.emit 'log',  "Livechat new session #{session.src}"
    options =
      uri: 'https://slack.com/api/channels.join'
      qs:
        token: process.env.SLACK_TOKEN
        name: session.src
    Request(options).then (response) ->
      events.emit 'log',  Util.inspect response
      sendToChannel announceChannel,
                    "New convo with #{session.src} at <##{announceId}>"

  options =
    uri: 'https://slack.com/api/channels.join'
    qs:
      token: process.env.SLACK_TOKEN
      name: announceChannel
  Request(options).then (response) ->
    events.emit 'log',  Util.inspect response
    events.emit 'log',  'Started the announce channel'
    announceId = JSON.parse(response).channel.id
