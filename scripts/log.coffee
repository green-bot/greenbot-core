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

module.exports = (robot) ->
  winston = new (Winston.Logger)(
    transports: [ new (Winston.transports.Papertrail)(
      host: 'logs2.papertrailapp.com'
      port: 48986)
    ])

  robot.on "log", (text) ->
    console.log text
    winston.info text
