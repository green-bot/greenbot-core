#
# Author : Thomas Howe
#
# The file that contains the database singleton

connection_string = process.env.MONGO_URL or 'localhost/greenbot'

module.exports = ( robot ) ->
  # Connect to the local mongo database
  client = require('monk')(connection_string)
