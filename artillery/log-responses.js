module.exports = {
  logResponse: function(req, res, context, ee) {
    console.log('=== RESPONSE ===');
    console.log('Status Code:', res.statusCode);
    console.log('Body:', res.body);
    console.log('================');
  }
};