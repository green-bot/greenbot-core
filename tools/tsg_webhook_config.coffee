# Copyright (c) 2016, GreenBot

http = require('https')

show_help = ->
  console.log 'Usage : coffee tsg_webhook_config DID URL'
  process.exit(-1)

did = process.argv[2]
url = process.argv[3]
unless did? and url?
  show_help()

api_key = process.env.TSG_COBRA_KEY
unless api_key?
  console.log "Must specify TSG_COBRA_KEY in environment"
  process.exit(-1)

console.log "Pointing inbound messages from #{did} to #{url}"
options =
  'method': 'GET'
  'hostname': 'api.tsgglobal.net'
  'port': null
  'path': "/sms_posturl_update.php?did=#{did}&api_key=#{api_key}&posturl=#{url}"
  'headers':
    'content-type': 'application/json'

req = http.request(options, (res) ->
  chunks = []
  res.on 'data', (chunk) ->
    chunks.push chunk
    return
  res.on 'end', ->
    body = Buffer.concat(chunks)
    console.log body.toString()
    return
  return
)
req.end()
