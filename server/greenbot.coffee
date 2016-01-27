require('coffee-script')
Notify = require('./notify')
Slackbot = require('./slackbot')
Slack = require('./slack')
Session = require('./session')
Telnet = require('./localtelnet')
Logger = require('./logger')
Bash = require('./bash-process')

Pubsub = require('./pubsub')
events = Pubsub.pubsub

events.emit 'log', "Greenbot started"
