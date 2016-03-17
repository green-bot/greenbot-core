require('coffee-script')
Notify = require('./notify')
Session = require('./session')
Logger = require('./logger')
Bash = require('./bash-process')
Watson = require('./watson-process')
Matrix = require('./matrix')
Pubsub = require('./pubsub')
events = Pubsub.pubsub
Express = require('./express-server')

RequireDir = require('require-dir')
RequireDir('./network_adapters')

Logger.info "Greenbot started"
