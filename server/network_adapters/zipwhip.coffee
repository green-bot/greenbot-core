# Copyright (c) 2015, Ten Digit Communications
# Thomas Howe
Logger = require('../logger')
Request = require "request-promise"
Util = require "util"

# Global events object
Pubsub = require('../pubsub')
events = Pubsub.pubsub

zwUser = process.env.ZW_NUMBER
zwPass = process.env.ZW_PASS

return unless zwUser and zwPass

startSession = (username, password) ->
  options =
    uri: "https://api.zipwhip.com/user/login"
    method: "POST"
    json: true
    form:
      username: username
      password: password
  Request(options)

startSession(zwUser, zwPass).then (session) ->
  zwSessionKey = session.response
  egressEvent = "zipwhip_egress"

  events.on egressEvent, (msg) ->
    {src, dst, txt} = msg
    Logger.info "Sending #{txt} to #{dst}"
    sendMsg zwSessionKey, dst, txt

  Logger.info "Started session : " + session.response
  setInterval () ->
    # Check for messages inbound from ZW
    getMessages(zwSessionKey).then (data) ->
      for zwMsg in data.response
        do (zwMsg) ->
          unless zwMsg.isRead
            msg =
              dst: "zipwhip::#{zwMsg.destAddress}"
              src: "zipwhip::#{zwMsg.sourceAddress}"
              network: "zipwhip"
              egressEvent: egressEvent
              txt: zwMsg.body

            Logger.info "ZipWhip INGRESS: #{JSON.stringify msg}"
            events.emit 'ingress', msg
            Logger.info "#{JSON.stringify msg}"
            Logger.info "[#{msg.src}->#{msg.dst}] #{msg.txt}"
            markAsRead(zwSessionKey, zwMsg.id)
  , 5000



getMessages = (sessionKey) ->
  options =
    uri: "https://api.zipwhip.com/message/list"
    method: "POST"
    json: true
    form:
      session: sessionKey
      limit: 30
  Request(options)


sendMsg = (sessionKey, dst, text) ->
  # extract telephone number
  dst = dst.split('::')[1]
  options =
    uri: "https://api.zipwhip.com/message/send"
    method: "POST"
    json: true
    form:
      session: sessionKey
      contacts: dst
      body: text
  Request(options)

markAsRead = (sessionKey, list) ->
  options =
    uri: "https://api.zipwhip.com/message/read"
    method: "POST"
    json: true
    form:
      messages: list
      session: sessionKey
  Request(options).then (resp) ->
    Logger.info "Cleared #{Util.inspect list}"
