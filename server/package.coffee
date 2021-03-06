Request        = require("request-promise")
Mailer         = require("nodemailer")
Util           = require('util')
Logger         = require('./logger')
MongoConnection = require('./mongo-singleton')
Promise        = require('es6-promise').Promise
Fs             = require('fs')
Chokidar       = require('chokidar')
CP             = require('child_process')
glob           = require("glob")
Random         = require('meteor-random')
Pubsub         = require './pubsub'

_              = require("underscore")
events         = Pubsub.pubsub


events.on 'api:installPackage', (packageName)->
  console.log "Got install package request from the api: npm install #{packageName}"
  CP.exec "npm install #{packageName}", (error, stdout, stderr) ->
    if error
      Logger.info "Thrown error in call to npm install"
      Logger.info error
    if stderr
      Logger.info "STDERR: #{stderr}"

events.on 'api:uninstallPackage', (packageName) ->
  console.log "Got remove package request from the api: npm uninstall #{packageName}"
  CP.exec "npm uninstall #{packageName}", (error, stdout, stderr) ->
    if error
      Logger.info "Thrown error in call to npm uninstall"
      Logger.info error
    if stderr
      Logger.info "STDERR: #{stderr}"

NPM_PATH =  process.env.GREENBOT_NPM_PATH or './node_modules/'

errorHandler = (desc, err) ->
  Logger.info desc
  Logger.info err

trace = (desc, obj) ->
  if process.env.TRACE_MESSAGES?
    Logger.info desc
    Logger.info Util.inspect(obj) if obj?

removeScript = (pkg) ->
  Logger.info "Removing #{pkg}"
  MongoConnection()
  .then (db) ->
    scripts  = db.collection('Scripts')
    scripts.find({npm_pkg_name: pkg}).limit(1).next()
    .then (script) ->
      scripts.remove npm_pkg_name: pkg
      bots  = db.collection('Bots')
      bots.update {scriptId: script._id}, {$set: {scriptId: null}}
    .then ->
      Logger.info "Script #{pkg} removed"
  .catch (err) ->
    Logger.info "Error in addScriptIfMissing #{pkgName}"
    Logger.info err

addScript = (pkg, path) ->
  Logger.info "Loading #{pkg} from #{path}"
  MongoConnection()
  .then (db) ->
    scripts  = db.collection('Scripts')
    scripts.deleteMany {npm_pkg_name: pkg}
    .then ->
      file = NPM_PATH + path
      try
        script = JSON.parse(Fs.readFileSync(file))[0]
      catch error
        Logger.info "Error in reading #{file}"
        Logger.info error
        return
      # Add the defaults proper to an NPM pacakge
      packagePath = NPM_PATH + pkg
      script.npm_pkg_name = pkg
      script.npm_pkg_location = packagePath
      script.default_cmd = 'npm start --loglevel silent'
      script.default_path = packagePath
      script._id = Random.id()

      readme = ''
      try
        bufData = Fs.readFileSync  packagePath + '/README.md'
        readme = bufData.toString()
      script.readme = readme

      Logger.info "Inserted into the DB"
      Logger.info script
      scripts.insert script
    .catch (err) ->
      Logger.info "Error thrown in add script"
      Logger.info err

addScriptIfMissing = (file) ->
  pkgName = file.split('/').shift()
  MongoConnection()
  .then (db) ->
    scriptsDb  = db.collection('Scripts')
    scriptsDb.count({npm_pkg_name: pkgName})
  .then (numScripts) ->
    unless numScripts is 0
      Logger.info "#{pkgName} installed"
      return
    Logger.info "Installing #{pkgName}"
    addScript pkgName, file
  .catch (err) ->
    Logger.info "Error in addScriptIfMissing #{pkgName}"
    Logger.info err

# On startup, look for pre-existing packages so we
# can tell if anything changed
Logger.info NPM_PATH + '*/bot.json'
glob '**/bot.json', {cwd: NPM_PATH}, (err, files) ->
  packages = files.map (file) -> file.split('/').shift()
  Logger.info "Found #{packages}"
  _.each files, addScriptIfMissing
  MongoConnection()
  .then (db) ->
    Logger.info "Removing scripts that have been uninstalled."
    scriptsDb  = db.collection('Scripts')
    scriptsDb.find()
    .each (err, script) ->
      throw err if err 
      return unless script
      Logger.info "Checking #{script.npm_pkg_name} to see if it is installed."
      removeScript(script.npm_pkg_name) if script.npm_pkg_name not in packages
  .catch (err) ->
    Logger.info "Error in finding packages"
    Logger.info err

Chokidar.watch('*/bot.json', {cwd: NPM_PATH, ignoreInitial: true})
.on 'add', (path) ->
  Logger.info "Found #{path} has changed"
  pkg = path.split('/').shift()
  addScript pkg, path
.on 'unlink', (path) ->
  removeScript path.split('/').shift()

# Update the database to indicate what our local node directory is
MongoConnection()
.then (db) ->
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
      Logger.info "Inserted node path #{path} into server settings"
    .catch (error) ->
      Logger.info "Error in saving NPM root : #{error}"
