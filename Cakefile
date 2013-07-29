flour = require 'flour'

flour.minifiers.disable 'js'

task 'build:jsbundle', ->
    console.log "[+] Building jsbundle"
    bundle [
        'public/js/jquery-2.0.2.js'
        'public/js/underscore.js'
        'public/js/backbone.js'
        'public/js/bootstrap.js'
        'public/js/flippant.js'
        'public/js/gistLoader.js'
        'public/js/blog.coffee'
    ], 'public/all.js'

task 'build:cssbundle', ->
    console.log "[+] Building cssbundle"
    bundle [
        'public/css/bootstrap.css'
        'public/css/bootstrap-responsive.css'
        'public/css/flippant.css'
        'public/css/blog.styl'
    ], 'public/all.css'

task 'build', ->
    invoke 'build:cssbundle'
    invoke 'build:jsbundle'

task 'watch', ->
    invoke 'build'

    watch 'public/css/*.styl', -> invoke 'build:cssbundle'

    watch 'app.coffee', -> invoke 'build:jsbundle'
    watch 'public/js/*.coffee', -> invoke 'build:jsbundle'
