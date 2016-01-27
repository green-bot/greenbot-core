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

    console.log 'Inbound message ' + msg
    msg =
      dst: '12183255075'
      src: 'telnet'
      txt: b.toString()
    events.emit 'telnet:ingress', msg
    return

  events.on "telnet:egress:telnet", (txt) ->
    client.write new Buffer txt + "\n"

  console.log 'Telnet server listening'
  return
).listen 3002
