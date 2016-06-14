Pubsub = require('./pubsub')
events = Pubsub.pubsub
debug = require('debug')('logger')


events.on 'log', (msg) ->
  debug msg

exports.info = (text) ->
  events.emit 'log',  text
