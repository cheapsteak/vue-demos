var flo = require('fb-flo');
var path = require('path');
var fs = require('fs');

var buildPath = './build/';

var server = flo( buildPath,
    {
    port: 8888,
    host: 'localhost',
    verbose: false,
    glob: [ '**/*.js', '**/*.css' ]
  }, resolver);

server.once('ready', function() {
  console.log('fb-flo server Ready!');
});

function resolver(filepath, callback) {

  console.log('fb-flo:', filepath);

  callback({
    resourceURL: 'bundle' + path.extname(filepath)
    ,contents: fs.readFileSync(buildPath + filepath)
    ,update: function(_window, _resourceURL) {
      // this function is executed in the browser, immediately after the resource has been updated with new content
      // perform additional steps here to reinitialize your application so it would take advantage of the new resource
      console.log("Resource " + _resourceURL + " has just been updated with new content");
    }
  });
}