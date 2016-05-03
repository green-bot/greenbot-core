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

