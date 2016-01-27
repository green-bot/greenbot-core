Pubsub = require('./pubsub')
events = Pubsub.pubsub

events.on 'log', (msg) ->
  console.log msg
