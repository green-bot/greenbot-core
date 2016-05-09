Pubsub = require('./pubsub')
events = Pubsub.pubsub
Memwatch = require('memwatch-next')
debug = require('debug')('monitor')


Memwatch.on 'leak', (info) ->
  debug 'Memwatch leak info:'
  debug info

Memwatch.on 'stats', (info) ->
  debug 'Memwatch stats info:'
  debug info
