var bc = require('cloud/bootcards-functions.js');
var _ = require('underscore');

exports.info = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			res.renderPjax('info', {
				username: currentUser.get("username"),
				email: currentUser.get("email"),
				name: room.get("name"),
				desc: room.get("desc")
				});
			},
		error: function(error) {
			console.log("Failed to get room.");
			console.log(error);
		}
	});
}

exports.list = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var room_settings = room.get("settings");
			var setting_keys = _.keys(room_settings);
			setting_keys.sort();
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
	var username = req.body.email.trim().toLowerCase();
	console.log("Resetting the password for " + username);
	Parse.User.requestPasswordReset(username, {
  success: function() {
    // Password reset request was sent successfully
		console.log("Found it.");
		res.redirect("/portal");
  },
  error: function(error) {
		console.log("I didn't find that user.");
		console.log(error);
		// Password reset request was sent successfully
	  res.render('reset_page', {
			error: error.message
		});
  }
	});
}

exports.owners = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var owners = room.get("owners");
			res.render('owners', {
				owners: owners
				});
			},
		error: function(error) {
			console.log("Failed to get owners.");
			console.log(error);
		}
	});
}

exports.owner_delete = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var owners = room.get("owners");
			console.log("Owners has");
			console.log(owners);
			console.log("Removing");
			console.log(req.query.number);


			var new_owners = _.without(owners, req.query.number);
			console.log("Now has");
			console.log(new_owners);
			room.set("owners", new_owners);
			room.save({
				success: function() {
				res.render('owners', {
					owners: new_owners
					});
				},
				error: function() {
					console.log("Could not save room.");
					res.render('owners', {
						owners: owners
						});
				}
			});
			},
		error: function(error) {
			console.log("Failed to get owners.");
			console.log(error);
		}
	});
}
exports.owner_add = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var owners = room.get("owners");
			var owner_number = req.body.new_owner.replace(/\D/g,'');
			owners.push(owner_number);
			room.set("owners", owners);
			room.save({
				success: function() {
				res.render('owners', {
					owners: owners
					});
				},
				error: function() {
					console.log("Could not save room.");
					res.render('owners', {
						owners: owners
						});
				}
			});
			},
		error: function(error) {
			console.log("Failed to get owners.");
			console.log(error);
		}
	});
}

exports.notification_emails = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var notification_emails = room.get("notification_emails");
			var mail_user = room.get("mail_user");
			var mail_pass = room.get("mail_pass");
			res.render('notification_emails', {
				notification_emails: notification_emails,
				mail_user: mail_user,
				mail_pass: mail_pass
				});
			},
		error: function(error) {
			console.log("Failed to get notification_emails.");
			console.log(error);
		}
	});
}
exports.notification_email_delete = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var notification_emails = room.get("notification_emails");
			console.log("notification_emails has");
			console.log(notification_emails);
			console.log("Removing");
			console.log(req.query.email);


			var new_notification_emails = _.without(notification_emails, req.query.email);
			console.log("Now has");
			console.log(new_notification_emails);
			room.set("notification_emails", new_notification_emails);
			room.save({
				success: function() {
					res.redirect('/portal/config/notification_emails');
				},
				error: function() {
					console.log("Could not save room.");
					res.redirect('/portal/config/notification_emails');
				}
			});
			},
		error: function(error) {
			console.log("Failed to get notification_emails.");
			console.log(error);
		}
	});
}
exports.notification_email_add = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			var notification_emails = room.get("notification_emails");
			var notification_email = req.body.email;
			notification_emails.push(notification_email);
			room.set("notification_emails", notification_emails);
			room.save({
				success: function() {
					res.redirect('/portal/config/notification_emails');
				},
				error: function() {
					console.log("Could not save room.");
					res.redirect('/portal/config/notification_emails');
				}
			});
			},
		error: function(error) {
			console.log("Failed to get notification_emails.");
			console.log(error);
		}
	});
}
exports.notification_creds_update = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	room.fetch({
		success: function(room) {
			console.log("Fetched room successfully");
			console.log("About to save user name " + req.body.mail_user);
			console.log("About to save user name " + req.body.mail_pass);
			room.set("mail_user", req.body.mail_user);
			room.set("mail_pass", req.body.mail_pass);
			room.save({
				success: function() {
					console.log("Saved room successfully");
					res.redirect('/portal/settings');
				},
				error: function() {
					console.log("Could not save room.");
					res.redirect('/portal/config/notification_emails');
				}
			});
			},
		error: function(error) {
			console.log("Failed to get notification_emails.");
			console.log(error);
			res.redirect('/portal/config');
		}
	});
}

