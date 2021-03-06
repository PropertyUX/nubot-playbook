'use strict'

/* eslint-disable no-template-curly-in-string */

const sinon = require('sinon')
const chai = require('chai')
chai.use(require('sinon-chai'))
chai.use(require('chai-subset'))
const should = chai.should()

const pretend = require('hubot-pretend')
const improv = require('../../lib/modules/improv')

describe('Improv', () => {
  context('singleton', () => {
    before(() => pretend.start())
    after(() => pretend.shutdown())

    it('sequential use returns existing instance', () => {
      let improvA = improv.use(pretend.robot)
      let improvB = improv.use(pretend.robot)
      improvA.should.eql(improvB)
    })

    it('instance persists after test robot shutdown', () => {
      should.exist(improv.instance)
    })

    it('use after clear returns new instance', () => {
      let improvA = improv.use(pretend.robot)
      improv.reset()
      let improvB = improv.use(pretend.robot)
      improvA.should.not.eql(improvB)
    })

    it('overwrite robot when reused', () => {
      improv.use(pretend.robot).robot.should.eql(pretend.robot)
    })

    it('configuration merges existing config', () => {
      improv.configure({ foo: 'bar' })
      improv.configure({ baz: 'qux' })
      improv.instance.config.should.include({ foo: 'bar', baz: 'qux' })
    })
  })

  context('instance', () => {
    beforeEach(() => {
      pretend.start()
      improv.use(pretend.robot)
      improv.configure({ save: false })

      // generate first listen response
      pretend.robot.hear(/test/, () => null) // listen for tests
      pretend.user('tester', { room: 'testing' }).send('test')
    })

    afterEach(() => {
      pretend.shutdown()
      improv.reset()
    })

    describe('.use', () => {
      it('attaches response middleware to robot', () => {
        pretend.robot.responseMiddleware.should.have.callCount(1)
      })
    })

    describe('.extend', () => {
      context('with function only', () => {
        it('stores function in extensions array with undefined path', () => {
          let func = sinon.spy()
          improv.extend(func)
          improv.extensions.should.eql([{ 'function': func, path: void 0 }])
        })
      })
      context('with function and path', () => {
        it('stores function in extensions array with undefined path', () => {
          let func = sinon.spy()
          improv.extend(func, 'a.path')
          improv.extensions.should.eql([{ 'function': func, path: 'a.path' }])
        })
      })
    })

    describe('.remember', () => {
      it('stores data at key in data', () => {
        improv.data.site = { name: 'Hub' }
        improv.remember('site', { lang: 'en' })
        improv.data.should.eql({ site: { lang: 'en' } })
      })
      it('stores data at path in data', () => {
        improv.data.site = { name: 'Hub' }
        improv.remember('site.lang', 'en')
        improv.data.should.eql({ site: { name: 'Hub', lang: 'en' } })
      })
    })

    describe('.rememberForUser', () => {
      it('stores data at path with user ID', () => {
        let uid = pretend.lastListen().message.user.id
        improv.data.site = { name: 'Hub' }
        improv.rememberForUser(uid, 'site.nickname', 'Hubby')
        improv.userData.should.eql({ [uid]: { site: { nickname: 'Hubby' } } })
      })
    })

    describe('.forget', () => {
      it('removes data at path', () => {
        improv.data.site = { name: 'Hub', lang: 'en' }
        improv.remember('site.lang', 'en')
        improv.data.should.eql({ site: { name: 'Hub', lang: 'en' } })
      })
    })

    describe('.forgetForUser', () => {
      it('forgets user data at path for user ID', () => {
        let uid = pretend.lastListen().message.user.id
        improv.userData = { [uid]: { site: { nickname: 'Hubby' } } }
        improv.forgetForUser(uid, 'site.nickname')
        improv.userData.should.eql({ [uid]: { site: {} } })
      })
    })

    describe('.mergeData', () => {
      context('with data passed as option', () => {
        it('merges data with given context', () => {
          improv.data.site = { name: 'Hub' }
          improv.mergeData({ user: pretend.lastListen().message.user })
          .should.eql({
            user: pretend.lastListen().message.user,
            site: { name: 'Hub' }
          })
        })
        it('makes user from res in context available', () => {
          improv.data.site = { name: 'Hub' }
          improv.mergeData({ response: pretend.lastListen() })
          .should.eql({
            response: pretend.lastListen(),
            user: pretend.lastListen().message.user,
            site: { name: 'Hub' }
          })
        })
        it('merges data with remembered user data in context', () => {
          let uid = pretend.lastListen().message.user.id
          improv.data.site = { name: 'Hub' }
          improv.userData = { [uid]: { site: { nickname: 'Hubby' } } }
          improv.mergeData({ response: pretend.lastListen() })
            .should.eql({
              response: pretend.lastListen(),
              user: pretend.lastListen().message.user,
              site: { name: 'Hub', nickname: 'Hubby' }
            })
        })
        it('does not merge remembered user data without context', () => {
          let uid = pretend.lastListen().message.user.id
          improv.data.site = { name: 'Hub' }
          improv.userData = { [uid]: { site: { nickname: 'Hubby' } } }
          improv.mergeData().should.eql({ site: { name: 'Hub' } })
        })
      })

      context('with data loaded from brain', () => {
        it('merges data with user data', () => {
          improv.configure({ save: true })
          pretend.robot.brain.set('improv', { site: { owner: 'Hubot' } })
          improv.data.site = { name: 'Hub' }
          improv.mergeData({ user: pretend.lastListen().message.user })
          .should.eql({
            user: pretend.lastListen().message.user,
            site: { owner: 'Hubot', name: 'Hub' }
          })
        })
      })

      context('with extension functions added', () => {
        it('merges data with results of functions', () => {
          improv
            .extend(() => { return { custom1: 'foo' } })
            .extend(() => { return { custom2: 'bar' } })
            .mergeData({ user: pretend.lastListen().message.user })
            .should.eql({
              user: pretend.lastListen().message.user,
              custom1: 'foo',
              custom2: 'bar'
            })
        })
        it('deep merges existing data with extensions', () => {
          improv
            .extend(() => { return { user: { type: 'human' } } })
            .mergeData({ user: { name: 'frendo' } })
            .should.eql({ user: { name: 'frendo', type: 'human' } })
        })
      })
      context('with paths argument matching extension', () => {
        it('merges extension with existing data', () => {
          let func = () => { return { test: { foo: 'bar' } } }
          improv
            .extend(func, 'test.foo')
            .mergeData({ test: { baz: 'qux' } }, ['test.foo'])
            .should.eql({ test: { foo: 'bar', baz: 'qux' } })
        })
      })
      context('with paths partially matching extension', () => {
        it('merges extension with existing data', () => {
          let func = () => { return { test: { foo: 'bar' } } }
          improv
            .extend(func, 'test.foo')
            .mergeData({ test: { baz: 'qux' } }, ['test'])
            .should.eql({ test: { foo: 'bar', baz: 'qux' } })
        })
      })
      context('with paths that don\'t match extension', () => {
        it('returns extension data only', () => {
          let func = () => { return { test: { foo: 'bar' } } }
          improv
            .extend(func, 'test.foo')
            .mergeData({ test: { baz: 'qux' } }, ['something.else'])
            .should.eql({ test: { baz: 'qux' } })
        })
      })
    })

    describe('.parse', () => {
      context('with data', () => {
        it('populates message template with data at path', () => {
          improv.data = { site: 'The Hub' }
          improv
            .parse({ strings: ['welcome to ${ this.site }'] })
            .should.eql(['welcome to The Hub'])
        })
      })
      context('without data', () => {
        it('uses fallback value', () => {
          let string = 'hey ${this.user.name}, pay ${this.product.price}'
          improv
            .parse({ strings: [string] })
            .should.eql(['hey unknown, pay unknown'])
        })
      })
      context('with partial data', () => {
        it('uses fallback for unknowns', () => {
          let string = 'hey ${ this.user.name }, pay ${ this.product.price }'
          improv.data = { product: { price: '$55' } }
          improv
            .parse({ strings: [string] })
            .should.eql(['hey unknown, pay $55'])
        })
        it('replaces entire string as configured', () => {
          let string = 'hey ${this.user.name}, pay ${this.product.price}'
          improv.configure({ replacement: '¯\\_(ツ)_/¯' })
          improv.data = { product: { price: '$55' } }
          improv
            .parse({ strings: [string] })
            .should.eql(['¯\\_(ツ)_/¯'])
        })
      })
    })

    describe('.middleware', () => {
      context('with series of hubot sends', () => {
        it('rendered messages with data', async () => {
          improv.data.site = { name: 'The Hub' }
          await pretend.lastListen().send('hello you')
          await pretend.lastListen().send('hi ${ this.user.name }')
          pretend.messages.should.eql([
            ['testing', 'tester', 'test'],
            ['testing', 'hubot', 'hello you'],
            ['testing', 'hubot', 'hi tester']
          ])
        })
      })
      context('with multiple strings', () => {
        it('renders each message with data', async () => {
          improv.data.site = { name: 'The Hub' }
          await pretend.lastListen().send(
            'testing',
            'hi ${ this.user.name }',
            'welcome to ${ this.site.name }'
          )
          pretend.messages.should.eql([
            ['testing', 'tester', 'test'],
            ['testing', 'hubot', 'testing'],
            ['testing', 'hubot', 'hi tester'],
            ['testing', 'hubot', 'welcome to The Hub']
          ])
        })

        it('renders messages with remembered user data', async () => {
          pretend.robot.hear(/remember i like (.*)/, (res) => {
            improv.rememberForUser(res.message.user.id, 'fav', res.match[1])
          })
          await pretend.user('blueboi').send('remember i like blue')
          await pretend.lastListen().send('i know you like ${this.fav}')
          pretend.messages.should.eql([
            ['testing', 'tester', 'test'],
            ['blueboi', 'remember i like blue'],
            ['hubot', 'i know you like blue']
          ])
        })

        it('does not confuse user memory in succession', async () => {
          pretend.robot.hear(/remember i like (.*)/, (res) => {
            improv.rememberForUser(res.message.user.id, 'fav', res.match[1])
          })
          await pretend.user('blueboi').send('remember i like blue')
          let blueres = pretend.lastListen()
          await pretend.user('redkid').send('remember i like red')
          let redres = pretend.lastListen()
          await blueres.reply('i know you like ${this.fav}')
          await redres.reply('i know you like ${this.fav}')
          pretend.messages.should.eql([
            ['testing', 'tester', 'test'],
            ['blueboi', 'remember i like blue'],
            ['redkid', 'remember i like red'],
            ['hubot', '@blueboi i know you like blue'],
            ['hubot', '@redkid i know you like red']
          ])
        })
      })
    })
  })
})
