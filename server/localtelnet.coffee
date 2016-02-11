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
Pubsub = require('./pubsub')
events = Pubsub.pubsub

Telnet.createServer((client) ->
  sessionId = ShortUUID.generate()
  client.on 'data', (b) ->
    msg = b.toString()

    events.emit 'log',  'Inbound message ' + msg
    msg =
      dst: process.env.DEV_ROOM_NAME or 'development'
      src: 'telnet'
      txt: b.toString()
    events.emit 'ingress', msg
    return

  events.on "telnet", (txt) ->
    events.emit 'log', 'Local telnet egress' + txt
    client.write new Buffer txt + "\n"

  events.emit 'log',  'Telnet server listening'
  return
).listen 3002
