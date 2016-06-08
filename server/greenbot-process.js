// Copyright  (c) 2016, Thomas Howe
//
// Load config for RethinkDB and express
var redis = require('redis')
var u = require('util')
var bluebird = require('bluebird')

// Make a redis client and promisfy all
bluebird.promisifyAll(redis.RedisClient.prototype)
bluebird.promisifyAll(redis.Multi.prototype)
var redisPort = process.env.REDIS_PORT || 6379
var redisHost = process.env.REDIS_HOST|| 'localhost'
var msgClient = redis.createClient(redisPort, redisHost)
var sessionClient = redis.createClient(redisPort, redisHost)
var terminateClient = redis.createClient(redisPort, redisHost)
var client = redis.createClient(redisPort, redisHost)
var abstractIngress = null
var abstractCreate = null
var abstractType = null

// The redis lists we need
const NEW_SESSIONS_FEED = 'NEW_SESSIONS'
const INGRESS_MSGS_FEED = 'INGRESS_MSGS'
const EGRESS_MSGS_FEED = 'EGRESS_MSGS'
const SESSION_ENDED_FEED = 'COMPLETED_SESSIONS'
const TERMINATE_SESSION_FEED = 'TERMINATE_SESSION'

// Couple convenience functions
var trace = function (text) {
  if (process.env.TRACE_MESSAGES) {
    console.log(text)
  }
}

var handleError = function (err) {
  trace('Redis client error: ' + err)
}
var ingressList = function (sessionId) {
  return sessionId + '.ingress'
}
var egressList = function (sessionId) {
  return sessionId + '.egress'
}

// Handle errors from the redis client
client.on('error', handleError)
sessionClient.on('error', handleError)
msgClient.on('error', handleError)

// Start the subscriber for the message pub/sub
sessionClient.on('message', function (chan, sess) {
  if (sess.type && (sess.type !== abstractType)) {
    // We've defined a type for this script... and this aint it.
    trace('Process passing on ' + sess.type)
    return
  }

  var popped = function (sessString) {
    if (sessString) {
      var sess = JSON.parse(sessString)
      trace('Starting session :  ' + u.inspect(sess))
      abstractCreate(sess)
    } else {
      trace('I knocked on the SESSION_DOOR; No joy.')
    }
  }
  var errored = function (err) {
    trace('Popping message returns ' + err)
  }
  trace('Getting the process now from ' + NEW_SESSIONS_FEED)
  client.lpopAsync(NEW_SESSIONS_FEED).then(popped, errored)
})
sessionClient.subscribe(NEW_SESSIONS_FEED)
trace('Subscribed to new sessions on ' + NEW_SESSIONS_FEED)

// Start the subscriber for the handling inbound messages
msgClient.on('message', function (chan, sessionId) {
  readMsg(sessionId)
})
msgClient.subscribe(INGRESS_MSGS_FEED)
trace('Subscribed to inbound notifications on ' + INGRESS_MSGS_FEED)

// Start the subscriber for the handling inbound messages
terminateClient.on('message', function (chan, sessionId) {
  if(abstractTerminate){ //abstractTerminate is optional at the moment so make sure it was passed in before calling it
    abstractTerminate(sessionId)
  }
})
terminateClient.subscribe(TERMINATE_SESSION_FEED)
trace('Subscribed to terminate session notifications on ' + TERMINATE_SESSION_FEED)


var readMsg = function (sessionId) {
  var listName = ingressList(sessionId)
  var popped = function (txt) {
    if (txt) {
      trace(sessionId + ' (INGRESS): ' + txt)
      abstractIngress(sessionId, txt) // Sticks it into the process
      readMsg(sessionId)
    }
  }
  var errored = function (err) {
    trace('Popping message returns ' + err)
  }
  client.lpopAsync(listName).then(popped, errored)
}

var endSession = function (sessionId) {
  client.publishAsync(SESSION_ENDED_FEED, sessionId).done()
}

var egress = function (sessionId, txt) {
  trace('Retreived a ' + txt + ' from ' + sessionId)
  client.lpush(egressList(sessionId), txt)
  client.publish(EGRESS_MSGS_FEED, sessionId)
}

module.exports = function override (ingressFunc, createFunc, type, terminateFunc = null) {
  abstractIngress = ingressFunc
  abstractCreate = createFunc
  abstractType = type
  abstractTerminate = terminateFunc

  return {
    complete: endSession,
    egress: egress
  }
}
