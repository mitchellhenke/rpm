require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper')) 
require 'newrelic_helper'
require 'new_relic/agent/model_fixture'

class NewRelic::Agent::NewrelicHelperTests < Test::Unit::TestCase
  include NewrelicHelper
  
  def params
    {}
  end
  
  def setup
    super
    NewRelic::Agent::ModelFixture.setup
    # setup instrumentation
    NewRelic::Agent.manual_start :test, :test
    # let's get a real stack trace
    begin
      NewRelic::Agent::ModelFixture.find 0
    rescue => e
      @exception = e
      return
    end
    flunk "should throw"
  end
  def teardown
    NewRelic::Agent::ModelFixture.teardown
    NewRelic::Agent.instance.shutdown
    super
  end
  def test_application_caller
    assert_match /setup/, application_caller(@exception.backtrace)
  end
  
  def test_application_stack_trace__rails
    assert_clean(application_stack_trace(@exception.backtrace, true), true)
  end
  def test_application_stack_trace__no_rails
    assert_clean(application_stack_trace(@exception.backtrace, false), false)
  end 
  def test_with_delimiter
    assert_equal "123,456.123456", with_delimiter(123456.123456)
  end
  
  private
  def assert_clean(backtrace, rails=false)
    if !rails
      assert_equal 0, backtrace.grep('/rails/').size, backtrace.grep(/newrelic_rpm/)
    end
    assert_equal 0, backtrace.grep(/trace/).size, backtrace.grep(/trace/)
    assert_equal 0, backtrace.grep(/newrelic_rpm\/lib/).size, backtrace.grep(/newrelic_rpm\/lib/)
  end
end