// Copyright  (c) 2016, Thomas Howe
//

// Load config for RethinkDB and express
var cp = require('child_process')
var gB = require('./greenbot-process')
var u = require('util')

// Couple convenience functions
var info = function (text) {
  console.log(text)
}
var objInfo = function (obj) {
  console.log(u.inspect(obj))
}
var sessions = {}

var createBash = function (sess) {
  var sessionId = sess.sessionId

  info('starting process: ' + sess.command)
  sess.process = cp.spawn(sess.command, sess.args, sess.opts)
  // Check for thrown errors
  sess.process.on('exit', function (code, signal) {
    info('Session ended ' + code)
    gbProcess.complete(sessionId)
  })
  sess.process.on('error', function (err) {
    info('Session threw error.')
    objInfo(err)
  })
  sess.process.stderr.on('data', function (chunk) {
    info('stderr: ' + chunk)
  })

  // Look for egress messages and stick them into the database
  sess.process.stdout.on('data', function (chunk) {
    gbProcess.egress(sessionId, chunk.toString())
  })
  sessions[sessionId] = sess
  info('started process: ' + sess.command)
}

var ingressMsg = function (sessionId, txt) {
  var session = sessions[sessionId]
  if (!session) return
  session.process.stdin.write(txt)
}

var gbProcess = gB(ingressMsg, createBash, 'bash')
