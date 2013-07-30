express = require 'express'
argv = require('optimist').argv
http = require 'http'
async = require 'async'
_ = require 'underscore'
winston = require 'winston'
{ secrets } = require './api/secrets.coffee'
{ questions } = require './api/questions.coffee'
trelloUtil = require './api/trelloUtil.coffee'

app = express()
app.set 'port', argv.port || 2337
app.use express.logger('dev')
app.use express.bodyParser()
winston.cli()

globals = 
  questionIndex: 0
  currentQuestion: questions[0]
  inRound: false

prefs =
  incrementalQuestionCounter : true
  postScoreWait: 3 
  refreshTimeLeftDelta: 5 
  numberOfRefreshDeltas: 2

winston.info "Starting Trillia", prefs

beginRound = () =>
  winston.info "starting next round!"
  idBoard = secrets.idBoard
  question = globals.currentQuestion

  async.auto
    oldLists: (next) ->
      trelloUtil.getLists(idBoard, next)

    oldCards: (next) ->
      trelloUtil.getCards(idBoard, next)
    
    wait: ["oldLists","oldCards", (next, {oldLists, oldCards}) ->
      winston.info "starting wait, found #{oldLists.length} list, and #{oldCards.length} cards"
      async.timesSeries prefs.numberOfRefreshDeltas, (i, next) =>
        newMessage = question.question + "\nTime Left: " + (prefs.numberOfRefreshDeltas - i) * prefs.refreshTimeLeftDelta + " seconds"
        trelloUtil.renameList newMessage, oldLists[0].id, (err) -> winson.error err if err?
        setTimeout next, prefs.refreshTimeLeftDelta * 1000
      , next
    ]

    lists: ["wait", (next) ->
      trelloUtil.getLists(idBoard, next)
    ]

    cards: ["wait", (next) ->
      trelloUtil.getCards(idBoard, next)
    ]

    scoreCards: ["lists", "cards", (next, {lists, cards}) ->
      correctList = (_.findWhere lists, { name: question.correctAnswer }).id
      async.each cards, (card, next) ->
        if card.idList == correctList
          trelloUtil.addCommentToCard(card.id, "WINNER!\nQuestion: #{question.question}\nAnswer: #{question.correctAnswer}", next)
        else
          next()
      , next
    ]

    scoreLists: ["lists", (next, {lists}) ->
      correctList = (_.findWhere lists, { name: question.correctAnswer }).id
      trelloUtil.renameList(question.correctAnswer + " - CORRECT ANSWER!!!", correctList, next)
    ]

    postScoreWait: ["scoreCards", "scoreLists", (next) ->
      setTimeout next, prefs.postScoreWait * 1000
    ]

    moveCardsBack: ["postScoreWait", (next, {cards, lists}) ->
      questionList = lists[0].id
      async.each cards, (card, next) ->
          trelloUtil.moveCard(card.id, questionList, next)
      , next
    ]

    setupQuestions: ["moveCardsBack", (next) ->
      setupQuestion(next)
    ]

  , (err) ->
    winston.error err if err
    globals.inRound = false
    winston.info "finished round"


setupQuestion = (next) =>
  winston.info "setting up question", { incrCounter: prefs.incrementalQuestionCounter }
  if prefs.incrementalQuestionCounter
    globals.questionIndex = (1 + globals.questionIndex) % questions.length
  else # Random
    globals.questionIndex = Math.floor(Math.random() * questions.length)
  winston.info "questionIndex", { questionIndex: globals.questionIndex }
  globals.currentQuestion = questions[globals.questionIndex]
  question = globals.currentQuestion.question
  answers = globals.currentQuestion.answers
  idBoard = secrets.idBoard

  winston.info "next question", globals.currentQuestion
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
  winston.error err if err?

app.post "/", (req, res) ->
  res.send('ok')

  winston.info("post recieved", {inRound: globals.inRound, isTrillia: req.body.action?.idMemberCreator == secrets.id})
  if req.body.action?.idMemberCreator == secrets.id
    return

  if not globals.inRound
    globals.inRound = true
    beginRound()

http.createServer(app).listen app.get('port'), ->
  winston.info "Express server listening on port #{app.get('port')}"
