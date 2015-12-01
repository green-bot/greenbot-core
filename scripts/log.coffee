# Description:
#   Handles logging.
#
# Dependencies:
#   Winston, Papertrail
#
# Configuration:
#   Done through ports
#
#
# Author:
#   Thomas Howe
#

Winston = require('winston')
Papertrail = require('winston-papertrail').Papertrail
testLogger = new (Winston.Logger)(
  transports: [ new (Winston.transports.Papertrail)(
    host: 'logs2.papertrailapp.com'
    port: 48986)
  ])

module.exports = (robot) ->
  logme = (text) ->
    testLogger.info text if testLogger?
    
  robot.on "log", (text) ->
    console.log text
    testLogger.info text
