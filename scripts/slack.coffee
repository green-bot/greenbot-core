Request = require('request-promise')
Slack = require('slack-client')
Util = require('util')



module.exports = (robot) ->
  # Don't run this unless SLACK_TOKEN and SLACK_ANNOUNCE are set
  unless process.env.SLACK_TOKEN and process.env.SLACK_ANNOUNCE
    console.log "Not running slack chat. No credentials"
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
      console.log Util.inspect response
      options.uri = 'https://slack.com/api/chat.postMessage'
      options.qs.text = text
      options.qs.channel = JSON.parse(response).channel.id
      Request(options).then((response) ->
        console.log Util.inspect options
        console.log Util.inspect response
        console.log "#{text} sent to #{channelName}"
      )
    )

  slackClient.login()

  slackClient.on 'send', (channel, msg) ->
    channel.send(msg)

  slackClient.on 'message', (message) ->
    channel = slackClient.getChannelGroupOrDMByID(message.channel)
    {type, ts, text} = message
    console.log("---\nSLACK: New chat arrived : #{text} from #{channel}")

  slackClient.on 'error', (error) ->
    console.error "Slack client error: #{JSON.stringify(error)}"

  robot.on 'livechat:ingress', (session, text) ->
    console.log "livechat msg: #{text} #{session.src}"
    sendToChannel(session.src, text)

  robot.on 'livechat:newsession', (session) ->
    console.log "Livechat new session #{session.src}"
    options =
      uri: 'https://slack.com/api/channels.join'
      qs:
        token: process.env.SLACK_TOKEN
        name: session.src
    Request(options).then (response) ->
      console.log Util.inspect response
      sendToChannel announceChannel,
                    "New convo with #{session.src} at <##{announceId}>"

  options =
    uri: 'https://slack.com/api/channels.join'
    qs:
      token: process.env.SLACK_TOKEN
      name: announceChannel
  Request(options).then (response) ->
    console.log Util.inspect response
    console.log 'Started the announce channel'
    announceId = JSON.parse(response).channel.id
