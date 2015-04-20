var bc = require('cloud/bootcards-functions');
var moment	= require('moment');

exports.list = function(req, res) {
	res.renderPjax('connections', {
  		activities: connections,
  		connection : connections[0],
   		menu: bc.getActiveMenu(menu, 'connections')
  	});
};

exports.read = function(req, res) {

	var connection = bc.getConnectionById(req.params.id);

	if (connection != null) {



		res.renderPjax( exports.getConnectionPartialRenderer(connection.type) , {
		 	activities : connections,
		   	connection: connection,
		    menu: bc.getActiveMenu(menu, 'connections')
		});

	}

}

exports.edit = function(req, res) {

	res.renderPjax('activity_edit', {
	 	activities : connections,
	   	activity: bc.getConnectionById(req.params.id),
	    menu: bc.getActiveMenu(menu, 'connections')
	});

}

/*a connection can be added to a contact or company*/
exports.add = function(req, res) {

	if (req.params.contactId) {

		var contact = bc.getContactById(req.params.contactId);

		res.renderPjax('activity_edit', {
	  		activities: connections,
	  		activity : {
	  			date : new Date(),
	  			isNew : true
	  		},
	  		contact: contact,
	   		menu: bc.getActiveMenu(menu, 'connections')
	  	});
	} else {

		res.renderPjax('activity_edit', {
	  		activities: connections,
	  		activity : {
	  			date : new Date(),
	  			isNew : true
	  		},
	   		menu: bc.getActiveMenu(menu, 'connections')
	  	});

	}
};

exports.save = function(req, res) {

	//retrieve the parent contact
	var contact = bc.getContactById(req.body.contactId);

	if (contact != null) {
		//found the contact: add new connection

		var connection = {
			type: req.body.type,
			subject: req.body.subject,
			date: moment(req.body.date),
			parentIds : [contact.id],
			details: req.body.details
		}

		connections.push(connection);

		res.renderPjax('contact', {
		 	contacts:contacts,
		   	menu: bc.getActiveMenu(menu, 'connections'),
		    contact: contact,
		    activities : bc.getConnectionsForParent(contact.id),
		});
	}

}

//returns the name of a partial used to render a specific connection type
exports.getConnectionPartialRenderer = function(type) {
	var renderWith = 'connections/text';		//default template

	if (type == 'file') {
		renderWith = 'connections/file';
	} else if (type == 'todo') {
		renderWith = 'connections/todo';
	} else if (type == 'text') {
		renderWith = 'connections/text';
	} else if (type == 'media') {
		renderWith = 'connections/media';
	}

	return renderWith;

}
