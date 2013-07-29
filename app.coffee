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

globals = 
  currentQuestion: questions[0]
  currentIndex: 0
  inRound: false

beginRound = () =>
  console.log "beginCount", globals.currentQuestion
  idBoard = secrets.idBoard
  question = globals.currentQuestion

  console.log "begin round, currentQuestion #{globals.currentQuestion.question}"
  async.auto
    wait: (next) ->
      setTimeout next, 30 * 1000

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

    scoreLists: ["lists", (next, {lists}) ->
      console.log "scoreList:", question.correctAnswer
      correctList = (_.findWhere lists, { name: question.correctAnswer }).id
      trelloUtil.renameList(question.correctAnswer + " - CORRECT ANSWER!!!", correctList, next)
    ]

    postScoreWait: ["scoreCards", "scoreLists", (next) ->
      setTimeout next, 3*1000
    ]

    moveCardsBack: ["postScoreWait", (next, {cards, lists}) ->
      questionList = (_.findWhere lists, {name: question.question }).id
      async.each cards, (card, next) ->
          trelloUtil.moveCard(card.id, questionList, next)
      , next()
    ]

    setupQuestions: ["moveCardsBack", (next) ->
      console.log "setupQuestionssss", globals.currentQuestion
      setupQuestion(next)
    ]

  , (err) ->
    console.log err if err
    globals.inRound = false
    console.log "done"


setupQuestion = (next) =>
  console.log "setupQuestion", globals.currentQuestion
  questionCounter = Math.floor(Math.random() * questions.length) + 1
  globals.currentQuestion = questions[questionCounter]
  question = globals.currentQuestion.question
  answers = globals.currentQuestion.answers
  idBoard = secrets.idBoard

  console.log "Setting up next question: #{question}"
  async.auto
    lists: (next) ->
      trelloUtil.getLists(idBoard, next)

    renameAnswers: [ "lists", (next, {lists} ) ->
      async.each _.zip(answers, _.rest (lists)), ([answer, list], next) ->
        trelloUtil.renameList(answer, list.id, next)
      , next
    ]

    renameQuestion: ["lists", (next, {lists} ) ->
      trelloUtil.renameList(question, lists[0].id, next)
    ]

  , next

setupQuestion (err) ->
  console.log err if err?

app.post "/", (req, res) ->
  res.send('ok')
  console.log "we got a post, inRound: #{globals.inRound}"
  if not globals.inRound
    globals.inRound = true
    console.log globals.currentQuestion
    beginRound()

http.createServer(app).listen app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'));