exports.network_type = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	var default_cmd;
	var current_name;
	var icon_class;
	var desc;
	var current_network;
	room.fetch().then (function (room) {
		current_name = room.get("name");
		var Did = Parse.Object.extend("dids");
		var query = new Parse.Query(Did);
		query.equalTo("did", current_name);
		return query.find();
	}).then(function(dids) {
		did = dids[0];
		current_network = did.get("network");
		var Network = Parse.Object.extend("Networks");
		var query = new Parse.Query(Network);
		return query.find();
	}).then(function(results) {
		var network_names = _.map(results, function(network) {
			return network.get("name");
		});
		console.log(JSON.stringify(network_names));
		res.render('networks', {
			networks: network_names,
			current_network: current_network,
			current_name: current_name
		});
	});
 }

exports.number_assign = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	var default_cmd;
	var current_name;
	var icon_class;
	var desc;
	var current_network;
	room.fetch().then (function (room) {
		current_name = room.get("name");
		var Did = Parse.Object.extend("dids");
		var query = new Parse.Query(Did);
		query.equalTo("did", current_name);
		return query.find();
	}).then(function(dids) {
		did = dids[0];
		current_network = did.get("network");
		var Network = Parse.Object.extend("Networks");
		var query = new Parse.Query(Network);
		return query.find();
	}).then(function(results) {
		var network_names = _.map(results, function(network) {
			return network.get("name");
		});
		console.log(JSON.stringify(network_names));
		res.render('networks', {
			networks: network_names,
			current_network: current_network,
			current_name: current_name
		});
	});
 }


exports.type = function(req, res) {
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	var default_cmd;
	var current_name;
	var icon_class;
	var desc;
	room.fetch().then (function (room) {
		default_cmd = room.get("default_cmd");
		var Script = Parse.Object.extend("Script");
		var query = new Parse.Query(Script);
		query.ascending("name");
		return query.find();
	}).then(function(elements) {
		var display_settings = [];
		_.each(elements, function(element, index, list) {
			var item = {
				name: element.get("name"),
				cmd: element.get("default_cmd"),
				id: element.id,
				active: false,
				icon_class: element.get("icon_class"),
				desc: element.get("desc")
			};
			if (default_cmd == item.cmd) {
				item.active = true;
				current_name = item.name;
			}
			display_settings.push(item);
			});
		res.render('types', {
			scripts: display_settings,
			default_cmd: default_cmd,
			current_name: current_name
		});
	});
 }

exports.type_change = function(req, res) {
	var Room = Parse.Object.extend("Room");
	var currentUser = Parse.User.current();
	var room = currentUser.get("room");
	var new_room;
	var default_cmd;
	var current_name;
	var icon_class;
	var desc;
	room.fetch().then(function (room) {
		default_cmd = room.get("default_cmd");
		var Script = Parse.Object.extend("Script");
		var query = new Parse.Query(Script);
		return query.get(req.params.id);
	}).then(function (script) {
		var default_cmd = script.get("default_cmd");
		var settings = script.get("default_settings");
		var owner_cmd = script.get("owner_cmd");
		var default_path = script.get("default_path");
		return room.save({
			default_cmd: default_cmd,
			settings: settings,
			owner_cmd: owner_cmd,
			default_path: default_path
		});
	}).then(function(room) {
		console.log("New room...");
		console.log(room);
		return res.redirect("/portal/settings/");
	}, function(error){
		console.log("Fail.");
		console.log(error);
	});
}
