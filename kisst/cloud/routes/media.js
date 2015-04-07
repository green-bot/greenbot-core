var bc = require('../bootcards-functions.js');

exports.list = function(req, res){

	res.renderPjax('data', {
  		menu: bc.getActiveMenu(menu, 'data')
	});

};
