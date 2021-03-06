# Description:
#   Connects greenbot to Telnet
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

Telnet = require('telnet')
ShortUUID = require 'shortid'

# Global events object
Pubsub = require('../pubsub')
events = Pubsub.pubsub

Telnet.createServer((client) ->
  sessionId = ShortUUID.generate()
  egressEvent = 'telnet'
  client.on 'data', (b) ->
    msg = b.toString()

    events.emit 'log',  'Inbound message ' + msg
    msg =
      dst: process.env.DEV_ROOM_NAME or 'development::telnet'
      src: 'telnet'
      txt: b.toString()
      egressEvent: egressEvent
    events.emit 'ingress', msg
    return
  client.on 'error', (e) ->
    if e.code is "ECONNRESET"
      console.log("Client quit unexpectedly; ignoring exception.")
      return

    console.log("Exception encountered:")
    console.log(e.code)
    process.exit(1)

  events.on egressEvent, (msg) ->
    events.emit 'log', 'Local telnet egress' + msg.txt
    client.write new Buffer msg.txt + "\n"

  events.emit 'log',  'Telnet server listening'
  return
).listen 3002
