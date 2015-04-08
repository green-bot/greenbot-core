var bc = require('cloud/bootcards-functions');
var _ = require('underscore');
var requireUser = require('cloud/require-user');

exports.list = function(req, res){
	var currentUser = Parse.User.current();
	var query = new Parse.Query("Session");
	// query.equalTo("user", currentUser);
  query.find().then(function(usersData) {
		var conversations = [];
		_.each(usersData, function assemble(element, index, list) {
			var record = {};
			var src = element.get("src");
			if (isNaN(src)) {
				record.src = src;
			} else {
				record.src = src.substr(1, 3) + '-' + src.substr(4, 3) + '-' + src.substr(7,4);
			}
			record.dst = element.get("room");
			record.session_id = element.get("sessionId");
			var myDate = element.createdAt;
			var options = { weekday: 'short', year: '2-digit', month: '2-digit', day: '2-digit', timeZone:"America/New_York"};
			record.display_timestamp = myDate.toDateString('en-US', options);
			record.objectId = element.get("objectId");
			conversations.push(record);
			});

			res.renderPjax('conversations', {
				conversations: conversations
			});
		}, function(error) {
			console.log("Failed to get conversations.");
			console.log(error);
				// Not good.
		});
	};

exports.read = function(req, res) {
	var session_id = req.params.id;
	var Session = Parse.Object.extend("Session");
	var query = new Parse.Query(Session);
	var thisSession;
	var thisData;
	var thisTranscript;

	query.equalTo("sessionId", session_id);
	query.first().then(function(session) {
		thisSession = session;
		var relation = session.relation("collectedData");
		var query = relation.query();
		return query.first();
	}).then(function(collectedData) {
		thisData = collectedData;
		var relation = thisSession.relation("transcript");
		var query = relation.query();
		return query.first();
	}).then(function(transcript) {
		thisTranscript = transcript;
		var display_data = [];
		var data_set = thisData.get("data");
		var data_labels = _.keys(data_set);
		_.each(data_labels, function convertForDisplay(element, index, list) {
			var entry = {
				key: element,
				v: data_set[element]
			};
			display_data.push(entry);
		});
		var myDate = new Date(transcript.createdAt);
		var options = {
			weekday: "long", year: "numeric", month: "short",
			day: "numeric", hour: "2-digit", minute: "2-digit"
		};
		var display_timestamp = myDate.toLocaleTimeString("en-us", options);
		var display_transcript = [];
		var lines = thisTranscript.get("transcript").split("\n");
		_.each(lines, function convert(element, index, list) {
			display_transcript.push(element.replace(/[^|]*/,""));
		});
		console.log(display_transcript);

		res.renderPjax('conversation', {
			session_id: session_id,
			transcript: display_transcript,
			collected_data: display_data,
			src: data_set.SRC,
			dst: data_set.DST,
			timestamp: display_timestamp
		});
	}, function(error) {
		console.log("Threw error in read");
		console.log(error);
	});
}
