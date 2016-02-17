require('coffee-script')
Notify = require('./notify')
Slackbot = require('./slackbot')
Slack = require('./slack')
Session = require('./session')
Telnet = require('./network_adapters/localtelnet')
require('./network_adapters/zipwhip')
Logger = require('./logger')
Bash = require('./bash-process')
Watson = require('./watson-process')
Matrix = require('./matrix')
Pubsub = require('./pubsub')
events = Pubsub.pubsub

events.emit 'log', "Greenbot started"
