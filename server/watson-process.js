// Copyright  (c) 2016, Thomas Howe
//

// Load config for RethinkDB and express
var bluemix = require('../config/bluemix')
var extend = require('util')._extend
var watson = require('watson-developer-cloud')
var gB = require('./greenbot-process')

var info = function (text) {
  console.log(text)
}

// if bluemix credentials exists, then override local
var credentials = extend({
  'password': process.env.WATSON_DIALOG_PASS,
  'url': 'https://gateway.watsonplatform.net/dialog/api',
  'username': process.env.WATSON_DIALOG_USERNAME,
  version: 'v1'
}, bluemix.getServiceCreds('dialog'))
var dialog_id = process.env.WATSON_DIALOG_ID || '<dialog-id>'
var sessions = {}

var createDialog = function (sess) {
  var sessionId = sess.sessionId
  sessions[sessionId] = sess
  info('started watson process : ' + sessionId)
  ingressMsg(sessionId, sess.txt)
}

var ingressMsg = function (sessionId, txt) {
  var session = sessions[sessionId]
  if (!session) return

  var params = {
    dialog_id: dialog_id,
    conversation_id: session.conversation_id,
    input: txt
  }
  dialog.conversation(params, function (err, results) {
    if (err) {
      console.log('Dialog error' + JSON.stringify(err))
      return
    }
    // Save the conversation ID returned in first response
    // from dialog.
    session.conversation_id = results['conversation_id']
    var arrayLength = results.response.length
    for (var i = 0; i < arrayLength; i++) {
      gbProcess.egress(sessionId, results.response[i] + '\n')
    }
  })
}

if (credentials.password &&
    credentials.username &&
    dialog_id) {
  var dialog = watson.dialog(credentials)
  var gbProcess = gB(ingressMsg, createDialog, 'watson')
  info('Watson configured.')
}
