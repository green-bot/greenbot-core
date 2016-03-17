# Description:
#   Connects greenbot to adapters over sockets
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
Logger = require('../logger')
Pubsub = require('../pubsub')
ShortUUID = require('shortid')
SOCKET_PORT = process.env.GB_SOCKET_PORT or 3003
io = require('socket.io')(SOCKET_PORT)

events = Pubsub.pubsub

io.on 'connection', (socket) ->
  egressEvent = 'socket-' + ShortUUID.generate()
  Logger.info "A network client connected. Listening on #{egressEvent}"
  socket.on 'disconnect', () ->
    Logger.info 'Network client disconnected'
  socket.on 'ingress', (msg) ->
    # Clean this sucker up. Make sure nothing icky gets in
    {dst, src, txt}  = msg
    Logger.info "SOCKET INGRESS #{src}->#{dst}:#{txt}"
    msg =
      dst: dst
      src: src
      txt: txt
      egressEvent: egressEvent
    events.emit 'ingress', msg
  events.on egressEvent, (msg) ->
    {dst, src, txt}  = msg
    Logger.info "SOCKET EGRESS #{src}->#{dst}:#{txt}"
    io.emit 'egress', msg

Logger.info "Started socket.io adapter"
