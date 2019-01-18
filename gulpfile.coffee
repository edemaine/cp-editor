gulp = require 'gulp'
gulpPug = require 'gulp-pug'
gulpCoffee = require 'gulp-coffee'
gulpChmod = require 'gulp-chmod'

exports.pug = pug = ->
  gulp.src '*.pug'
  .pipe gulpPug pretty: true
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

exports.coffee = coffee = ->
  gulp.src '*.coffee', ignore: 'gulpfile.coffee'
  .pipe gulpCoffee()
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

exports.watch = watch = ->
  gulp.watch '*.pug', pug
  gulp.watch '*.styl', pug
  gulp.watch '*.coffee', coffee

exports.default = gulp.series ...[
  gulp.parallel pug, coffee
]
