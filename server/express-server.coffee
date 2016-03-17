Express = require 'express'
BodyParser = require 'body-parser'
Multer    = require 'multer'
Logger = require './logger'
Pubsub = require('./pubsub')
events = Pubsub.pubsub

app = Express()

app.use(BodyParser.json())
app.use(BodyParser.urlencoded({ extended: true }))
app.use(Multer())
expressPort = process.env.GREENBOT_BOT_SERVER_PORT or 3001
app.listen(3001)
Logger.info "Started express on port #{expressPort}"
exports.app = app
