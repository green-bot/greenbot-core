# Copyright (c) 2016, greenbot

_              = require('underscore')
Async          = require('async')
Bluebird       = require('bluebird')
Logger         = require('../logger')
MongoClient    = require('mongodb').MongoClient
Os             = require("os")
Promise        = require('node-promise').Promise
Pubsub         = require('../pubsub')
ShortUUID      = require('shortid')
Url            = require("url")
Util           = require('util')
Request        = require("request-promise")
ExpressServer  = require '../express-server'
debug          = require('debug')('tsg')

# Before any of this stuff happens, see if we are configured for
# TSG

configured = true
configured = false unless process.env.TSG_CALLBACK_HOST?
configured = false unless process.env.TSG_SECRET?
configured = false unless process.env.TSG_COBRA_KEY?

if not configured
  debug "No TSG Credentials"
  return

debug 'Configuring the TSG Adapter'

TSG_SEND_MSG_URL = "http://sms.tsgglobal.com/jsonrpc"
CONNECTION_STRING = process.env.MONGO_URL or
                    'mongodb://localhost:27017/greenbot'
CALLBACK_PATH = '/networks/tsg'
TSG_CALLBACK_URL = process.env.TSG_CALLBACK_HOST + CALLBACK_PATH

events = Pubsub.pubsub
app = ExpressServer.app
egressEvent = "tsg_egress"

app.post CALLBACK_PATH, (req, res) ->
  remoteNumber = req.body.remote_number.replace("+","")
  hostNumber = req.body.host_number.replace("+","")
  txt = req.body.message
  res.writeHead 200,     "Content-Type": "text/plain"
  res.end()
  debug 'Inbound message TSG: ' + txt

  msg =
    dst: "tsg::" + hostNumber
    src: "tsg::" + remoteNumber
    txt: txt + "\n"
    egressEvent: egressEvent
  events.emit 'ingress', msg
  return

events.on egressEvent, (msg) ->
  debug 'tsg egress: ' + msg.txt
  sendTsgMessage(msg)
debug 'tsg server listening'

sendTsgMessage = (msg) ->
  {src, dst, txt} = msg
  src = src.split('::')[1]
  dst = dst.split('::')[1]

  options =
    uri: TSG_SEND_MSG_URL
    qs:
      key: process.env.TSG_SECRET
    body:
      method: "sms.send"
      id: 0
      params: [src, dst, txt, 1]
    json: true

  Request.post(options)
  .then (response) ->
    debug "Sent #{src}->#{dst}: #{txt}"
    if response.error?
      debug "ERROR POSTING TO TSG:"
      debug response

registeredNumbers = []

checkAddresses = (db) ->
  debug 'Checking for new addresses'
  botsDb = db.collection('Bots')
  botsDb.find 'addresses.network': 'tsg'
  .each (err, bot) ->
    if err
      debug "Mongo client threw error"
      debug err
      return
    unless bot
      return

    debug 'Checking bot ', bot._id
    for address in bot.addresses
      if /tsg/i.test address.networkHandleName
        debug 'Found TSG address in ', address.networkHandleName
        unless address.networkHandleName in registeredNumbers
          registeredNumbers.push address.networkHandleName
          did = address.networkHandleName.split("::").pop()
          api_key = process.env.TSG_COBRA_KEY
          url = TSG_CALLBACK_URL

          # Now set the callback to this number to this
          # machine
          debug "Settings callback for #{did} to #{TSG_CALLBACK_URL}"
          options =
            uri: 'https://api.tsgglobal.net/sms_posturl_update.php'
            qs:
              did:      did
              api_key:  api_key
              posturl:  TSG_CALLBACK_URL
            json: true
          Request.get(options)
          .then (response) ->
            if response.error?
              debug "ERROR POSTING TO TSG:"
              debug response
            else
              debug "TSG Responds"
              debug response
      else
        debug 'Already registered.'

MongoClient.connect(CONNECTION_STRING)
  .then (db) ->
    setInterval checkAddresses, 4000, db

MongoClient.connect(CONNECTION_STRING)
.then (db) ->
  networks = db.collection('Networks')
  networkObj = name: 'tsg'
  networks.update networkObj, networkObj, upsert: true
  .then ->
    db.close()
