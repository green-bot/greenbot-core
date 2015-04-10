var bc = require('cloud/bootcards-functions.js');
var _ = require('underscore');

exports.list = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var room_settings = room.get("settings");
			var setting_keys = _.keys(room_settings);
			var display_settings = [];
			_.each(setting_keys, function(element, index, list) {
				var item = {
					key: element,
					v: room_settings[element]
					};
				display_settings.push(item);
				});
			res.renderPjax('config', {
				config: display_settings
				});
			},
		error: function(error) {
			console.log("Failed to get room.");
			console.log(error);
		}
	});
}

exports.edit = function(req, res){
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var room_settings = room.get("settings");
			var setting_keys = _.keys(room_settings);
			var display_settings = [];
			_.each(setting_keys, function(element, index, list) {
				var item = {
					key: element,
					v: room_settings[element]
					};
				display_settings.push(item);
				});
			res.renderPjax('config_edit', {
				config: display_settings
				});
			},
		error: function(error) {
			console.log("Failed to get room.");
			console.log(error);
		}
	});
}

exports.save = function(req, res){
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var room_settings = room.get("settings");
			// This posted form has two kinds of data. Password
			// and room settings. Process the password first
			_.each(room_settings, function(value, key, list){
				if (_.has(req.body, key)) {
					room_settings[key] = req.body[key];
				}
			});
			room.set("settings", room_settings);
			room.save().then(function(room){
				res.redirect("/portal/config");
			});
		},
		error: function(error) {
			console.log("Error thrown while saving settings.");
			console.log(error);
		}
	});
}

exports.reset_request = function(req, res) {
	console.log("Resetting the password");
	Parse.User.requestPasswordReset(req.body.email, {
  success: function() {
    // Password reset request was sent successfully
		console.log("Found it.");
		res.redirect("/portal");
  },
  error: function(error) {
		console.log("I didn't find that user.");
		console.log(error);
		// Password reset request was sent successfully
	  res.render('reset_page');
  }
	});
}
