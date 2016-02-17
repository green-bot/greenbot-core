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
Os             = require("os")
Pipe           = require("multipipe")
Promise        = require('node-promise')
Redis          = require('redis')
ShortUUID      = require('shortid')
Stream         = require('stream')
Url            = require("url")
Us             = require("underscore.string")
Util           = require('util')

# Global events object
Pubsub = require('./pubsub')
events = Pubsub.pubsub

# Setup the connection to the database
connectionString = process.env.MONGO_URL or 'localhost/greenbot'
Db       = require('monk')(connectionString)
Bots     = Db.get('Bots')
dbSessions = Db.get('Sessions')
Scripts  = Db.get('Scripts')
ObjectID = require('mongodb').ObjectID


# Setup the connect to Redis
Bluebird.promisifyAll(Redis.RedisClient.prototype)
Bluebird.promisifyAll(Redis.Multi.prototype)
client        = Redis.createClient()
egressClient  = Redis.createClient()
sessionClient = Redis.createClient()

INGRESS_MSGS_FEED  = 'INGRESS_MSGS'
EGRESS_MSGS_FEED   = 'EGRESS_MSGS'
NEW_SESSIONS_FEED  = 'NEW_SESSIONS'
SESSION_ENDED_FEED = 'COMPLETED_SESSIONS'

# Set the default directory for scripts
DEF_SCRIPT_DIR = process.env.DEF_SCRIPT_DIR || './scripts/'

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


