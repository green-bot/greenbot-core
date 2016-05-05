# Description:
#   Handles session aware dialogs.
#
# Dependencies:
#
# Configuration:
#
# Commands:
#
# Author:
#   Thomas Howe - ghostofbasho@gmail.com
#

_              = require('underscore')
Async          = require('async')
Bluebird       = require('bluebird')
ChildProcess   = require("child_process")
LanguageFilter = require('watson-translate-stream')
Logger         = require('./logger')
Mailer         = require("nodemailer")
MongoClient    = require('mongodb').MongoClient
Os             = require("os")
Pipe           = require("multipipe")
Promise        = require('node-promise')
Redis          = require('redis')
ShortUUID      = require('shortid')
Stream         = require('stream')
Url            = require("url")
Us             = require("underscore.string")
Util           = require('util')
Random = require('meteor-random')

#DBLogger = require('mongodb').Logger
#DBLogger.setLevel('debug')

# Global events object
Pubsub = require('./pubsub')
events = Pubsub.pubsub

# Setup the connect to Redis
Bluebird.promisifyAll(Redis.RedisClient.prototype)
Bluebird.promisifyAll(Redis.Multi.prototype)
redisPort      = process.env.REDIS_PORT or 6379
redisHost      = process.env.REDIS_HOST or 'localhost'
client        = Redis.createClient(redisPort, redisHost)
egressClient  = Redis.createClient(redisPort, redisHost)
sessionClient = Redis.createClient(redisPort, redisHost)

INGRESS_MSGS_FEED  = 'INGRESS_MSGS'
EGRESS_MSGS_FEED   = 'EGRESS_MSGS'
NEW_SESSIONS_FEED  = 'NEW_SESSIONS'
SESSION_ENDED_FEED = 'COMPLETED_SESSIONS'

# Set the default directory for scripts
DEF_SCRIPT_DIR = process.env.DEF_SCRIPT_DIR || './scripts/'
CONNECTION_STRING = process.env.MONGO_URL or
                    'mongodb://localhost:27017/greenbot'

genSessionKey = (msg) -> msg.src + "_" + msg.dst
cleanText     = (text = "") -> text.trim().toLowerCase()
isJson = (str) ->
  # When a text message comes from a session, if it's a valid JSON
  # string, we will treat it as a command or data. This function
  # allows us to figure that out.
  try
    JSON.parse str
  catch e
    return false
  true

errorHandler = (desc, err) ->
  Logger.info desc
  Logger.info err

trace = (desc, obj) ->
  if process.env.TRACE_MESSAGES?
    Logger.info desc
    Logger.info Util.inspect(obj) if obj?


