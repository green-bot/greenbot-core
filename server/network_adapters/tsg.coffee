Logger = require('../logger')
TSG_SEND_MSG_URL = "http://sms.tsgglobal.com/jsonrpc"

# Global events object
Pubsub = require('../pubsub')
events = Pubsub.pubsub

ExpressServer = require '../express-server'
app = ExpressServer.app

Request = require 'request-promise'


egressEvent = "tsg_egress"

app.post '/networks/tsg', (req, res) ->
  remoteNumber = req.body.remote_number.replace("+","")
  hostNumber = req.body.host_number.replace("+","")
  txt = req.body.message

  res.writeHead 200,     "Content-Type": "text/plain"
  res.end()

  Logger.info 'Inbound message TSG: ' + txt

  msg =
    dst: "tsg::" + hostNumber
    src: "tsg::" + remoteNumber
    txt: txt
    egressEvent: egressEvent
  events.emit 'ingress', msg
  return

events.on egressEvent, (msg) ->
  Logger.info 'tsg egress: ' + msg.txt
  sendTsgMessage(msg)

Logger.info 'tsg server listening'


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
    Logger.info "Sent #{src}->#{dst}: #{txt}"
    if response.error?
      Logger.info "ERROR POSTING TO TSG:"
      Logger.info response
  #.catch (error) ->
    #Logger.info "ERROR POSTING TO TSG:" + error