class Session
  @active = {}

  @findById = (id) ->
    for key, session of Session.active
      return session if session.id is id
    Logger.info "Session NOT FOUND !!!!"

  @findByKey = (key) ->
    Session.active[key]

  @findOrCreate = (msg, cb) ->
    Logger.info("Finding or creating session: #{JSON.stringify msg}")
    # All messages that come from the network end up here.
    sessionKey = genSessionKey(msg)
    session = Session.findByKey(sessionKey)
    if session
      # We already have a session, so send it off.
      session.ingressMsg(msg.txt)
    else
      # No session active. Kick one off.
      name = msg.dst.toLowerCase()
      keyword = cleanText(msg.txt)
      Logger.info "Looking for #{name}:#{keyword}"
      q = Bots.findOne
        $and: [
          'addresses.networkHandleName': name,
          "keywords": $in: [keyword]
        ]

      q.onReject (err) ->
        Logger.info "Can't find #{name}:#{keyword}" + err

      q.then (bot) ->
        if bot
          Logger.info "Found bot #{name}:#{keyword}"
          return bot

        # Apparently, no bots with that keyword. Check for default
        return Bots.findOne
          $and: [
            'addresses.networkHandleName': name,
            "keywords": $in: ['default']
          ]
      .then (bot) ->
        if not bot
          Logger.info "No default keyword set for that network handle."
          return
        Logger.info bot
        new Session(msg, bot, cb)

  constructor: (@msg, @bot, @cb) ->
    # The variables that make up a Session
    @transcript = []
    @src = @msg.src
    @dst = @msg.dst.toLowerCase()
    @sessionKey = genSessionKey(@msg)
    @id = ShortUUID.generate()
    Session.active[@sessionKey] = @
    @automated = true
    @processStack = []

    Logger.info "Creating new session #{@id}"

    # Assemble the @command, @arguments, @opts
    q = dbSessions.findOne({src: @src}, {sort: {updatedAt: -1}})
    q.error = (err) ->
      Logger.info 'Mongo error in fetch language : ' + err
    q.then (session) =>
      if session?.lang?
        @lang = session.lang
      else
        @lang = process.env.DEFAULT_LANG or 'en'
      Logger.info 'Language selection ' + @lang
      return @lang
    .then () =>
      @createSessionEnv()
    .then () =>
      @kickOffProcess(@command, @arguments, @opts, @lang)

  kickOffProcess : (command, args, opts, lang) =>
    # Start the process, connect the pipes
    Logger.info 'Kicking off process through redis : '
    sess =
      command: command
      args: args
      opts: opts
      sessionId: @id
      txt: @msg.txt
      botId: @bot._id
      scriptId: @bot.scriptId
      type: @bot.type
    Logger.info sess

    newSessionRequest = JSON.stringify sess
    client.lpush NEW_SESSIONS_FEED, newSessionRequest
    client.publish NEW_SESSIONS_FEED, newSessionRequest
    @language = new LanguageFilter('en', lang)
    jsonFilter = @createJsonFilter()
    # Start the subscriber for the bash_process pub/sub
    @ingressProcessStream = @language.ingressStream
    @ingressProcessStream.on 'readable', =>
      client.lpush @ingressList(), @ingressProcessStream.read()
      client.publish INGRESS_MSGS_FEED, @id

    @egressProcessStream = Pipe(jsonFilter, @language.egressStream)
    Logger.info "@egressProcessStream initialized:"
    Logger.info @egressProcessStream

    @egressProcessStream.on "readable", =>
      @egressMsg @egressProcessStream.read()

    @egressProcessStream.on "error", (err) ->
      Logger.info "Error thrown from session"
      Logger.info err
    @language.on "langChanged", (oldLang, newLang) =>
      Logger.info "Language changed, restarting : #{oldLang} to #{newLang}"
      @egressProcessStream.write("Language changed, restarting conversation.")
      Logger.info "Restarting session."
      @lang = newLang
      nextProcess =
        command: @command
        args: @arguments
        opts: @opts
        lang: @lang
      @processStack.push nextProcess

  createSessionEnv: =>
    Logger.info 'Organizing the session environment'
    q = Scripts.findById @bot.scriptId
    q.onReject (err) -> Logger.info "Can't find script???"
    q.then (@script) =>
      if @isOwner() and not @bot.testMode
        Logger.info "Running as the owner"
        @arguments  = @script.owner_cmd.split(" ")
      else
        Logger.info "Running as a visitor"
        @arguments  = @script.default_cmd.split(" ")

      @command = @arguments[0]
      @arguments.shift()
      @env = @cmdSettings()
      @env.INITIAL_MSG = @msg.txt
      @opts =
        cwd: DEF_SCRIPT_DIR
        env: @env
      return @opts
    .then (opts) =>
      Logger.info 'Updating test mode on the bot'
      Bots.updateById @bot._id, testMode:false
    return q

    # Now save it in the database
  updateDb: =>
    Logger.info @bot
    dbSessions.update sessionId: @id, @information(), upsert: true


  information: =>
    transcript:     @transcript
    src:            @src
    dst:            @dst
    sessionKey:     @sessionKey
    sessionId:      @id
    collectedData:  @collectedData
    updatedAt:      Date.now()
    lang:           @lang

  end: =>
    nextProcess = @processStack.shift()
      # If process stack has element, run that.
    if nextProcess?
      Logger.info 'Process ended. Starting a new one.'
      {command, args, opts, lang} = nextProcess
      @kickOffProcess(command, args, opts, lang)
    else
      Logger.info "Ending and recording session #{@id}"
      events.emit 'session:ended', @id
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
    for address in @bot.addresses
      return true if @src in address.ownerHandles
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
        Logger.info "#{@id}: #{@bot.name}: #{line}"
        @transcript.push { direction: 'egress', text: line}
        @updateDb()

  ingressMsg: (text) =>
    if cleanText(text) == '/human'
      @automated = false
      events.emit 'livechat:newsession', @information()
    if @automated
      @ingressProcessStream.write("#{text}\n")
    else
      events.emit 'livechat:ingress', @information(), text
    @transcript.push { direction: 'ingress', text: text}
    Logger.info "#{@id}: #{@src}: #{text}"
    @updateDb()

  createJsonFilter: () =>
    # Filter out JSON as it goes through the system
    jsonFilter = new Stream.Transform()
    jsonFilter._transform = (chunk, encoding, done) =>
      Logger.info "Filtering JSON in session #{@id}"
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
      Logger.info "Remembering #{line} in #{@id}"
      @collectedData = JSON.parse line
      @updateDb()
    return jsonFilter

  writeEgressMessage: (txt) =>
    lines = txt.split("\n")
    @egressProcessStream.write(line) for line in lines

  redisPopErrored: (err) =>
    Logger.info('Popping message returns ' + err)

  ingressList: -> @id + '.ingress'
  egressList: ->  @id + '.egress'

events.on 'ingress', (msg) ->
  Logger.info 'Inbound ' + msg.txt
  #flipping for egress
  src = msg.dst
  dst = msg.src
  Session.findOrCreate msg, (txt) ->
    Logger.info "FOC callback: #{JSON.stringify msg}"
    egressMsg = {src: src, dst: dst, txt: txt}
    events.emit msg.egressEvent, egressMsg


sessionClient.on 'message', (chan, sessionId) ->
  Session.findById(sessionId).end()

egressClient.on "message", (chan, sessionId) ->
  #get the right session from sesion id
  session = Session.findById(sessionId)
  Logger.info session
  Logger.info session.egressProcessStream
  client.lpopAsync(session.egressList()).then(session.writeEgressMessage, session.redisPopErrored)

egressClient.subscribe(EGRESS_MSGS_FEED)
sessionClient.subscribe(SESSION_ENDED_FEED)
