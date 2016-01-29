// Copyright  (c) 2016, Thomas Howe
//
// Load config for RethinkDB and express
var redis = require('redis')
var u = require('util')
var bluebird = require('bluebird')

// Make a redis client and promisfy all
bluebird.promisifyAll(redis.RedisClient.prototype)
bluebird.promisifyAll(redis.Multi.prototype)
var msgClient = redis.createClient()
var sessionClient = redis.createClient()
var client = redis.createClient()
var abstractIngress = null
var abstractCreate = null
var abstractType = null

// The table we need
const NEW_SESSIONS_FEED = 'NEW_SESSIONS'
const INGRESS_MSGS_FEED = 'INGRESS_MSGS'
const EGRESS_MSGS_FEED = 'EGRESS_MSGS'
const SESSION_ENDED_FEED = 'COMPLETED_SESSIONS'

// Couple convenience functions
var info = function (text) {
  console.log(text)
}
var handleError = function (err) {
  info('Redis client error: ' + err)
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

// Start the subscriber for the bash_process pub/sub
sessionClient.on('message', function (chan, sess) {
  // As a quick and dirty approach to reliability,
  // we will wait a random small amount of time before trying
  // to read from the NEW_SESSIONS_FEED list. If we get the
  // element, start it. If we didn't, well, something else got
  // there first.   The random amount of time is to prevent
  // deadlocks. But, we will probably need a better
  // scale solution anyways. Thus, quick and dirty.

  if (sess.type && (sess.type !== abstractType)) {
    // We've defined a type for this script... and this aint it.
    info('Process passing on ' + sess.type)
    return
  }

  var popped = function (sessString) {
    if (sessString) {
      var sess = JSON.parse(sessString)
      info('Starting session :  ' + u.inspect(sess))
      abstractCreate(sess)
    } else {
      info('I knocked on the SESSION_DOOR; No joy.')
    }
  }
  var errored = function (err) {
    info('Popping message returns ' + err)
  }
  info('Getting the process now from ' + NEW_SESSIONS_FEED)
  client.lpopAsync(NEW_SESSIONS_FEED).then(popped, errored)
})
sessionClient.subscribe(NEW_SESSIONS_FEED)
info('Subscribed to new sessions on ' + NEW_SESSIONS_FEED)

// Start the subscriber for the handling inbound messages
msgClient.on('message', function (chan, sessionId) {
  readMsg(sessionId)
})
msgClient.subscribe(INGRESS_MSGS_FEED)
info('Subscribed to inbound notifications on ' + INGRESS_MSGS_FEED)

var readMsg = function (sessionId) {
  var listName = ingressList(sessionId)
  var popped = function (txt) {
    if (txt) {
      info(sessionId + ' (INGRESS): ' + txt)
      abstractIngress(sessionId, txt) // Sticks it into the process
      readMsg(sessionId)
    }
  }
  var errored = function (err) {
    info('Popping message returns ' + err)
  }
  client.lpopAsync(listName).then(popped, errored)
}

var endSession = function (sessionId) {
  client.publishAsync(SESSION_ENDED_FEED, sessionId).done()
}

var egress = function (sessionId, txt) {
  info('Retreived a ' + txt + ' from ' + sessionId)
  client.lpush(egressList(sessionId), txt)
  client.publish(EGRESS_MSGS_FEED, sessionId)
}

module.exports = function override (ingressFunc, createFunc, type) {
  abstractIngress = ingressFunc
  abstractCreate = createFunc
  abstractType = type

  return {
    complete: endSession,
    egress: egress
  }
}