class Session
  @active = {}

  @connectDb = (url) ->
    # Setup the connection to the database
    MongoClient.connect(url)
    .then (@db) =>
      Logger.info "Connected to the DB"
      @botsDb     = @db.collection('Bots')
      @sessionsDb = @db.collection('Sessions')
      @scriptsDb  = @db.collection('Scripts')

    .catch (err) ->
      Logger.info "Cannot connect to DB. Fail"
      exit -1

  @findById = (id) ->
    for key, session of Session.active
      return session if session.id is id

  @findByKey = (key) ->
    Session.active[key]

  @findBot = (handle, keyword) ->
    Session.botsDb.find
      $and: [
        'addresses.networkHandleName': handle,
        'addresses.keywords': $in: [keyword]
      ]
    .limit(1).next()

  @allKeywords = (handle) ->
    Session.botsDb.find 'addresses.networkHandleName': handle
    .toArray()
    .then (bots) ->
      Logger.info 'Found the following bots in keywords'
      Logger.info bots
      keywords = []
      for bot in bots
        for a in bot.addresses
          Logger.info 'Checking out address'
          Logger.info a
          keywords = keywords.concat a.keywords if a.networkHandleName is handle
      Logger.info 'Found keywords'
      Logger.info keywords
      return keywords

  @findOrCreate = (msg, cb) ->
    # All messages that come from the network end up here.
    sessionKey = genSessionKey(msg)
    session = Session.findByKey(sessionKey)
    if session
      # We already have a session, so send it off.
      trace "Session exists, send it off"
      session.ingressMsg(msg.txt)
    else
      # No session active. Kick one off.
      name = msg.dst.toLowerCase()
      keyword = cleanText(msg.txt)

      Session.findBot(name, keyword)
      .then (bot) ->
        return bot if bot
        Logger.info "Hmmm. Keep looking."
        Session.findBot(name, 'default')
      .then (bot) ->
        unless bot
          trace "No default keyword set for that network handle."
          return
        trace "This is the bot I am looking for. Creating session", bot
        new Session(msg, bot, cb)
      .catch (err) -> errorHandler("Error thrown in finding the bot", err)

  constructor: (@msg, @bot, @cb) ->
    Logger.info "Constructing the session"
    # The variables that make up a Session
    @transcript = []
    @createdAt = new Date()
    @src = @msg.src
    @dst = @msg.dst.toLowerCase()
    @sessionKey = genSessionKey(@msg)
    @id = Random.id()
    Session.active[@sessionKey] = @
    @automated = true
    @processStack = []
    @networkHandleName = @msg.dst.toLowerCase()

    # Get the other keywords that also match
    # this network handle.
    Session.allKeywords(@networkHandleName)
    .then (keywords) =>
      Logger.info 'Other keywords happen to be'
      Logger.info keywords
      @keywords = keywords
    .then () =>
      # Assemble the @command, @arguments, @opts
      Session.sessionsDb.findOne({src: @src}, {sort: {updatedAt: -1}})
    .then (session) =>
      return err if err?
      if session?.lang?
        @lang = session.lang
      else
        @lang = process.env.DEFAULT_LANG or 'en'
      trace 'Language selection ', @lang
    .then =>
      @createSessionEnv()
    .then =>
      @kickOffProcess(@command, @arguments, @opts, @lang)
    .then ->
      Logger.info "Session started"
    .catch (err) -> errorHandler("Error in session constructor", err)

  createSessionEnv: =>
    trace "Starting session ENV", @
    trace "Scripts collection", Session.scriptsDb
    trace "Bot looks like", @bot
    trace "All keywords", @keywords
    Session.scriptsDb.findOne( { _id: @bot.scriptId })
    .then (script) =>
      trace("Just got the script", script)
      @script = script
      if @isOwner() and not @bot.testMode
        @arguments  = @script.owner_cmd.split(" ")
      else
        @arguments  = @script.default_cmd.split(" ")

      @command = @arguments[0]
      @arguments.shift()
      @env = @cmdSettings()
      @env.INITIAL_MSG = @msg.txt
      @env.ALL_KEYWORDS = @keywords.join(',')
      @opts =
        cwd: @script.default_path
        env: @env
      Session.botsDb.update {_id: @bot.scriptId}, testMode:false
    .catch (err) -> errorHandler("Error thrown in createSessionEnv", err)


  kickOffProcess : (command, args, opts, lang) =>
    Logger.info "Kicking off session as #{command} #{args} in #{lang}"
    # Start the process, connect the pipes
    sess =
      command: command
      args: args
      opts: opts
      sessionId: @id
      txt: @msg.txt
      botId: @bot._id
      scriptId: @bot.scriptId
      type: @bot.type

    trace "New session starting", sess
    newSessionRequest = JSON.stringify sess
    client.lpush NEW_SESSIONS_FEED, newSessionRequest
    client.publish NEW_SESSIONS_FEED, newSessionRequest

    if process.env.WATSON_USERNAME and process.env.WATSON_PASSWORD
      # Create the language filter using Watson
      @language = new LanguageFilter('en', lang)

      # Bot dialogs have interleaved messages: straight text is to
      # be sent to the network, any valid JSON should be saved as
      # collected data from the session
      jsonFilter = @createJsonFilter()

      # the ingress process stream carries messages from
      # the network to the bot dialog
      @ingressProcessStream = @language.ingressStream
      @ingressProcessStream.on 'readable', =>
        client.lpush @ingressList(), @ingressProcessStream.read()
        client.publish INGRESS_MSGS_FEED, @id

      # the egress process stream carries messages from the
      # bot to the network.
      @egressProcessStream = Pipe(jsonFilter, @language.egressStream)
      @egressProcessStream.on "readable", =>
        @egressMsg @egressProcessStream.read()
      @egressProcessStream.on "error", (err) ->
        Logger.info "Error thrown from session"
        Logger.info err

      # When the language changes, restart the bot dialog
      @language.on "langChanged", (oldLang, newLang) =>
        Logger.info "Language changed, restarting : #{oldLang} to #{newLang}"
        @egressProcessStream.write("Language changed, restarting conversation.")
        @lang = newLang
        nextProcess =
          command: @command
          args: @arguments
          opts: @opts
          lang: @lang
        @processStack.push nextProcess

    # Now save it in the database
  updateDb: =>
    console.log "Updating db"
    Session.sessionsDb.update {sessionId: @id}, @information(), upsert: true

  information: =>
    transcript:     @transcript
    src:            @src
    dst:            @dst
    sessionKey:     @sessionKey
    sessionId:      @id
    collectedData:  @collectedData
    updatedAt:      new Date()
    createdAt:      @createdAt
    lang:           @lang
    botId:          @bot._id
    _id:            @id

  end: =>
    nextProcess = @processStack.shift()
      # If process stack has element, run that.
    if nextProcess?
      Logger.info 'Process ended. Starting a new one.'
      {command, args, opts, lang} = nextProcess
      @kickOffProcess(command, args, opts, lang)
    else
      Logger.info "Ending and recording session #{@id}"
      events.emit 'session:ended', @information()
      delete Session.active[@sessionKey]

  cmdSettings: =>
    env_settings = _.clone(process.env)
    env_settings.SESSION_ID = @id
    env_settings.SRC = @src
    env_settings.DST = @dst
    env_settings.BOT_OBJECT_ID = @bot._id
    for setting in @bot.settings
      env_settings[setting.name] = setting.value
    return env_settings

  isOwner: () =>
    trace "Checking to see if #{@src} is in", @bot
    for address in @bot.addresses
      return true if @src in @bot.ownerHandles
    Logger.info "Running session #{@id} as a visitor"
    return false


  egressMsg: (text) =>
    if text
      lines = text.toString().split("\n")
    else
      lines = []
    for line in lines
      line = line.trim()
      if line.length > 0
        @cb line
        @transcript.push { direction: 'egress', text: line}
        @updateDb()

  ingressMsg: (text) =>
    # Handle slash commands, if any
    if cleanText(text) == '/human'
      @automated = false
      events.emit 'livechat:newsession', @information()

    # If we are in automated mode, send it to the bot
    if @automated
      if @ingressProcessStream
        @ingressProcessStream.write("#{text}\n")
      else
        client.lpush @ingressList(), text
        client.publish INGRESS_MSGS_FEED, @id
    else
      events.emit 'livechat:ingress', @information(), text
    @transcript.push { direction: 'ingress', text: text}
    @updateDb()

  createJsonFilter: () =>
    # Filter out JSON as it goes through the system
    jsonFilter = new Stream.Transform()
    jsonFilter._transform = (chunk, encoding, done) ->
      lines = chunk.toString().split("\n")
      for line in lines
        do (line) ->
          if isJson(line)
            jsonFilter.emit 'json', line
          else
            jsonFilter.push(line)
      done()

      # If the message is JSON, treat it as if it were collected data
    jsonFilter.on 'json', (line) =>
      @collectedData = JSON.parse line
      @updateDb()
    return jsonFilter

  writeEgressMessage: (txt) =>
    trace "Writing egress message #{txt}"
    lines = txt.split("\n")
    if @egressProcessStream
      @egressProcessStream.write(line) for line in lines
    else
      for line in lines
        if isJson(line)
          @collectedData = JSON.parse line
          @updateDb()
        else
          @egressMsg line

  redisPopErrored: (err) ->
    Logger.info('Popping message returns ' + err)

  ingressList: -> @id + '.ingress'
  egressList: ->  @id + '.egress'
# End Session class

events.on 'ingress', (msg) ->
  #flipping for egress
  trace "Inbound message ", msg
  src = msg.dst
  dst = msg.src
  egressEvent = msg.egressEvent
  Session.findOrCreate msg, (txt) ->
    egressMsg = {src: src, dst: dst, txt: txt}
    trace "Sending out message to #{dst}", egressMsg
    events.emit egressEvent, egressMsg


sessionClient.on 'message', (chan, sessionId) ->
  session = Session.findById(sessionId)
  session?.end()

egressClient.on "message", (chan, sessionId) ->
  #get the right session from sesion id
  session = Session.findById(sessionId)
  if not session
    trace "I can't find #{sessionId}", session
    return
  else
    trace "Found session #{sessionId}"
    trace session

  client.lpopAsync(session.egressList())
  .then (txt) ->
    session.writeEgressMessage(txt)
    trace "Message egress from session", txt
  .catch (err) -> errorHandler("Error thrown in redisPopErrored", err)

egressClient.subscribe(EGRESS_MSGS_FEED)
sessionClient.subscribe(SESSION_ENDED_FEED)

# Connect to the DB
Session.connectDb(CONNECTION_STRING)
