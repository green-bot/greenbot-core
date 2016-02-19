# Copyright (c) 2015, Ten Digit Communications
# Thomas Howe
_              = require('underscore')
Logger         = require('../logger')
Request        = require "request-promise"
Util           = require "util"

# Global events object
Pubsub = require('../pubsub')
events = Pubsub.pubsub

ghToken = process.env.GH_TOKEN
ghNumber = process.env.GH_NUMBER
egressEvent = "grasshopper_egress"
lastMessageAt = new Date()

processGhMsgs  = () ->
  # Check for messages inbound from ZW
  getNewMessages(lastMessageAt).then (messages) ->
    return if messages.length is 0
    lastMessageAt = messages[0].timestamp
    for ghMsg in messages
      do (ghMsg) ->
        msg =
          dst: "gh::#{ghMsg.vpsNumber}"
          src: "gh::#{ghMsg.otherNumber}"
          network: "gh"
          egressEvent: egressEvent
          txt: ghMsg.body
        events.emit 'ingress', msg

getNewMessages = (timestamp) ->
  getConversationsSince(timestamp)
  .then (conversations) ->
    numbers = []
    numbers.push convo.otherNumber for convo in conversations
    (getMessagesSince(num, timestamp) for num in numbers)
    # Returns an array of promises returned by getMessagesSince
  .then (promises) ->
    Promise.all(promises)
  .then (msgsArray) ->
    messages = []
    for msgs in msgsArray
      messages.push m for m in msgs
    _.sortBy(messages, 'timestamp')
  .catch (err) ->
    console.log "I have an error!"
    console.log err


getMessagesSince = (otherNumber, timestamp) ->
  epochTime = Date.parse(timestamp)
  options =
    uri: "https://mnsq.ghuser.com/external/sms"
    method: "GET"
    headers: Authorization: ghToken
    json: true
    qs:
      vpsNumber: encodeURI(ghNumber)
      otherNumber: encodeURI(otherNumber)
  Request(options).then (messages) ->
    return (m for m in messages when Date.parse(m.timestamp) > epochTime and m.direction is "Inbound")

getConversationsSince = (timestamp) ->
  epochTime = Date.parse(timestamp)
  options =
    uri: "https://mnsq.ghuser.com/external/sms/conversations"
    method: "GET"
    headers: Authorization: ghToken
    json: true
    qs:
      vpsNumber: encodeURI(ghNumber)
  Request(options).then (convos) ->
    convos = (c for c in convos when Date.parse(c.timestamp) > epochTime)
    return convos

sendMsg = (token, src, dst, txt) ->
  # extract telephone number
  src = src.split('::')[1]
  dst = dst.split('::')[1]
  options =
    uri: "https://mnsq.ghuser.com/external/sms"
    method: "POST"
    headers: Authorization: ghToken
    json: true
    body:
      vpsNumber: encodeURI(src)
      otherNumber: encodeURI(dst)
      body: txt
  Request(options)

if ghNumber? and ghToken?
  Logger.info "Starting Grasshopper adapter"
  events.on egressEvent, (msg) ->
    {src, dst, txt} = msg
    sendMsg ghToken, src, dst, txt

  setInterval processGhMsgs, 5000
else
  Logger.info "Not starting Grasshopper adapter"
  Logger.info "No GH_TOKEN defined in environment" if not process.env.GH_TOKEN
  Logger.info "No GH_NUMBER defined in environment" if not process.env.GH_NUMBER
