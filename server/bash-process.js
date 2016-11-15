// Copyright  (c) 2016, Thomas Howe
//

// Load config for RethinkDB and express
var ChildProcess = require('child_process')
var gB = require('./greenbot-process')
var u = require('util')

// Couple convenience functions
var trace = function (text) {
  if (process.env.TRACE_MESSAGES) {
    console.log(text)
  }
}
var objtrace = function (obj) {
  if (process.env.TRACE_MESSAGES){
    console.log(u.inspect(obj))
  }
}
var sessions = {}

var createBash = function (sess) {
  var sessionId = sess.sessionId

  trace('starting process: ' + sess.command)
  sess.process = ChildProcess.spawn(sess.command, sess.args, sess.opts)
  // Check for thrown errors
  sess.process.on('exit', function (code, signal) {
    trace('Session ended ' + code)
    gbProcess.complete(sessionId)
  })
  sess.process.on('error', function (err) {
    trace('Session threw error.')
    objtrace(err)
  })
  sess.process.stderr.on('data', function (chunk) {
    trace('stderr: ' + chunk)
  })

  // Look for egress messages and stick them into the database
  sess.process.stdout.on('data', function (chunk) {
    gbProcess.egress(sessionId, chunk.toString())
  })
  sessions[sessionId] = sess
  trace('started process: ' + sess.command)
}

var ingressMsg = function (sessionId, txt) {
  var session = sessions[sessionId]
  if (!session) return
  session.process.stdin.write(txt)
}

var terminateSessionFunction = function (sessionId) {
  var session = sessions[sessionId]
  if (!session) return
    //gbProcess.complete(sessionId)
  session.process.kill('SIGHUP')
}

var gbProcess = gB(ingressMsg, createBash, 'bash', terminateSessionFunction)
