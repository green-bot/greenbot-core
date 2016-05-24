# Copyright (c) 2016, GreenBot
# Thomas Howe
_              = require('underscore')
Logger         = require('../logger')
Request        = require "request-promise"
Util           = require "util"
ExpressServer  = require('../express-server')
events         = require('../pubsub').pubsub
debug          = require('debug')('gh')
MongoClient    = require('mongodb').MongoClient
Crypto         = require('crypto')

GH_TOKEN       = process.env.GH_TOKEN
GH_NUMBER      = process.env.GH_NUMBER
EGRESS_EVENT   = "gh_egress"
WEBHOOK_PATH   = process.env.GH_WEBHOOK or '/networks/gh'
NETWORK_NAME   = "gh"
MONGO_URL      = process.env.MONGO_URL or 'mongodb://localhost:27017/greenbot'
app            = ExpressServer.app

configured = true
configured = false unless process.env.GH_NUMBER?
configured = false unless process.env.GH_TOKEN?
configured = false unless process.env.GH_VENDOR_ID?

if not configured
  debug "No GH Credentials"
  return

debug 'Configuring the GH Adapter'
MongoClient.connect(MONGO_URL)
.then (db) ->
  networks = db.collection('Networks')
  networkObj = name: 'gh'
  networks.update networkObj, networkObj, upsert: true
  .then ->
    db.close()

events.on EGRESS_EVENT, (msg) ->
  {src, dst, txt} = msg
  egressMsg GH_TOKEN, src, dst, txt

ghHandle = (handle) -> NETWORK_NAME+"::#{handle}"

ingressMsg = (ghMsg) ->
  msg =
    dst:          ghHandle ghMsg.to
    src:          ghHandle ghMsg.from
    egressEvent:  EGRESS_EVENT
    txt:          ghMsg.body
  events.emit     'ingress', msg

app.post WEBHOOK_PATH, (req, res) ->
  debug 'Inbound message from GH'
  debug req.body
  ingressMsg(req.body)
  res.send 'OK'

authToken = (botnumber) ->
  timestamp = Math.floor(Date.now()/1000)
  id =JSON.stringify {
    vendorID:   process.env.GH_VENDOR_ID
    botNumber:  botnumber
    timestamp:  timestamp}
  hmac = Crypto.createHmac('sha256', process.env.GH_TOKEN)
  hmac.update(id)
  tok = JSON.stringify {
    key: hmac.digest('base64')
    id: id }
  return "OAuth " + Buffer.from(tok, 'ascii').toString('base64')

egressMsg = (token, src, dst, txt) ->
  # extract telephone number
  src = src.split('::')[1]
  dst = dst.split('::')[1]
  options =
    uri: "https://mnsq.ghuser.com/bot/message"
    method: "POST"
    headers: Authorization: authToken(src)
    json: true
    body:
      from: encodeURI(src)
      to: encodeURI(dst)
      body: txt
  Request(options)
  .catch (err) ->
    debug "GH Send Message Error"
    debug err
  .then (resp) ->
    debug "GH Send message sucess"
    debug resp
