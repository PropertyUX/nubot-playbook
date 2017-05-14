_ = require 'lodash'
Base = require './Base'

_.mixin 'hasKeys': (obj, keys) ->
  0 is _.size _.difference keys, _.keys obj

_.mixin 'pickHas': (obj, pickKeys) ->
  _.omitBy _.pick(obj, pickKeys), _.isUndefined

###*
 * Keep a record of configured events and emmitted data. Can record any events
 * emitted by the robot or just those originating from a given instance
 * Config keys:
 * - events: array of event names to record
 * - responseAtts: Hubot Response attribute keys to add to record
 * - instanceAtts: as above, for Playbook module instance attributes
 * @param {Robot}  robot     - Hubot Robot instance
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Transcript extends Base
  constructor: (args...) ->
    @defaults =
      save: true
      events: ['match', 'mismatch', 'catch', 'send']
      instanceAtts: ['name', 'key', 'id' ]
      responseAtts: ['match']
      messageAtts: ['user.id', 'user.name', 'room', 'text']

    super 'transcript', args...
    _.castArray @config.instanceAtts if @config.instanceAtts?
    _.castArray @config.responseAtts if @config.responseAtts?
    _.castArray @config.messageAtts if @config.messageAtts?

    if @config.save
      @robot.brain.set 'transcripts', [] unless @robot.brain.get 'transcripts'
      @records = @robot.brain.get 'transcripts'
    @records ?= []

  ###*
   * Record given event in records array, save to hubot brain if configured
   * Events emitted by Playbook always include module instance as first param
   * @param  {String} event   - The event name
   * @param  {Mixed} args...  - Args passed with the event, usually consists of:
   *                            - Playbook module instance
   *                            - Hubot response object
   *                            - other additional (special context) arguments
  ###
  recordEvent: (event, args...) ->
    instance = args.shift() if _.hasKeys args[0], ['name', 'id', 'config']
    response = args.shift() if _.hasKeys args[0], ['robot', 'message']
    record = time: _.now(), event: event
    record.key = @key if @key?

    if instance? and @config.instanceAtts?
      record.instance = _.pickHas instance, @config.instanceAtts
    if response? and @config.responseAtts?
      record.response = _.pickHas response, @config.responseAtts
    if response? and @config.messageAtts?
      record.message = _.pickHas response.message, @config.messageAtts

    record.other = args unless _.isEmpty args

    @records.push record
    @emit 'record', record
    return

  ###*
   * Record events emitted by all Playbook modules and/or the robot itself
   * (still only applies to configured event types)
  ###
  recordAll: ->
    _.each _.castArray(@config.events), (event) =>
      @robot.on event, (args...) => @recordEvent event, args...
    return

  ###*
   * Record events emitted by a given dialogue
   * @param  {Dialogue} dialogue - The Dialogue instance
  ###
  recordDialogue: (dialogue) ->
    _.each _.castArray(@config.events), (event) =>
      dialogue.on event, (args...) => @recordEvent event, args...
    return

  ###*
   * Record events emitted by a given scene and any dialogue it enters
   * Records all events fromn the scene but only configured events from dialogue
   * @param  {Scene} scene - The Scnee instance
  ###
  recordScene: (scene) ->
    scene.on 'enter', (scene, res, dialogue) =>
      @recordEvent 'enter', scene, res
      @recordDialogue dialogue
    scene.on 'exit', (scene, res, reason) =>
      @recordEvent 'exit', scene, res, reason
    return

  ###*
   * Record denial events emitted by a given director
   * Ignores configured events because director has distinct events
   * @param  {Director} scene - The Director instance
  ###
  recordDirector: (director) ->
    director.on 'allow', (args...) =>
      @recordEvent 'allow', args...
    director.on 'deny', (args...) =>
      @recordEvent 'deny', args...
    return

  ###*
   * Filter records matching a subset, e.g. user name or instance key
   # Optionally return the whole record or values for a given key
   * @param  {Object} subsetMatch  - Key/s:value/s to match (accepts path key)
   * @param  {String} [returnPath] - Key or path within record to return
   * @return {Array}               - Whole records or selected values found
  ###
  findRecords: (subsetMatch, returnPath) ->
    found = _.filter @records, subsetMatch
    return found unless returnPath?
    return _.map found, (record) -> _.head _.at record, returnPath

module.exports = Transcript
