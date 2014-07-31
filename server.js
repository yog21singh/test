'use strict';
var express = require('express');
var formidable = require('formidable'),
     http = require('http'),
    util = require('util');
var app = express();
app.use(express.static(__dirname + '/public'));
var a;
var nunjucks = require('nunjucks')
nunjucks.configure('views', {
    autoescape: true,
    express: app
});
var mongojs = require('mongojs');
var db = mongojs('127.0.0.1:27017/querydb', ['query']);
app.get('/', function(req, res) {
    res.render('newQuery.html');
});

 app.get('/newQuery.html', function(req, res) {
    res.render('newQuery.html');
});


app.get('/oldQueries.html', function(req, res) {
    res.render('oldQueries.html');
});

app.post('/query', function(req, res){

    
  var form = new formidable.IncomingForm();
console.log(form['name']);
//console.log(util.inspect({form:form}));
    res.send(200);
    //    res.send(form);
//  form.parse(req, function(err, fields, files) {
    //res.send(200);
//       console.log(util.inspect({fields: fields, files: files}));
      //console.log("Entries of form:");
      //console.log(form);
    //db.query.insert(query);
      
   /* console.log(util.inspect({fields: fields, files: files}));

    var transport = nodemailer.createTransport("sendmail", {
      path: "/usr/sbin/sendmail"
    });

    // setup e-mail data with unicode symbols
    var mailOptions = {
       from: "Digiapt Website <website@digiapt.com>", // sender address
       to: "anil.gracias@digiapt.com", // list of receivers
       subject: "Note from the virtual world", // Subject line
       text: "Hello world ✔", // plaintext body
       html: "<b>Hello world ✔</b>" // html body
    };

    mailOptions.html = "<b>Origin: Contact</b><br/>" + util.inspect({fields: fields, files: files});
    mailOptions.text = "Origin: Contact. " + util.inspect({fields: fields, files: files});

    // send mail with defined transport object
    transport.sendMail(mailOptions, function(error, response){
      if(error) {
          console.log(error);
      } else {
          console.log("Message sent: " + response.message);
      }
      transport.close(); // shut down the connection pool, no more messages
    });*/

//  });
});


/*app.post('/submitquery', function(req, res) {
    //console.log(req);
    console.log(req.params);
    console.log(req.body);
    console.log(req.query);
    var query=req.param("name");
    //console.log(query);
    //db.query.insert(query);
    res.send("Success");
});*/

 app.get('/oldQueries', function(req, res) { 
    db.query.count(function(err, cnt) {
    // console.log(cnt);
        db.query.find({},function(err,result){
      //  console.log(result);
        res.send({
                "queries":result,
                "count":cnt
            });         
    });
          
    });
  
});


var server = app.listen(3000, function(){
    console.log('Ready to take calls on %d', server.address().port);
});
