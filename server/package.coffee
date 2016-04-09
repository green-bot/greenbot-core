Request        = require("request-promise")
Mailer         = require("nodemailer")
Util           = require('util')
Pubsub         = require('./pubsub')
Logger         = require('./logger')
MongoClient    = require('mongodb').MongoClient
events         = Pubsub.pubsub
Fs             = require('fs')
Chokidar       = require('chokidar')
CP             = require('child_process')

MONGO_URL = process.env.MONGO_URL or 'mongodb://localhost:27017/greenbot'
NPM_PATH =  process.env.GREENBOT_NPM_PATH or './node_modules/'

errorHandler = (desc, err) ->
  Logger.info desc
  Logger.info err

trace = (desc, obj) ->
  if process.env.TRACE_MESSAGES?
    Logger.info desc
    Logger.info Util.inspect(obj) if obj?

removeScript = (pkg) ->
  MongoClient.connect(MONGO_URL)
  .then (db) ->
    scripts  = db.collection('Scripts')
    scripts.remove npm_pkg_name: pkg
    .then ->
      Logger.info "Script #{pkg} removed"
      db.close()

addScript = (pkg, path) ->
  Logger.info "Loading #{pkg} from #{path}"
  MongoClient.connect(MONGO_URL)
  .then (db) ->
    Logger.info "Connected to DB"
    scripts  = db.collection('Scripts')

    # Clean up any old records
    scripts.remove npm_pkg_name: pkg

    # Likely that JSON file is up to no good. Catch the
    # error and display to user
    jsonFileLocation = NPM_PATH + path
    try
      script = JSON.parse(Fs.readFileSync(jsonFileLocation))[0]
    catch error
      Logger.info "Error in reading #{jsonFileLocation}"
      Logger.info error
      db.close()
      Logger.info "Disconnected from DB"
      return

    # Add the defaults proper to an NPM pacakge
    packagePath = NPM_PATH + pkg
    script.npm_pkg_name = pkg
    script.npm_pkg_location = packagePath
    script.default_cmd = 'npm start --loglevel silent'
    script.default_path = packagePath
    scripts.insert script, ->
      db.close()
      Logger.info "Disconnected from DB"

Chokidar.watch '*/bot.json', cwd: NPM_PATH
.on 'add', (path) ->
  Logger.info "Found #{path} has changed"
  pkg = path.split('/').shift()
  addScript pkg, path
.on 'unlink', (path) ->
  removeScript path.split('/').shift()

# Update the database to indicate what our local node directory is
MongoClient.connect(MONGO_URL)
.then (db) ->
  Logger.info "Connected to DB. Updating npm directory path"
  CP.exec 'npm root', (error, stdout, stderr) ->
    if error
      Logger.info "Thrown error in call to npm root"
      return
    if stderr
      Logger.info "STDERR: #{stderr}"
    path = stdout.trim()
    setting =
      type:   'NODE_PATH'
      val:    path.replace(/(\r\n|\n|\r)/gm,"")
    db.collection('ServerSettings').update { type:     'NODE_PATH' },
                                           setting, { upsert:   true }
    .then (setting) ->
      Logger.info "Inserted #{path}"
      db.close()
    .catch (error) ->
      Logger.info "Error in saving NPM root : #{error}"
      db.close()
