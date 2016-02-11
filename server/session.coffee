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

_ = require('underscore')
Async = require('async')
Bluebird = require('bluebird')
ChildProcess = require("child_process")
LanguageFilter = require('watson-translate-stream')
Mailer = require("nodemailer")
Os = require("os")
Pipe = require("multipipe")
Promise = require('node-promise')
Redis = require('redis')
ShortUUID = require 'shortid'
Stream = require('stream')
Url = require("url")
Us = require("underscore.string")
Util = require('util')

# Global events object
Pubsub = require('./pubsub')
events = Pubsub.pubsub

# Setup the connection to the database
connectionString = process.env.MONGO_URL or 'localhost/greenbot'
Db = require('monk')(connectionString)
Bots = Db.get('Bots')
Sessions = Db.get('Sessions')
Scripts = Db.get('Scripts')
ObjectID = require('mongodb').ObjectID


# Setup the connect to Redis
Bluebird.promisifyAll(Redis.RedisClient.prototype)
Bluebird.promisifyAll(Redis.Multi.prototype)
client = Redis.createClient()
egressClient = Redis.createClient()
sessionClient = Redis.createClient()

INGRESS_MSGS_FEED = 'INGRESS_MSGS'
EGRESS_MSGS_FEED = 'EGRESS_MSGS'
NEW_SESSIONS_FEED = 'NEW_SESSIONS'
SESSION_ENDED_FEED = 'COMPLETED_SESSIONS'

# Set the default directory for scripts
DEF_SCRIPT_DIR = process.env.DEF_SCRIPT_DIR || './scripts/'

info = (text) ->
  events.emit 'log',  text

genSessionKey = (msg) ->
  msg.src + "_" + msg.dst

cleanText = (text) ->
  return "" unless text
  text.trim().toLowerCase()

msg_text = (msg) ->
  msg.txt

visitor_name = (msg) ->
  msg.src.toLowerCase()

isJson = (str) ->
  # When a text message comes from a session, if it's a valid JSON
  # string, we will treat it as a command or data. This function
  # allows us to figure that out.
  try
    JSON.parse str
  catch e
    return false
  true

ingressList = (sessionKey) ->
  sessionKey + '.ingress'

egressList = (sessionKey) ->
  sessionKey + '.egress'

