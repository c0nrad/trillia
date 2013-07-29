request = require('request')
querystring = require 'querystring'
_ = require 'underscore'
{secrets} = require('./secrets')
async = require 'async'


moveCard = exports.moveCard = (cardId, listId, next) ->
  trelloRun("put", "cards/#{cardId}/idList", {value: listId}, next)

addCommentToCard = exports.addCommentToCard = (cardId, comment, next) ->
  trelloRun("post", "cards/#{cardId}/actions/comments", {text: comment}, next)

getCards = exports.getCards = (boardId, next) ->
  trelloRun("get", "boards/#{boardId}/cards", {}, next)

getLists = exports.getLists = (boardId, next) ->
  trelloRun("get", "boards/#{boardId}/lists", {}, next)

renameList = exports.renameList = (name, listId, next) ->
  trelloRun("put", "lists/#{listId}/name", {value: name}, next)

addCardToList = exports.addCardToBoard = (name, boardId) ->
  console.log "NOT IMPLEMENTED."
  next()

addListToBoard = exports.addListToBoard = (name, idBoard) ->
  trelloRun("post", "lists", { name, idBoard })

makeBoard = exports.makeBoard =  (name) ->
  trelloRun("post", "boards", { name })

memberMe = exports.memberMe = () ->
  trelloRun("get", "members/me")

trelloRun = (method, route, params, next) ->
  params = _.extend {}, params, { token: secrets.token, key: secrets.appKey } 
  opts = 
    url: "http://trello.com/1/" + route + "?" + querystring.stringify params
    method: method
    json: params

  request opts, (error, response, body) ->
    next(error, body)
