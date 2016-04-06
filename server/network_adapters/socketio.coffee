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
MongoClient    = require('mongodb').MongoClient
SOCKET_PORT = process.env.GB_SOCKET_PORT or 3003
io = require('socket.io')(SOCKET_PORT)
events = Pubsub.pubsub

# Global scope so we can get it later.
botsDb = undefined
sessionsDb = undefined
integrationsDb= undefined

CONNECTION_STRING = process.env.MONGO_URL or
                    'mongodb://localhost:27017/greenbot'
MongoClient.connect(CONNECTION_STRING)
.then (db) ->
  sessionsDb = db.collection('Sessions')

handleEgress = (msg) ->
  {dst, src, txt}  = msg
  Logger.info "SOCKET EGRESS #{src}->#{dst}:#{txt}"
  io.emit 'egress', msg

handleEndSession = (sessionId) ->
  console.log "Got a session ended event"
  sessionsDb.find({ sessionId: sessionId }).limit(1).next()
  .then (sess) ->
    console.log "Sending session ended for #{sessionId}"
    io.emit 'session:ended', sess


io.on 'connection', (socket) ->
  egressEvent = 'socket-' + ShortUUID.generate()
  events.on egressEvent, handleEgress
  events.on 'session:ended', handleEndSession
  Logger.info "A network client connected. Listening on #{egressEvent}"

  socket.on 'disconnect', () ->
    Logger.info "Network client disconnected from #{egressEvent}"
    events.removeListener 'session:ended', handleEndSession
    events.removeListener egressEvent, handleEgress

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
Logger.info "Started socket.io adapter"
