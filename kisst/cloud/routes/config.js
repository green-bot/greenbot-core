var bc = require('../bootcards-functions.js');
var _ = require('underscore');

exports.list = function(req, res){
	var room_name = "18587036359";
	var room_settings = _.find(rooms, function(room){ return room.name == room_name});
	var setting_keys = _.keys(room_settings.settings);
	var display_settings = [];
	_.each(setting_keys, function(element, index, list) {
		var item = {
			key: element,
			v: room_settings.settings[element]
		};
		display_settings.push(item);
	});

	res.renderPjax('config', {
		config: display_settings,
		menu: bc.getActiveMenu(menu, 'config')
	});

	console.log("Finished.");
};

exports.edit = function(req, res){
	var room_name = "18587036359";
	var room_settings = _.find(rooms, function(room){ return room.name == room_name});
	var setting_keys = _.keys(room_settings.settings);
	var display_settings = [];
	_.each(setting_keys, function(element, index, list) {
		var item = {
			key: element,
			v: room_settings.settings[element]
		};
		display_settings.push(item);
	});

	res.renderPjax('config_edit', {
		config: display_settings,
		menu: bc.getActiveMenu(menu, 'config')
	});
};
