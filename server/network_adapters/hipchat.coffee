# Copyright (c) 2016, greenbot

_              = require 'underscore'
Async          = require 'async'
Bluebird       = require 'bluebird'
Logger         = require '../logger'
MongoClient    = require('mongodb').MongoClient
Os             = require 'os'
Promise        = require('node-promise').Promise
Pubsub         = require '../pubsub'
ShortUUID      = require 'shortid'
Url            = require 'url'
Util           = require 'util'
Request        = require 'request-promise'
ExpressServer  = require '../express-server'

CONNECTION_STRING = process.env.MONGO_URL or
                    'mongodb://localhost:27017/greenbot'
CALLBACK_PATH = '/networks/hipchat'
HIPCHAT_CALLBACK_URL = process.env.HIPCHAT_CALLBACK_HOST + CALLBACK_PATH

events = Pubsub.pubsub
app = ExpressServer.app
egressEvent = 'hipchat_egress'

app.post CALLBACK_PATH, (req, res) ->
  # parse hipchat message
  data = req.body.item
  hipchatUser = data.message.from.id
  hipchatRoom = data.room.id
  txt = req.body.message.message
  res.writeHead 200, "Content-Type": "text/plain"
  res.end()
  Logger.info 'Inbound message hipchat: ' + txt

  msg =
    dst: "hipchat::" + hipchatRoom
    src: "hipchat::" + hipchatUser
    txt: txt
    egressEvent: egressEvent
  events.emit 'ingress', msg
  return

events.on egressEvent, (msg) ->
  Logger.info 'hipchat egress: ' + msg.txt
  sendHipchatMessage msg

Logger.info 'hipchat server listening'

sendMessageUrlFor = (dst) ->
  "/v2/room/#{dst}/message"

sendHipchatMessage = (msg) ->
  {src, dst, txt} = msg
  src = src.split('::')[1]
  dst = dst.split('::')[1]

  options =
    uri: sendMessageUrlFor dst
    qs:
      auth_token: process.env.HIPCHAT_AUTH_TOKEN
    body:
      message: txt
    json: true

  Request.post(options).then (response) ->
    Logger.info "Sent #{src}->#{dst}: #{txt}"
    if response.error?
      Logger.info "ERROR POSTING TO HIPCHAT:"
      Logger.info response

registeredNumbers = []

client = undefined
getClient = () ->
  if client
    promise = new Promise()
    promise.resolve client
    promise
  else
    MongoClient.connect(CONNECTION_STRING).then (db) ->
      client = db
      return client

updateBotWebhooks = (bot) ->
  for address in bot.addresses
    if /hipchat/i.test address.networkHandleName
      unless address.networkHandleName in registeredNumbers
        registeredNumbers.push address.networkHandleName
        roomName = address.networkHandleName.split("::").pop()
        api_key = process.env.HIPCHAT_API_KEY
        url = HIPCHAT_CALLBACK_URL

        # Now set the callback to this number to this machine
        Logger.info "Settings callback for #{roomName} to #{HIPCHAT_CALLBACK_URL}"
        options =
          uri: "/v2/room/#{roomName}/extension/webhook/#{roomName}"
          body:
            url: url
            event: 'room_message'
          qs:
            auth_token: process.env.HIPCHAT_AUTH_TOKEN
          json: true
        Request.put(options).then (response) ->
          if response.error?
            Logger.info "ERROR POSTING TO HIPCHAT:"
            Logger.info response
          else
            Logger.info "Hipchat Responds"
            Logger.info response

updateWebhooks = ->
  getClient().then (db) ->
    botsDb = db.collection 'Bots'
    botsDb.find 'addresses.network': 'hipchat'
    .each (err, bot) ->
      if err
        console.log "Mongo client threw error"
        console.log err
        return
      return unless bot
      updateBotWebhooks bot

setInterval updateWebhooks, 4000
