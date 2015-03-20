module Slop
  class Option
    DEFAULT_CONFIG = {
      help: true
    }

    # An Array of flags this option matches.
    attr_reader :flags

    # A custom description used for the help text.
    attr_reader :desc

    # A Hash of configuration options.
    attr_reader :config

    # An Integer count for the total times this option
    # has been executed.
    attr_reader :count

    # A custom proc that yields the option value when
    # it's executed.
    attr_reader :block

    # The end value for this option.
    attr_writer :value

    def initialize(flags, desc, **config, &block)
      @flags  = flags
      @desc   = desc
      @config = DEFAULT_CONFIG.merge(config)
      @block  = block
      reset
    end

    # Reset the option count and value. Used when calling .reset
    # on the Parser.
    def reset
      @value = nil
      @count = 0
    end

    # Since `call()` can be used/overriden in subclasses, this
    # method is used to do general tasks like increment count. This
    # ensures you don't *have* to call `super` when overriding `call()`.
    # It's used in the Parser.
    def ensure_call(value)
      @count += 1

      if value.nil? && expects_argument? && !suppress_errors?
        raise Slop::MissingArgument, "missing argument for #{flag}"
      end

      @value = call(value)
      block.call(@value) if block.respond_to?(:call)
    end

    # This method is called immediately when an option is found.
    # Override it in sub-classes.
    def call(_value)
      raise NotImplementedError,
        "you must override the `call' method for option #{self.class}"
    end

    # By default this method does nothing. It's called when all options
    # have been parsed and allows you to mutate the `@value` attribute
    # according to other options.
    def finish(_result)
    end

    # Override this if this option type does not expect an argument
    # (i.e a boolean option type).
    def expects_argument?
      true
    end

    # Override this if you want to ignore the return value for an option
    # (i.e so Result#to_hash does not include it).
    def null?
      false
    end

    # Returns the value for this option. Falls back to the default (or nil).
    def value
      @value || default_value
    end

    # Returns the default value for this option (default is nil).
    def default_value
      config[:default]
    end

    # Returns true if we should ignore errors that cause exceptions to be raised.
    def suppress_errors?
      config[:suppress_errors]
    end

    # Returns all flags joined by a comma. Used by the help string.
    def flag
      flags.join(", ")
    end

    # Returns the last key as a symbol. Used in Options.to_hash.
    def key
      (config[:key] || flags.last.sub(/\A--?/, '')).to_sym
    end

    # Returns true if this option should be displayed in help text.
    def help?
      config[:help]
    end

    # Returns the help text for this option (flags and description).
    def to_s(offset: 0)
      "%-#{offset}s  %s" % [flag, desc]
    end
  end
end
