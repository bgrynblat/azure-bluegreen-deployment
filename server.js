const fs = require('fs');
const express = require('express');

var app = express();

var port = process.env.PORT || 3000;

app.get("/", function(req, res) {
	res.status(200).send("Server started on port "+port+" on "+started_at);
});

var server = app.listen(port);
var started_at = new Date().toString();

console.log('Listening on port '+port+'...');