/*global Parse */

var _ = require('underscore')

exports.list = function (req, res) {
  var Sessions = Parse.Object.extend('Sessions')
  var query = new Parse.Query(Sessions)
  var Rooms = Parse.Object.extend('Rooms')
  var room = new Rooms()
  room.id = req.cookies.roomId
  query.equalTo('room', room)
  query.find().then(function (usersData) {
      var conversations = []
      _.each(usersData, function assemble (element, index, list) {
        var record = {}
        var src = element.get('src')
        if (isNaN(src)) {
          record.src = src
        } else {
          record.src = src.substr(1, 3) + '-' + src.substr(4, 3) + '-' + src.substr(7, 4)
        }
        record.dst = req.cookies.roomName
        record.session_id = element.get('sessionId')
        var myDate = element.createdAt
        var options = {
          weekday: 'short',
          year: '2-digit',
          month: '2-digit',
          day: '2-digit',
          timeZone: 'America/New_York'
        }
        record.display_timestamp = myDate.toDateString('en-US', options)
        record.objectId = element.get('objectId')
        conversations.push(record)
      })

      res.renderPjax('conversations', {
        conversations: conversations
      })
    }, function (error) {
      console.log('Failed to get conversations.')
      console.log(error)
        // Not good.
    })
}

exports.read = function (req, res) {
  var session_id = req.params.id
  var Sessions = Parse.Object.extend('Sessions')
  var query = new Parse.Query(Sessions)
  query.equalTo('sessionId', session_id)
  query.first()
    .then(function (session) {
      var display_data = []
      var data_set = JSON.parse(session.get('collected_data'))
      var data_labels = _.keys(data_set)
      _.each(data_labels, function convertForDisplay (element, index, list) {
        var entry = {
          key: element,
          v: data_set[element]
        }
        display_data.push(entry)
      })
      var myDate = new Date(session.createdAt)
      var options = {
        weekday: 'long',
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }
      var display_timestamp = myDate.toLocaleTimeString('en-us', options)
      var display_transcript = []
      var lines = JSON.parse(session.get('transcript'))
      _.each(lines, function (element, index, list) {
        display_transcript.push({
					source: element.direction === 'ingress' ? data_set['SRC'] : data_set['DST'],
					text: element.text
				})
      })
      console.log(session)

      res.renderPjax('conversation', {
        session_id: session_id,
        transcript: display_transcript,
        collected_data: display_data,
        src: data_set.SRC,
        dst: data_set.DST,
        timestamp: display_timestamp
      })
    }, function (error) {
      console.log('Threw error in read')
      console.log(error)
    })
}
