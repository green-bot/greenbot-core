Request = require('request-promise')
Slack = require('slack-client')
Util = require('util')
ShortUUID = require 'shortid'

autoReconnect = true
autoMark = true


module.exports = (robot) ->
  if process.env.SLACK_TOKEN
    slack = new Slack(process.env.SLACK_TOKEN, autoReconnect, autoMark)

    slack.login()

    slack.on 'open', ->
      console.log "Running slackbot as @#{slack.self.name} of #{slack.team.name}"

    slack.on 'message', (message) ->
      {type, ts, text, user, channel} = message
      console.log("New chat arrived : #{text} from #{channel}, user #{user}")

      msg =
        dst: "@" + slack.self.name
        src: channel
        txt: text
      robot.emit 'slack:ingress', msg

    slack.on 'error', (error) ->
      console.error "Slack client error: #{JSON.stringify(error)}"

    robot.on "slack:egress", (dst, txt) ->
      channel = slack.getChannelGroupOrDMByID(dst)
      channel.send txt
