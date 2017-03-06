Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../scripts/ping.coffee"
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'
Director = require '../../src/modules/Director'
Playbook = require '../../src/Playbook'

describe '#Director', ->

  # create room and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'
    @robot = @room.robot
    @robot.on 'respond', (res) => @res = res # store every response sent
    @robot.on 'receive', (res) => @rec = res # store every message received
    @robot.log.info = @robot.log.debug = -> # silence
    @spy = _.mapObject Director.prototype, (val, key) ->
      sinon.spy Director.prototype, key # spy on all the class methods
    @room.user.say 'tester', 'hubot ping' # trigger first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  describe 'constructor', ->

    context 'without env vars or optional args', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        @director = new namespace.Director @robot

      it 'does not throw', ->
        @constructor.should.not.have.threw

      it 'has empty array names', ->
        @director.names.should.eql []

      it 'has default config', ->
        @director.config.should.eql
          type: 'whitelist'
          scope: 'username'
          reply: "Sorry, I can't do that."

      it 'calls keygen to create a random key', ->
        @spy.keygen.getCall(0).should.have.calledWith()

      it 'stores the generated key as an attribute', ->
        @director.key.length.should.equal 12

    context 'with key', ->

      beforeEach ->
        @director = new Director @robot, 'Orson Welles'

      it 'calls keygen with provided source', ->
        @spy.keygen.getCall(0).should.have.calledWith 'Orson Welles'

      it 'stores the slugified source key as an attribute', ->
        @director.key.should.equal 'Orson-Welles'

    context 'with options', ->

      beforeEach ->
        @director = new Director @robot, deniedReply: "DENIED!"

      it 'stores passed options in config', ->
        @director.config.deniedReply.should.equal "DENIED!"

    context 'with authorise function', ->

      beforeEach ->
        @authorise = -> null
        @director = new Director @robot, @authorise

      it 'stores the given function as its authorise method', ->
        @director.authorise = @authorise

    context 'with env var for names', ->

      beforeEach ->
        process.env.WHITELIST_USERS = 'Emmanuel'
        process.env.WHITELIST_ROOMS = 'Capital'
        process.env.BLACKLIST_USERS = 'Winston,Julia,Syme'
        process.env.BLACKLIST_ROOMS = 'Labour'

      afterEach ->
        delete process.env.WHITELIST_USERS
        delete process.env.WHITELIST_ROOMS
        delete process.env.BLACKLIST_USERS
        delete process.env.BLACKLIST_ROOMS

      context 'whitelist type, username scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'whitelist'
            scope: 'username'

        it 'stores the whitelisted usernames from env', ->
          @director.names.should.eql ['Emmanuel']

      context 'whitelist type, room scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'whitelist'
            scope: 'room'

        it 'stores the whitelisted rooms from env', ->
          @names.rooms.should.eql ['Capital']

      context 'blacklist type, username scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'blacklist'
            scope: 'username'

        it 'stores the blacklisted usernames from env', ->
          @director.names.should.eql ['Winston','Julia','Syme']

      context 'blacklist type, room scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'blacklist'
            scope: 'room'

        it 'stores the blacklisted rooms from env', ->
          @director.names.should.eql ['Labour']

    context 'with env var for reply', ->

      beforeEach ->
        process.env.DENIED_REPLY = "403 Sorry."
        @director = new Director @robot

      afterEach ->
        delete process.env.DENIED_REPLY

      it 'stores env vars in config', ->
        @director.config.deniedReply.should.equal "403 Sorry."

    context 'with env vars and args for reply', ->

      beforeEach ->
        process.env.DENIED_REPLY = "403 Sorry."
        @director = new Director @robot, deniedReply: "DENIED!"

      afterEach ->
        delete process.env.DENIED_REPLY

      it 'stores passed options in config (overriding env vars)', ->
        @director.config.deniedReply.should.equal "DENIED!"

    context 'with invalid option for type', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        try @director = new namespace.Director @robot,
          type: 'pinklist'

      it 'should throw error', ->
        @constructor.should.have.threw

    context 'with invalid option for scope', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        try @director = new namespace.Director @robot,
          scope: 'robot'

      it 'should throw error', ->
        @constructor.should.have.threw

  describe '.keygen', ->

    beforeEach ->
      @director = new Director @robot

    context 'with a source string', ->

      beforeEach ->
        @result = @director.keygen '%.test @# String!'

      it 'converts or removes unsafe characters', ->
        @result.should.equal 'test-String'

    context 'without source', ->

      beforeEach ->
        @result = @director.keygen()

      it 'creates a string of 12 random characters', ->
        @result.length.should.equal 12

  describe '.add', ->

    beforeEach ->
      @director = new Director @robot

    context 'given array of names', ->

      beforeEach ->
        @director.add ['pema', 'nima']

      it 'stores them in the names array', ->
        @director.names.should.eql ['pema', 'nima']

    context 'given single name', ->

      beforeEach ->
        @director.add 'pema'

      it 'stores it in the names array', ->
        @director.names.should.eql ['pema']

    context 'given array of names, some existing', ->

      beforeEach ->
        @director.add ['pema', 'juan']

      it 'adds any missing, not duplicating existing', ->
        @director.names.should.eql ['yeon', 'juan', 'pema']

  describe '.remove', ->

    beforeEach ->
      @director = new Director @robot
      @director.names = ['yeon', 'pema', 'juan', 'nima']

    context 'given array of names', ->

      beforeEach ->
        @director.remove ['pema','nima']

      it 'removes them from the names array', ->
        @director.names.should.eql ['yeon', 'juan']

    context 'with single name', ->

      beforeEach ->
        @director.remove 'pema'

      it 'removes it from the names array', ->
        @director.names.should.eql ['yeon', 'juan', 'nima']

    context 'with array names, some not existing', ->

      beforeEach ->
        @director.remove ['frank', 'pema', 'juan', 'nima']

      it 'removes any missing, ignoring others', ->
        @director.names.should.eql ['yeon']

  describe '.directScene', ->

    beforeEach ->
      @director = new Director @robot
      @scene = new Scene @robot
      @director.directScene @scene

    context 'when scene enter manually called - user not allowed', ->

      beforeEach ->
        @dialogue = @scene.enter @res

      it 'calls .canEnter to check if origin of response can access', ->
        @spy.canEnter.getCall(0).should.have.calledWith @res

      it 'preempts scene.enter, returning false instead', ->
        @dialogue.should.be.false

    context 'when scene enter manually called - user allowed', ->

      beforeEach ->
        @director.names = ['tester']
        @dialogue = @scene.enter @res

      it 'calls .canEnter to check if origin of response can access', ->
        @spy.canEnter.getCall(0).should.have.calledWith @res

      it 'allowed the .enter method, returning a Dialogue object', ->
        @dialogue.should.be.instanceof Dialogue

    context 'when matched listeners - user not allowed', ->

      # TODO: test middleware attached

    context 'when matched listeners - user allowed', ->

      # TODO: test middleware attached

  describe '.canEnter', ->

    context 'whitelist without authorise function', ->

      beforeEach ->
        @director = new Director @robot

      context 'no list', ->

        beforeEach ->
          @result = @director.canEnter @res

        it 'returns true', ->
          @result.should.be.true

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.canEnter @res

        it 'returns true', ->
          @result.should.be.true

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.canEnter @res

        it 'returns false', ->
          @result.should.be.false

    context 'blacklist without authorise function', ->

      beforeEach ->
        @director = new Director @robot,
          type: 'blacklist'

      context 'no list', ->

        beforeEach ->
          @result = @director.canEnter @res

        it 'returns true', ->
          @result.should.be.true

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.canEnter @res

        it 'returns false', ->
          @result.should.be.false

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.canEnter @res

        it 'returns true', ->
          @result.should.be.true

    context 'whitelist with authorise function', ->

      beforeEach ->
        @authorise = sinon.spy -> 'AUTHORISE'
        @director = new Director @robot, @authorise

      context 'no list', ->

        beforeEach ->
          @result = @director.canEnter @res

        it 'calls authorise function with username and res', ->
          @authorise.getCall(0).should.have.calledWith 'tester', @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.canEnter @res

        it 'returns true', ->
          @result.should.be.true

        it 'does not call authorise function', ->
          @authorise.should.not.have.calledOnce

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.canEnter @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

    context 'blacklist with authorise function', ->

      beforeEach ->
        @authorise = sinon.spy -> 'AUTHORISE'
        @director = new Director @robot, @authorise

      context 'no list', ->

        beforeEach ->
          @result = @director.canEnter @res

        it 'calls authorise function with username and res', ->
          @authorise.getCall(0).should.have.calledWith 'tester', @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.canEnter @res

        it 'returns false', ->
          @result.should.be.false

        it 'does not call authorise function', ->
          @authorise.should.not.have.calledOnce

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.canEnter @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

# TODO test that it replies when denied, through manual call or middleware
