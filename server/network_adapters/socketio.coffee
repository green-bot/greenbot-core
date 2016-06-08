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
debug = require('debug')('socketio')

handleEgress = (msg) ->
  {dst, src, txt}  = msg
  debug "SOCKET EGRESS #{src}->#{dst}:#{txt}"
  io.emit 'egress', msg

handleEndSession = (sess) ->
  debug "Socket.io received a session ended event"
  debug sess
  io.emit 'session:ended', sess


io.on 'connection', (socket) ->
  egressEvent = 'socket-' + ShortUUID.generate()
  events.on egressEvent, handleEgress
  events.on 'session:ended', handleEndSession
  debug "A network client connected. Listening on #{egressEvent}"

  socket.on 'disconnect', () ->
    debug "Network client disconnected from #{egressEvent}"
    events.removeListener 'session:ended', handleEndSession
    events.removeListener egressEvent, handleEgress

  socket.on 'ingress', (msg) ->
    # Clean this sucker up. Make sure nothing icky gets in
    {dst, src, txt}  = msg
    debug "SOCKET INGRESS #{src}->#{dst}:#{txt}"
    msg =
      dst: dst
      src: src
      txt: txt
      egressEvent: egressEvent
    events.emit 'ingress', msg
debug "Started socket.io adapter"
