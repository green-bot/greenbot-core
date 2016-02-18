require('coffee-script')
Notify = require('./notify')
Slackbot = require('./slackbot')
Slack = require('./slack')
Session = require('./session')
Logger = require('./logger')
Bash = require('./bash-process')
Watson = require('./watson-process')
Matrix = require('./matrix')
Pubsub = require('./pubsub')
events = Pubsub.pubsub

RequireDir = require('require-dir')
RequireDir('./network_adapters')

events.emit 'log', "Greenbot started"
