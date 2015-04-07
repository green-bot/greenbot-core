

//sort an object by a property
exports.sortByField = function(data, field) {

	return data.sort(

		function(a,b) {
			return ( (a[field] > b[field]) ? 1 : ((a[field] < b[field]) ? -1 : 0));
		}

	);

}

//set the active menu
exports.getActiveMenu = function(menu, id) {

	for (var i=0; i<menu.length; i++) {
		menu[i].active = (id == menu[i].id ? true : false);
	}

	return menu;

}

//return an icon name for an item type
exports.getIconForType = function(type) {

	switch (type) {

	case "company":
		return "fa-building-o";
	case "contact":
		return "fa-user-o";
	case "document":
		return "fa-paperclip";
	case "letter":
		return "fa-file-o";
	case "ticket":
		return "fa-medkit";
	case "phone":
		return "fa-phone-square";
	case "opportunity":
		return "fa-bar-chart-o";
	case "visit":
		return "fa-users";
	case "info":
		return "fa-info-circle";
	case "mail":
		return "fa-edit";
	case "todo":
		return "fa-check-square-o";
	case "text":
		return "fa-file-text-o";
	case "media":
		return "fa-picture-o";
	case "file":
		return "fa-paperclip";
	default:
		return "fa-file-o";
	}

}

exports.getUniqueId = function() {
	return (+new Date()).toString(36);
}

exports.getContactById = function(id) {
	var contact = getById(contacts, id);
	if (contact != null) {
		contact.connections = getForParent(connections, contact.id);
		contact.isNew = false;
	}
	return contact;
}
exports.getConversationById = function(id) {
	var company = getById(conversations, id);
	if (company != null) {
		company.connections = getForParent(connections, company.id);
		company.contacts = getForParent(contacts, company.id);
	}
	return company;
}
exports.getConnectionById = function(id) {
	return getById(connections, id);
}

exports.getContactsForConversation = function(parentId) {
	return getForParent(contacts, parentId);
}
exports.getConnectionsForParent = function(parentId) {
	return getForParent(connections, parentId);
}

var getForParent = function( from, id) {

	var results = [];

	for (var i=0; i<from.length; i++) {
		var fromEl = from[i];
		for (var j=0; j<fromEl.parentIds.length; j++) {
			if (fromEl.parentIds[j] == id) {
				results.push(fromEl);
				break;
			}
		}
	}
	return results;
}

var getById = function(from, id) {
	if (from == null || from.length==0) {
		return null;
	}

	if (id != null ) {
		for (var i=0; i<from.length; i++) {
			if (from[i].id == id) {
				return from[i];
			}
		}
	}

	return null;
}
