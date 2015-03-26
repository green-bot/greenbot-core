require 'test_helper'

module Slop
  class ReverseEverythingOption < BoolOption
    def finish(result)
      result.used_options.grep(Slop::StringOption).each do |opt|
        opt.value = opt.value.reverse
      end
    end
  end
end

describe Slop::Result do
  before do
    @options = Slop::Options.new
    @verbose = @options.bool "-v", "--verbose"
    @name    = @options.string "--name"
    @unused  = @options.string "--unused"
    @result  = @options.parse %w(foo -v --name lee argument)
  end

  it "increments option count" do
    # test this here so it's more "full stack"
    assert_equal 1, @verbose.count
    @result.parser.reset.parse %w(-v --verbose)
    assert_equal 2, @verbose.count
  end

  it "handles default values" do
    @options.string("--foo", default: "bar")
    @result.parser.reset.parse %w()
    assert_equal "bar", @result[:foo]
  end

  it "handles custom finishing" do
    @options.string "--foo"
    @options.reverse_everything "-r"
    @result.parser.reset.parse %w(-r --name lee --foo bar)
    assert_equal %w(eel rab), @result.to_hash.values_at(:name, :foo)
  end

  it "yields arguments to option blocks" do
    output = nil
    @options.string("--foo") { |v| output = v }
    @result.parser.reset.parse %w(--foo bar)
    assert_equal output, "bar"
  end

  describe "#[]" do
    it "returns an options value" do
      assert_equal "lee", @result["name"]
      assert_equal "lee", @result[:name]
      assert_equal "lee", @result["--name"]
    end
  end

  describe "#method_missing" do
    it "checks if options have been used" do
      assert_equal true, @result.verbose?
      assert_equal false, @result.unused?
    end
  end

  describe "#option" do
    it "returns an option by flag" do
      assert_equal @verbose, @result.option("--verbose")
      assert_equal @verbose, @result.option("-v")
    end

    it "ignores prefixed hyphens" do
      assert_equal @verbose, @result.option("verbose")
      assert_equal @verbose, @result.option("-v")
    end

    it "returns nil if nothing is found" do
      assert_equal nil, @result.option("foo")
    end
  end

  describe "#to_hash" do
    it "returns option keys and values" do
      assert_equal({ verbose: true, name: "lee", unused: nil }, @result.to_hash)
    end
  end
end
