#!/usr/bin/env coffee

prompt = require 'prompt'
socketUrl = process.env.GB_SOCKET_URL or "http://127.0.0.1:3003"
consoleSrc = process.env.CONSOLE_SRC or 'console'
consoleDst = process.argv[2] or 'development::console'
keyword = process.argv[3] or 'default'
io = require('socket.io-client')(socketUrl)

unless process.argv[1] and process.argv[2]
  console.log "Usage : test <network::handle> <keyword>, using defaults"

console.log "Connecting to #{socketUrl} as #{consoleSrc}"
console.log "Starting conversation with #{consoleDst}, keyword #{keyword}"
console.log "Send a CTL-C to end"

io.on 'connect', ->
  console.log "Connected to #{socketUrl}"
io.on 'disconnect', ->
  console.log "Disconnected from #{socketUrl}"
io.on 'egress', (msg) ->
  console.log msg.txt
io.on 'session:ended', (sess) ->
  if sess.src is consoleSrc
    console.log "Session ended"
    console.log sess

sendMsg = (src, dst, txt) ->
  msg =
    dst: dst
    src: src
    txt: txt + "\n"
  io.emit 'ingress', msg

errHandler =  (err) ->
  console.log "Error from prompt"
  console.log err
  return

handleMsg = (err, result) ->
  sendMsg consoleSrc, consoleDst, result.input
  prompt.get ['input'], handleMsg

prompt.start()
prompt.get ['input'], handleMsg
