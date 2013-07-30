express = require 'express'
argv = require('optimist').argv
http = require 'http'
async = require 'async'
_ = require 'underscore'
{ secrets } = require './api/secrets.coffee'
{ questions } = require './api/questions.coffee'
trelloUtil = require './api/trelloUtil.coffee'

app = express()
app.set 'port', argv.port || 1338
app.use express.logger('dev')
app.use express.bodyParser()

globals = 
  currentQuestion: questions[0]
  currentIndex: 0
  inRound: false

beginRound = () =>
  idBoard = secrets.idBoard
  question = globals.currentQuestion

  async.auto
    oldLists: (next) ->
      trelloUtil.getLists(idBoard, next)

    oldCards: (next) ->
      trelloUtil.getCards(idBoard, next)
    
    wait: ["oldLists","oldCards", (next, {oldLists}) ->
      numberOfCycles = 2
      async.timesSeries numberOfCycles, (i, next) =>
        newMessage = question.question + "\nTime Left: " + (numberOfCycles - i) * 5 + " seconds"
        trelloUtil.renameList newMessage, oldLists[0].id, (err) -> console.log err if err?
        setTimeout next, 5 * 1000
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
      console.log correctList
      async.each cards, (card, next) ->
        console.log card.idList, correctList
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
      setTimeout next, 3*1000
    ]

    moveCardsBack: ["postScoreWait", (next, {cards, lists}) ->
      questionList = (_.findWhere lists, {name: question.question }).id
      async.each cards, (card, next) ->
          trelloUtil.moveCard(card.id, questionList, next)
      , next
    ]

    setupQuestions: ["moveCardsBack", (next) ->
      setupQuestion(next)
    ]

  , (err) ->
    console.log err if err
    globals.inRound = false
    console.log "done"


setupQuestion = (next) =>
  questionCounter = Math.floor(Math.random() * questions.length)
  globals.currentQuestion = questions[questionCounter]
  question = globals.currentQuestion.question
  answers = globals.currentQuestion.answers
  idBoard = secrets.idBoard

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
  if req.body.action.idMemberCreator == secrets.id
    return

  console.log "we got a post, inRound: #{globals.inRound}"
  if not globals.inRound
    globals.inRound = true
    beginRound()

http.createServer(app).listen app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'));
