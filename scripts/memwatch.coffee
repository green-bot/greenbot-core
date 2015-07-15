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

Memwatch = require('memwatch-next')
module.exports = (robot) ->
  Memwatch.on 'leak', (info) ->
    robot.emit "log", "Leak detected: #{JSON.stringify info}"

  Memwatch.on 'stats', (stats) ->
    robot.emit "log", "Memwatch stats : #{JSON.stringify stats}"

  robot.emit "log", "Memwatch started"
