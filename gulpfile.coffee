_          = require 'lodash'
browserify = require 'browserify'
partialify = require 'partialify'
chalk      = require 'chalk'
CSSmin     = require 'gulp-minify-css'
ecstatic   = require 'ecstatic'

express    = require 'express'
compression= require 'compression'

gulp       = require 'gulp'
gutil      = require 'gulp-util'
notify     = require 'gulp-notify'

path       = require 'path'

prefix     = require 'gulp-autoprefixer'
prettyTime = require 'pretty-hrtime'
source     = require 'vinyl-source-stream'
transform  = require 'vinyl-transform'
streamify  = require 'gulp-streamify'
stylus     = require 'gulp-stylus'
uglify     = require 'gulp-uglify'
watchify   = require 'watchify'
exorcist   = require 'exorcist'
to5        = require 'babelify'

sourcemaps = require 'gulp-sourcemaps'
concat     = require 'gulp-concat'

production = process.env.NODE_ENV is 'production'

spawn = require('spawn-cmd').spawn
exec = require('spawn-cmd').exec
node = undefined

paths =
  scripts:
    vendorSource: './src/vendor.js'
    appSource: './src/index.js'
    destination: './build/js/'
    vendorOutfile: 'vendor.js'
    appOutfile: 'main.js'
  templates:
    src: ['./src/index.html']
    destination: './build/'
  styles:
    source: './src/index.styl'
    watch: './src/**/*.styl'
    destination: './build/css/'
  assets:
    source: './src/assets/**/*.*'
    watch: './src/assets/**/*.*'
    destination: './build/'

# Gather all the library dependencies so they can be bundled separately into vendor.js
packageJson = require './package.json'
dependencies = (key for key of _.extend({},
  _.omit(packageJson.dependencies, 'babel-runtime'),
  packageJson.peerDependencies))

babelConfig =
  optional: ['runtime']
  experimental: true

browserifyAppBundle = (options) ->
  entries = paths.scripts.appSource
  browserify
    entries: [entries]
    debug: not production
    cache: {}
    packageCache: {}
    fullPaths: true
  .external dependencies
  .transform partialify
  .transform to5.configure babelConfig

browserifyVendorBundle = ->
  browserify
    entries: [paths.scripts.vendorSource]
    debug: not production
    cache: {}
    packageCache: {}
    fullPaths: true
  .require dependencies
  .transform to5.configure babelConfig

handleError = (err) ->
  args = Array::slice.call(arguments)
  gutil.log err
  notify.onError(
    title: 'Compile Error'
    message: '<%= error.message %>').apply this, args
  gutil.beep()
  this.emit 'end'

compileScripts = (bundle, outfile) ->
  build = bundle.bundle()
    .on 'error', handleError
    .pipe source outfile

  build.pipe(streamify(uglify())) if production
  build
    .pipe transform => exorcist paths.scripts.destination + outfile + '.map'
    .pipe gulp.dest paths.scripts.destination

gulp.task 'scripts:vendor', ->
  compileScripts(browserifyVendorBundle(), paths.scripts.vendorOutfile);

gulp.task 'scripts:main', ->
  compileScripts(browserifyAppBundle(), paths.scripts.appOutfile);

gulp.task 'templates', ->
  pipeline = gulp
    .src paths.templates.src
    .on 'error', handleError
    .pipe gulp.dest paths.templates.destination
  pipeline

gulp.task 'styles', ->
  styles = gulp
    .src paths.styles.source
    .pipe sourcemaps.init()
    .pipe stylus
      'include css': true

    .on 'error', handleError
    .pipe prefix 'last 2 versions', 'Chrome 34', 'Firefox 28', 'iOS 7'

  styles = styles.pipe(CSSmin()) if production
  styles = styles
    .pipe concat('bundle.css')
    .pipe sourcemaps.write('.')
    .pipe gulp.dest paths.styles.destination
  styles

gulp.task 'assets', ->
  gulp
    .src paths.assets.source
    .pipe gulp.dest paths.assets.destination

gulp.task 'server', ->
  app = express()
  app.use compression()
  app.use express.static path.join __dirname, 'build'
  app.get '/*', (req, res) ->
    res.sendFile(__dirname + '/build/index.html')

  require('http')
    .createServer app
    .listen 9001

gulp.task 'watch', ->
  gulp.watch paths.templates.src, ['templates']
  gulp.watch paths.styles.watch, ['styles']
  gulp.watch paths.assets.watch, ['assets']
  gulp.watch paths.scripts.vendorSource, ['scripts:vendor']

  bundle = watchify browserifyAppBundle()

  bundle.on 'update', ->
    gutil.log "Starting '#{chalk.cyan 'rebundle'}'..."
    start = process.hrtime()
    build = bundle.bundle()
      .on 'error', handleError

      .pipe source paths.scripts.appOutfile

    build
      .pipe transform -> exorcist paths.scripts.destination + paths.scripts.appOutfile + '.map'
      .pipe gulp.dest paths.scripts.destination
    gutil.log "Finished '#{chalk.cyan 'rebundle'}' after #{chalk.magenta prettyTime process.hrtime start}"

  .emit 'update'

gulp.task 'watch_bundle', ->
  gulp.watch [paths.scripts.destination + '*.js', paths.styles.destination + '*.css'], ->
    if !node
      gulp.start 'fb-flo'

gulp.task 'fb-flo', ->
  gutil.log "Starting '#{chalk.cyan 'fb-flo'}'..."
  if node
    node.kill()
  gulp.start 'terminateOrphanFbFlo'
  node = spawn('node', [ 'flo.js' ], stdio: 'inherit')
  node.on 'close', (code) ->
    if code == 8
      gulp.log 'Error detected, turning off fb-flo...'

gulp.task 'terminateOrphanFbFlo', ->
  fbFloRegex = /node\s+(\d+)\s/g
  fbFloLsof = spawn('lsof', [
    '-i'
    ':8888'
  ])
  fbFloLsof.stderr.on 'data', onStderr
  fbFloLsof.on 'close', onStdClose
  fbFloLsof.stdout.on 'data', (data) ->
    fbFloPid = ''
    results = fbFloRegex.exec(data)
    if results and results[1]
      exec 'kill -9 ' + results[1]

gulp.task 'deploy-test', ->
  gulp
    .src 'build/**'
    .pipe rsync
      root: 'build'
      destination: '/var/www/html/bst-game'
      incremental: true
      hostname: '54.86.34.240'
      username: 'ubuntu'
      progress: true

gulp.task 'no-js', ['templates', 'styles', 'assets']
gulp.task 'build', ['scripts:vendor', 'scripts:main', 'no-js']
# scripts and watch conflict and will produce invalid js upon first run
# which is why the no-js task exists.
gulp.task 'default', ['fb-flo', 'scripts:vendor', 'watch', 'no-js', 'server', 'watch_bundle']


# Utility Functions

onError = (err) ->
  console.log err
  # kill $(ps aux | grep 'node flo' | awk '{print $2}')
  if node
    node.kill()
    node = false

onStderr = (data) ->
  console.log 'stderr: ' + data

onStdClose = (code) ->
  console.log 'child process exited with code ' + code