class Session
  @active = []

  @findOrCreate: (msg, cb) ->
    # All messages that come from the network end up here.
    session_name = genSessionKey(msg)
    session = @active[session_name]
    if session
      # We already have a session, so send it off.
      session.ingressMsg(msg.txt)
    else
      # No session active. Kick one off.
      name = msg.dst.toLowerCase()
      keyword = cleanText(msg.txt)
      info "Looking for #{name}:#{keyword}"
      q = Bots.findOne
        $and: [
          'addresses.networkHandleName': name,
          "keywords":
            $in: [keyword]
        ]

      q.onReject (err) ->
        info "Can't find #{name}:#{keyword}" + err

      q.then (bot) ->
        if bot
          info "Found bot #{name}:#{keyword}"
          return bot

        # Apparently, no bots with that keyword. Check for default
        return Bots.findOne
          $and: [
            'addresses.networkHandleName': name,
            "keywords":
              $in: ['default']
          ]
      .then (bot) ->
        if not bot
          info "No default keyword set for that network handle."
          return
        info bot
        new Session(msg, bot, cb)


  @complete: (sessionId) ->
    # All messages that come from the network end up here.
    info "Notification of script complete for session #{sessionId}"
    for s of @active
      if @active[s].sessionId is sessionId
        @active[s].endSession()

  constructor: (@msg, @bot, @cb) ->
    # The variables that make up a Session
    @transcript = []
    @src = @msg.src
    @dst = @msg.dst.toLowerCase()
    @sessionKey = genSessionKey(@msg)
    @sessionId = ShortUUID.generate()
    Session.active[@sessionKey] = @
    @automated = true
    @processStack = []

    info "Creating new session #{@sessionId}"

    # Assemble the @command, @arguments, @opts
    q = Sessions.findOne({src: @src}, {sort: {updatedAt: -1}})
    q.error = (err) ->
      info 'Mongo error in fetch language : ' + err
    q.then (session) =>
      if session?.lang?
        @lang = session.lang
      else
        @lang = process.env.DEFAULT_LANG or 'en'
      info 'Language selection ' + @lang
      return @lang
    .then () =>
      @createSessionEnv()
    .then () =>
      @kickOffProcess(@command, @arguments, @opts, @lang)

  kickOffProcess : (command, args, opts, lang) ->
    # Start the process, connect the pipes
    info 'Kicking off process through redis : '
    sess =
      command: command
      args: args
      opts: opts
      sessionId: @sessionId
      txt: @msg.txt
      botId: @bot._id
      scriptId: @bot.scriptId
      type: @bot.type
    info sess

    newSessionRequest = JSON.stringify sess
    client.lpush NEW_SESSIONS_FEED, newSessionRequest
    client.publish NEW_SESSIONS_FEED, newSessionRequest
    @language = new LanguageFilter('en', lang)
    jsonFilter = @createJsonFilter()
    @egressProcessStream = Pipe(jsonFilter,
                                @language.egressStream)

    egressClient.on 'message', (chan, sessionKey) =>
      popped = (txt) =>
        info('Popped a ' + txt)
        if txt
          lines = txt.toString().split("\n")
        else
          lines = []
        for line in lines
          @egressProcessStream.write(line) if (line)
      errored = (err) ->
        info('Popping message returns ' + err)
      redisList = egressList(sessionKey)
      client.lpopAsync(redisList).then(popped, errored)
    egressClient.subscribe(EGRESS_MSGS_FEED)

    sessionClient.on 'message', (chan, sessionKey) ->
      Session.complete(sessionKey)
    sessionClient.subscribe(SESSION_ENDED_FEED)


    # Start the subscriber for the bash_process pub/sub
    @ingressProcessStream = @language.ingressStream
    @ingressProcessStream.on 'readable', () =>
      redisList = ingressList(@sessionId)
      client.lpush redisList, @ingressProcessStream.read()
      client.publish INGRESS_MSGS_FEED, @sessionId

    @egressProcessStream.on "readable", () =>
      # Send the output of the egress stream off to the network
      info 'Data available for reading'
      @egressMsg @egressProcessStream.read()

    @egressProcessStream.on "error", (err) ->
      info "Error thrown from session"
      info err
    @language.on "langChanged", (oldLang, newLang) =>
      info "Language changed, restarting : #{oldLang} to #{newLang}"
      @egressProcessStream.write("Language changed, restarting conversation.")
      info "Restarting session."
      @lang = newLang
      nextProcess =
        command: @command
        args: @arguments
        opts: @opts
        lang: @lang
      @processStack.push nextProcess

  createSessionEnv: () ->
    info 'Organizing the session environment'
    q = Scripts.findById @bot.scriptId
    q.onReject (err) -> info "Can't find script???"
    q.then (@script) =>
      if @isOwner() and not @bot.testMode
        info "Running as the owner"
        @arguments  = @script.owner_cmd.split(" ")
      else
        info "Running as a visitor"
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
      info 'Updating test mode on the bot'
      Bots.updateById @bot._id, testMode:false
    return q

    # Now save it in the database
  updateDb: () =>
    info "Updating session #{@sessionId}"
    info @bot
    Sessions.update sessionId: @sessionId, @information(), upsert: true


  information: () =>
    transcript:     @transcript
    src:            @src
    dst:            @dst
    sessionKey:     @sessionKey
    sessionId:      @sessionId
    collectedData:  @collectedData
    updatedAt:      Date.now()
    lang:           @lang


  endSession: () ->
    nextProcess = @processStack.shift()
      # If process stack has element, run that.
    if nextProcess?
      info 'Process ended. Starting a new one.'
      {command, args, opts, lang} = nextProcess
      @kickOffProcess(command, args, opts, lang)
    else
      info "Ending and recording session #{@sessionId}"
      events.emit 'session:ended', @sessionId
      delete Session.active[@sessionKey]

  cmdSettings: () ->
    env_settings = _.clone(process.env)
    env_settings.SESSION_ID = @sessionId
    env_settings.SRC = @src
    env_settings.DST = @dst
    env_settings.BOT_OBJECT_ID = @bot._id
    for setting in @bot.settings
      env_settings[setting.name] = setting.value
    return env_settings

  isOwner: () ->
    for address in @bot.addresses
      return true if @src in address.ownerHandles
    info "Running session #{@sessionId} as a visitor"
    return false


  egressMsg: (text) =>
    if text
      lines = text.toString().split("\n")
    else
      lines = []
    for line in lines
      line = line.trim()
      if line.length > 0
        @cb @src, line
        info "#{@sessionId}: #{@bot.name}: #{line}"
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
    info "#{@sessionId}: #{@src}: #{text}"
    @updateDb()

  createJsonFilter: () ->
    # Filter out JSON as it goes through the system
    jsonFilter = new Stream.Transform()
    jsonFilter._transform = (chunk, encoding, done) ->
      info "Filtering JSON"
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
      info "Remembering #{line}"
      @collectedData = JSON.parse line
      @updateDb()
    return jsonFilter


events.on 'ingress', (msg) ->
  events.emit 'log', 'Inbound ' + msg.txt
  {dst, src, txt} = msg
  Session.findOrCreate msg, (src, txt) ->
    events.emit src, txt

events.on 'livechat:egress', (sessionKey, text) ->
  events.emit 'log',  "Received #{text} for #{sessionKey}"
