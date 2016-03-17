# Copyright (c) 2015, GreenBot
# Thomas Howe
_              = require('underscore')
Logger         = require('../logger')
Request        = require "request-promise"
Util           = require "util"
Express        = require('../express-server').app
Events         = require('../pubsub').pubsub

GH_TOKEN       = process.env.GH_TOKEN
GH_NUMBER      = process.env.GH_NUMBER
EGRESS_EVENT   = "grasshopper_egress"
WEBHOOK_PATH   = process.env.GH_WEBHOOK or '/inbound/gh'
NETWORK_NAME   = "gh"

Events.on EGRESS_EVENT, (msg) ->
  {src, dst, txt} = msg
  egressMsg GH_TOKEN, src, dst, txt

ghHandle = (handle) -> NETWORK_NAME+"::#{handle}"

ingressMsg = (ghMsg) ->
  msg =
    dst:          ghHandle ghMsg.vpsNumber
    src:          ghHandle ghMsg.otherNumber
    network:      NETWORK_NAME
    EGRESS_EVENT: EGRESS_EVENT
    txt:          ghMsg.body
  Events.emit     'ingress', msg

processGhMsgs  = () ->
  # Check for messages inbound from ZW
  getNewMessages(lastMessageAt).then (messages) ->
    return if messages.length is 0
    lastMessageAt = messages[0].timestamp
    ingressMsg(ghMsg) for ghMsg in messages

Express.post WEBHOOK_PATH, (req, res) ->
  ingressMsg(req.body)
  res.send 'OK'

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
    headers: Authorization: GH_TOKEN
    json: true
    qs:
      vpsNumber: encodeURI(GH_NUMBER)
      otherNumber: encodeURI(otherNumber)
  Request(options).then (messages) ->
    return (m for m in messages when Date.parse(m.timestamp) > epochTime and m.direction is "Inbound")

getConversationsSince = (timestamp) ->
  epochTime = Date.parse(timestamp)
  options =
    uri: "https://mnsq.ghuser.com/external/sms/conversations"
    method: "GET"
    headers: Authorization: GH_TOKEN
    json: true
    qs:
      vpsNumber: encodeURI(GH_NUMBER)
  Request(options).then (convos) ->
    convos = (c for c in convos when Date.parse(c.timestamp) > epochTime)
    return convos

egressMsg = (token, src, dst, txt) ->
  # extract telephone number
  src = src.split('::')[1]
  dst = dst.split('::')[1]
  options =
    uri: "https://mnsq.ghuser.com/external/sms"
    method: "POST"
    headers: Authorization: GH_TOKEN
    json: true
    body:
      vpsNumber: encodeURI(src)
      otherNumber: encodeURI(dst)
      body: txt
  Request(options)

if GH_NUMBER? and GH_TOKEN?
  Logger.info "Starting Grasshopper adapter"
  setInterval(processGhMsgs, 5000) unless WEBHOOK_PATH
  Logger.info "Waiting for GH Webhooks" if WEBHOOK_PATH
else
  Logger.info "Not starting Grasshopper adapter"
  Logger.info "No GH_TOKEN defined in environment" if not GH_TOKEN
  Logger.info "No GH_NUMBER defined in environment" if not GH_NUMBER
