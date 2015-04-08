var bc = require('cloud/bootcards-functions');
var moment	= require('moment');
var connection = require('cloud/connection');

exports.list = function(req, res){

	var firstId = contacts[0].id;

	res.renderPjax('contacts', {
  		contacts : contacts,
  		contact : bc.getContactById(firstId),
   		menu: bc.getActiveMenu(menu, 'contacts')
	});
};

exports.read = function(req, res) {

	res.renderPjax('contact', {
	 	contacts:contacts,
	   	contact: bc.getContactById(req.params.id),
	    menu: bc.getActiveMenu(menu, 'contacts')
	});

}

exports.edit = function(req, res) {

	res.renderPjax('contact_edit', {
	 	contacts:contacts,
	   	menu: bc.getActiveMenu(menu, 'contacts'),
		contact: bc.getContactById(req.params.id)
	});

}

exports.add = function(req, res) {

	if (req.params.companyId) {

		var company = (req.params.companyId ? bc.getConversationById(req.params.companyId) : null);

		res.renderPjax('contact_edit', {
	  		contacts:contacts,
	  		contact : {
	  			isNew : true,
	  			companyId : (company ? company.id : null)
	  		},
	   		menu: bc.getActiveMenu(menu, 'contacts')
	  	});
	} else {
		res.renderPjax('contact_edit', {
	  		contacts:contacts,
	  		contact : {
	  			isNew : true
	  		},
	   		menu: bc.getActiveMenu(menu, 'contacts')
	  	});
	}
};

exports.save = function(req,res) {

	var contact = bc.getContactById(req.params.id);

	if (contact != null) {
		//found the contact: update it
		contact.firstName = req.body.firstName;
		contact.lastName = req.body.lastName;
		contact.email = req.body.email;
		contact.phone = req.body.phone;
		contact.jobTitle = req.body.jobTitle;
		contact.department = req.body.department;
		contact.salutation = req.body.salutation;
	}

	res.renderPjax('contacts', {
	 	contacts:contacts,
	   	menu: bc.getActiveMenu(menu, 'contacts'),
	    contact: contact
	});

}

/* NOTES */

exports.listConnections = function(req, res) {

	res.renderPjax('activities_for_contact', {
  		contact : bc.getContactById(req.params.id)
	});

}

exports.readConnection = function(req, res) {

	var contact = bc.getContactById( req.params.id);
	contact.isContact = true;

	var tgtConnection = bc.getConnectionById(req.params.connectionId);

	res.renderPjax( connection.getConnectionPartialRenderer(tgtConnection.type), {
		contact : contact,
  		connection : tgtConnection
	});
}
exports.editConnection = function(req, res) {

	var contact = bc.getContactById( req.params.id);
	contact.isContact = true;

	var connection = bc.getConnectionById( req.params.connectionId);

	res.renderPjax('contact_activity_edit', {
		contact : contact,
		activity : connection
	});
}
exports.addConnection = function(req, res) {

	var contact = bc.getContactById(req.params.id);

	res.renderPjax('contact_activity_edit', {
  		contact: contact,
  		activity : {
  			date : moment().format("DD/MM/YYYY HH:mm"),
  			isNew : true
  		}
	});
}

exports.saveConnection = function(req, res) {

	var connection;
	var contact = bc.getContactById(req.params.id);

	if (req.params.connectionId) {

		connection = bc.getConnectionById(req.params.connectionId);
		connection.type = req.body.type;
		connection.subject = req.body.subject;
		connection.date = moment(req.body.date, "DD/MM/YYYY HH:mm");
		connection.details = req.body.details;

	} else {

		connection = {
			id: bc.getUniqueId(),
			parentIds : [req.params.id],
			type: req.body.type,
			subject: req.body.subject,
			date: moment(req.body.date, "DD/MM/YYYY HH:mm"),
			details: req.body.details
		}

		connections.push(connection);
		contact.connections.push(connection);

	}

	if (contact != null) {

		res.renderPjax('activities_for_contact', {
	  		contact : contact
		});
	}

}
