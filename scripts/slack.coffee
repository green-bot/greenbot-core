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

Readline = require 'readline'
ShortUUID = require 'shortid'
Redis = require "redis"
Os = require("os")
ChildProcess = require("child_process")
Url = require("url")
Request = require("request")
Mailer = require("nodemailer")
Moment = require("moment")
Us = require("underscore")
Wellknown = require("nodemailer-wellknown")
Winston = require('winston')
Papertrail = require('winston-papertrail').Papertrail
Parse = require('node-parse-api').Parse
Async = require('async')
BitlyAPI = require('node-bitlyapi')
Slack = require('slack-client')

module.exports = (robot) ->
  options =
    app_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI"
    api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7"
  parse = new Parse(options)
  slack_clients = {} # Referenced by API token
  clients_by_key = {}
  session_keys_by_channel = {}
  channels_by_session_keys = {}

  console.log("Slack script running")

  # A helper function to tell us if an inbound chat message is a control
  # message or a just a normal chat message.
  # Control messages are used to assign bots to the appropriate rooms
  is_control_message = (text) =>
    [session_key, action] = text.split(" ")
    session_keys = Us.keys(clients_by_key)
    return false unless session_key in session_keys
    return false unless action in ["start", "stop", "listen"]
    return true

  session_announce_end = (session_key) ->
    slack_client = clients_by_key[session_key]
    if slack_client?
      slack_client.announce_channel.send("#{session_key} has just ended")

  # Every integratin needs a slack client. Then can be shared
  # among sessions.
  new_slack_client = (token, session_key, announce_channel) ->
    autoReconnect = true
    autoMark = true
    slack_client = new Slack(token, autoReconnect, autoMark)
    slack_client.announce_channel_name = announce_channel
    slack_client.unannounced = []
    slack_client.unannounced.push session_key if session_key?

    slack_client.on 'loggedIn', =>
      console.log("Slack client logged in")
      slack_client.announce_channel = slack_client.getChannelByName(slack_client.announce_channel_name)
      for session_key in slack_client.unannounced
        slack_client.emit("announce", session_key)

    slack_client.on 'announce', (session_key) =>
      console.log("Announcing #{session_key}")
      announcements = [
        "New session #{session_key}
        In any room that I'm listening in you can use the following commands: \n
        To just listen, type '#{session_key} listen' \n
        To start chatting, type '#{session_key} start' \n
        To stop and go back to the bot, '#{session_key} stop'"
      ]
      for msg in announcements
        slack_client.emit 'send', slack_client.announce_channel, msg

    slack_client.on 'send', (channel, msg) ->
      channel.send(msg)

      #if not channel.send(msg)
      #  process.nextTick () =>
      #    console.log("Failed to send messsage. Trying again next tick.")
      #    slack_client.emit('send', channel, msg)


    slack_client.on 'message', (message) ->
      channel = slack_client.getChannelGroupOrDMByID(message.channel)
      {type, ts, text} = message
      console.log("New chat arrived : #{text} from #{channel}")
      unless is_control_message(text)
        robot.emit("session:chat_arrived", session_keys_by_channel[channel], text)
      else
        [session_key, action] = text.split(" ")
        switch action
          when "start"
            if session_key in Us.keys(clients_by_key)
              session_keys_by_channel[channel] = session_key
              channels_by_session_keys[session_key] = channel
              channel.send("The conversation with #{session_key} is now in this room.")
            else
              console.log("No session here?")

    slack_client.on 'error', (error) ->
      console.error "Slack client error: #{JSON.stringify(error)}"

    slack_client.login()
    slack_client

  robot.on "session:start", (session) ->
    filter =
      where:
        room:
          __type: "Pointer"
          className: "Room"
          objectId: session.room.objectId
        provider: 'slack'
    parse.find 'Integrations', filter, (err, response) ->
      if err?
        console.log("Integration search turned up error")
        console.log(err)
      else
        if response.results.count > 0
          integration = response.results[0]
          settings = JSON.parse(integration["settings"])
          session_key = session.session_key
          slack_client = slack_clients[integration.token]
          unless slack_client
            console.log("Creating new slack client with settings")
            console.log(settings["announce_channel"])
            slack_client = new_slack_client(integration.token, session_key, settings["announce_channel"])
            slack_clients[integration.token] = slack_client
            clients_by_key[session_key] = slack_client
          else
            clients_by_key[session_key] = slack_client
            slack_client.emit("announce", session_key)
        else
          console.log("No slack integration defined for this room.")

  robot.on "session:inbound_msg", (session, msg) ->
    session_key = session.session_key
    channel = channels_by_session_keys[session_key]
    slack_client = clients_by_key[session_key]
    if slack_client?
      slack_client.emit 'send', channel, msg

  robot.on "session:end", (session) ->
    session_announce_end(session.session_key)
