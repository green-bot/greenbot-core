Pubsub = require('./pubsub')
events = Pubsub.pubsub

events.on 'log', (msg) ->
  console.log msg
  
exports.info = (text) ->
  events.emit 'log',  text
