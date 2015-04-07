var bc = require('../bootcards-functions.js');
var _ = require('underscore');

exports.list = function(req, res){
	var conversations = [];

	_.each(collected_data, function assemble(element, index, list) {
		var record = {};
		record.src = element.data.SRC;
		record.dst = element.data.DST;
		record.session_id = element.data.SESSION_ID;
		var myDate = new Date(element.createdAt);
		var options = {
			weekday: "long", year: "numeric", month: "short",
			day: "numeric", hour: "2-digit", minute: "2-digit"
		};
		record.display_timestamp = myDate.toLocaleTimeString("en-us", options);
		record.objectId = element.objectId;
		conversations.push(record);
		});


	res.renderPjax('conversations', {
		conversations: conversations,
		menu: bc.getActiveMenu(menu, 'conversations')
		});

};

exports.read = function(req, res){
	var session_id = req.params.id;
	var transcript = _.findWhere(transcripts, {transcript_key: session_id});
	var data_record = _.find(collected_data, function(record){ return record.data.SESSION_ID == session_id});
	var display_data = []
	var data_labels = _.keys(data_record.data);
	_.each(data_labels, function convertForDisplay(element, index, list) {
		var entry = {
			key: element,
			v: data_record.data[element]
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
	var lines = transcript.transcript.split("\n");
	_.each(lines, function convert(element, index, list) {
		 display_transcript.push(element.replace(/[^|]*/,""));
	});

	res.renderPjax('conversation', {
		session_id: session_id,
		transcript: display_transcript,
		collected_data: display_data,
		src: data_record.data.SRC,
		dst: data_record.data.DST,
		timestamp: display_timestamp,
		menu: bc.getActiveMenu(menu, 'conversations')
		});
};
