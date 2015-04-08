var bc = require('cloud/bootcards-functions');

exports.list = function(req, res){

	res.renderPjax('data', {
  		menu: bc.getActiveMenu(menu, 'data')
	});

};
