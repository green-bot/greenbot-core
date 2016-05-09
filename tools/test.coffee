#!/usr/bin/env coffee

stdio = require 'stdio'
socketUrl = process.env.GB_SOCKET_URL or "http://127.0.0.1:3003"
consoleSrc = process.env.CONSOLE_SRC or 'console'
consoleDst = process.argv[2] or 'development::console'
keyword = process.argv[3] or 'default'
if process.argv[4]
  reps = parseInt( process.argv[4], 10 )
else
  reps = 1

io = require('socket.io-client')(socketUrl)
debug = require('debug')('test.coffee')

unless process.argv[1] and process.argv[2]
  debug "Usage : test <network::handle> <keyword> <reps>, using defaults"

debug "Connecting to #{socketUrl} as #{consoleSrc}"
debug "Starting conversation with #{consoleDst}, keyword #{keyword}"
debug "Send a CTL-C to end"

io.on 'connect', ->
  debug "Connected to #{socketUrl}"
io.on 'disconnect', ->
  debug "Disconnected from #{socketUrl}"
io.on 'egress', (msg) ->
  console.log msg.txt
io.on 'session:ended', (sess) ->
  debug 'Received a session end event'
  debug sess
  if sess.src is consoleSrc
    debug "Session ended"
    debug sess
    reps -= 1
    process.exit 0 if reps is 0

    # Otherwise, kick it off again
    sendMsg consoleSrc, consoleDst, keyword

sendMsg = (src, dst, txt) ->
  msg =
    dst: dst
    src: src
    txt: txt + "\n"
  io.emit 'ingress', msg

stdio.read (text) ->
  sendMsg consoleSrc, consoleDst, text

sendMsg consoleSrc, consoleDst, keyword
