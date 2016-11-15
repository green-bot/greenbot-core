ExpressServer  = require './express-server'
Pubsub         = require './pubsub'

events = Pubsub.pubsub

app = ExpressServer.app

app.post '/api/installPackage', (req, res) ->
  packageName = req.body.packageName
  console.log "Requested npm pkg installation: #{ packageName }"
  events.emit("api:installPackage", packageName)
app.delete '/api/uninstallPackage', (req, res) ->
  packageName = req.body.packageName
  console.log "Requested npm pkg removal: #{ packageName }"
  events.emit("api:uninstallPackage", packageName)
app.delete '/api/killSession', (req, res) ->
  sessionIdentInfo = sessionId = req.body.sessionId
  sessionIdentInfo = {src: req.body.src, dst: req.body.dst} unless sessionId
  console.log "Requested we kill session :"
  console.log sessionIdentInfo
  events.emit 'api:killSession', sessionIdentInfo
