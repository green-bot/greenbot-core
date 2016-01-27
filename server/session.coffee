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
Rooms = Db.get('Rooms')
Sessions = Db.get('Sessions')

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

sessionUpdate = Async.queue (session, callback) ->
  information = session.information()
  sessionId = session.sessionId
  cb = (err, session) ->
    info "Threw error on database update #{err}" if err
    callback()

  Sessions.findOne {sessionId: sessionId}, (err, session) ->
    if session?
      Sessions.findAndModify {
        query:
          sessionId: sessionId
        update:
          information
        options:
          new: true
        }, cb
    else
      info 'Creating a new session'
      information.createdAt = Date.now()
      Sessions.insert information, cb

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
      name = process.env.DEV_ROOM_NAME or msg.dst.toLowerCase()
      keyword = cleanText(msg.txt)
      info "Looking for #{name}:#{keyword}"
      Rooms.findOne {name: name, keyword: keyword}, (err, room) ->
        info "Can't find #{name}:#{keyword}" if err
        if room
          info "Found room #{name}:#{room.keyword}:#{room.default_cmd}"
          new Session(msg, room, cb)
        return if room or err

        # No room and keyword combination matched
        # Return the default if there's one.
        info 'No room/keyword found. Check for default'
        Rooms.findOne {name: name, default: true}, (err, room) ->
          if room
            info "Found room #{name}, starting session"
            new Session(msg, room, cb)
          else
            info 'No default room, no matching keyword. Fail.'

  @complete: (sessionId) ->
    # All messages that come from the network end up here.
    info "Notification of script complete for session #{sessionId}"
    for s of @active
      if @active[s].sessionId is sessionId
        @active[s].endSession()

  constructor: (@msg, @room, @cb) ->
    # The variables that make up a Session
    @transcript = []
    @src = @msg.src
    @dst = @msg.dst.toLowerCase()
    @sessionKey = genSessionKey(@msg)
    @sessionId = ShortUUID.generate()
    Session.active[@sessionKey] = @
    @automated = true
    @processStack = []

    # Assemble the @command, @arguments, @opts
    @createSessionEnv()
    langQ = Sessions.findOne({src: @src}, {sort: {updatedAt: -1}})
    langQ.error = (err) ->
      info 'Mongo error in fetch language : ' + err
    langQ.then (session) =>
      if session?.lang?
        @lang = session.lang
      else
        @lang = process.env.DEFAULT_LANG or 'en'
      info 'Kicking off process with lang ' + @lang
      @kickOffProcess(@command, @arguments, @opts, @lang)

  kickOffProcess : (command, args, opts, lang) ->
    # Start the process, connect the pipes
    info 'Kicking off process ' + command
    sess =
      command: command
      args: args
      opts: opts
      sessionId: @sessionId
      txt: @msg.txt
      roomId: @room.objectId
      scriptId: @room.script.objectId
      type: @room.type

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
      # @process.kill()

    info "New process started : #{@process.pid}"

  createSessionEnv: () ->
    if @isOwner()
      info "Running as the owner"
      if @room.test_mode is true
        @room.test_mode = false
        Db.update 'Rooms', @room.objectId,
          { test_mode: false }, (err, response) ->
          if err
            info "Error trying to turn off test mode : #{err}"
        @arguments  = @room.default_cmd.split(" ")
      else
        @arguments  = @room.owner_cmd.split(" ")
    else
      info "Running as a visitor"
      @arguments  = @room.default_cmd.split(" ")
    @command = @arguments[0]
    @arguments.shift()
    @env = @cmdSettings()
    @env.INITIAL_MSG = @msg.txt
    @opts =
      cwd: DEF_SCRIPT_DIR
      env: @env


    # Now save it in the database
  updateDb: () ->
    info "Updating session #{@sessionId}"
    sessionUpdate.push @

  information: () ->
    transcript:     @transcript
    src:            @src
    dst:            @dst
    sessionKey:     @sessionKey
    sessionId:      @sessionId
    roomId:         @room.objectId
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
    env_settings.ROOM_OBJECT_ID = @room.objectId
    for attrname of @room.settings
      env_settings[attrname] = @room.settings[attrname]
    return env_settings

  isOwner: () ->
    if @room.owners? and @src in @room.owners
      info "Running session #{@sessionId} as the owner"
      true
    else
      info "Running session #{@sessionId} as a visitor"
      false


  egressMsg: (text) =>
    if text
      lines = text.toString().split("\n")
    else
      lines = []
    for line in lines
      line = line.trim()
      if line.length > 0
        @cb @src, line
        info "#{@sessionId}: #{@room.name}: #{line}"
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
