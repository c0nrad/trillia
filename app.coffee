express = require('express')
argv = require('optimist').argv
http = require('http')
async = require 'async'
_ = require 'underscore'
{ secrets } = require './api/secrets.coffee'
{ questions } = require './api/questions.coffee'
trelloUtil = require './api/trelloUtil.coffee'


app = express()
app.set 'port', argv.port || 3333
app.use express.logger('dev')

inRound = false
questionCounter = 0

app.post "/", (req, res) ->
  res.send('ok')
  console.log "we got a post, inRound: #{inRound}"
  if not inRound
    inRound = true
    beginRound(secrets.idBoard, questions[questionCounter])
    questionCounter = (questionCounter + 1) % questions.length

http.createServer(app).listen app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'));

beginRound = (idBoard, question) ->
  async.auto

    setupQuestions: (next) ->
      setupQuestion(question.question, question.answers, idBoard, next)

    wait: ["setupQuestions", (next) ->
      setTimeout next, 3 * 1000
    ]


    lists: ["wait", (next) ->
      console.log "lists"
      trelloUtil.getLists(idBoard, next)
    ]

    cards: ["wait", (next) ->
      trelloUtil.getCards(idBoard, next)
    ]

    scoreCards: ["cards", (next, {lists, cards}) ->
      correctList = (_.findWhere lists, { name: question.correctAnswer }).id
      async.each cards, (card, next) ->
        if card.idList == correctList
          trelloUtil.addCommentToCard(card.id, "WINNER!\nQuestion: #{question.question}\nAnswer: #{question.correctAnswer}", next)
      , next()
    ]

    scoreLists: ["cards", (next, {lists}) ->
      correctList = (_.findWhere lists, { name: question.correctAnswer }).id
      trelloUtil.renameList(question.correctAnswer + " - CORRECT ANSWER!!!", correctList, next)
    ]

    postScoreWait: ["scoreCards", (next) ->
      setTimeout next, 3*1000
    ]

    moveCardsBack: ["postScoreWait", (next, {cards, lists}) ->
      questionList = (_.findWhere lists, {name: question.question }).id
      async.each cards, (card, next) ->
          trelloUtil.moveCard(card.id, questionList, next)
      , next()
    ]
  , (err) ->
    console.log err if err
    inRound = false
    console.log "done"


setupQuestion = (question, answers, idBoard, next) ->
  console.log "Setting up next question: #{question}"
  async.auto
    lists: (next) ->
      console.log "lists"
      trelloUtil.getLists(idBoard, next)

    renameAnswers: [ "lists", (next, {lists} ) ->
      console.log lists
      async.each _.zip(answers, _.rest (lists)), ([answer, list], next) ->
        trelloUtil.renameList(answer, list.id, next)
      , next
    ]

    renameQuestion: ["lists", (next, {lists} ) ->
      console.log "renameQuestion"
      trelloUtil.renameList(question, lists[0].id, next)
    ]

  , next
