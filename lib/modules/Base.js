// Generated by CoffeeScript 1.12.5
(function() {
  var Base, _,
    slice = [].slice;

  _ = require('lodash');


  /**
   * Base class inherited by modules for consistent structure and common behaviour
   * Inherits EventEmitter so all modules can emit events.
   * @param  {String} name  - The module/class name
   * @param  {Robot} robot  - Robot instance
   */

  Base = (function() {
    function Base(name, robot, options) {
      this.name = name;
      this.robot = robot;
      if (options == null) {
        options = {};
      }
      if (!_.isString(this.name)) {
        this.error('Module requires a name');
      }
      if (!_.isObject(this.robot)) {
        this.error('Module requires a robot object');
      }
      this.log = this.robot.logger;
      this.config = _.defaults(options, this.defaults);
      this.id = _.uniqueId();
    }


    /**
     * Generic error handling, logs and emits event before throwing
     * @param  {String} [err] - Description of error (optional)
     * @param  {Error} [err]  - Error instance (optional)
     */

    Base.prototype.error = function(err) {
      var text;
      if (_.isString(err)) {
        text = (this.id || 'constructor') + ": " + err;
        err = new Error(text);
      }
      if (this.robot != null) {
        this.robot.emit('error', err);
      }
      throw err;
    };


    /**
     * Emit events using robot's event emmitter, allows listening from any module
     * Prepends instance's unique ID, so event listens can be implicitly targeted
     * @param  {String} event   Name of event
     * @param  {Mixed} args...  Arguments passed to event
     */

    Base.prototype.emit = function() {
      var args, event, ref;
      event = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      (ref = this.robot).emit.apply(ref, [event, this].concat(slice.call(args)));
    };


    /**
     * Fire callback on robot events if event's ID arguement matches this instance
     * @param  {String}   event    Name of event
     * @param  {Function} callback Function to call
     */

    Base.prototype.on = function(event, callback) {
      this.robot.on(event, (function(_this) {
        return function() {
          var args, instance;
          instance = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
          if (instance === _this) {
            return callback.apply(null, [instance].concat(slice.call(args)));
          }
        };
      })(this));
    };

    return Base;

  })();

  module.exports = Base;

}).call(this);