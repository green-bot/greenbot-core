Express = require 'express'
BodyParser = require 'body-parser'
Multer    = require 'multer'

app = Express()

app.use(BodyParser.json())
app.use(BodyParser.urlencoded({ extended: true }))
app.use(Multer())

app.listen(process.env.GREENBOT_BOT_SERVER_PORT or 3001)

exports.app = app
