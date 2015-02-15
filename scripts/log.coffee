Winston = require('winston')
Papertrail = require('winston-papertrail').Papertrail

module.exports = (robot) ->
  logger = new (Winston.Logger)(transports: [ new (Winston.transports.Papertrail)(
    host: 'logs2.papertrailapp.com'
    port: 48986) ])

  robot.on "log", (string) ->
    logger.info string
