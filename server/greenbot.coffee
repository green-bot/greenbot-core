require('coffee-script')
Notify = require('./notify')
Session = require('./session')
Logger = require('./logger')
Bash = require('./bash-process')
Watson = require('./watson-process')
Matrix = require('./matrix')
Pubsub = require('./pubsub')
events = Pubsub.pubsub
PackageMgr = require('./package')

RequireDir = require('require-dir')
RequireDir('./network_adapters')

require './http-api'

Logger.info "Greenbot started"
