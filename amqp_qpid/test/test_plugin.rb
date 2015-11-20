# FIXME aconway 2015-11-25:
#
# Use Fluent::Test::InputTestDriver, don't start fluentd exe from tests.
# Pick random port for testing AMQP connections.

require 'test/unit'
require 'qpid_proton'

DIR=File.dirname(__FILE__)
LIB_DIR=File.expand_path(File.join(DIR, '..', 'lib'))
PLUGIN_DIR=File.join(LIB_DIR, 'fluent', 'plugin')
CONFIG_FILE=File.expand_path(File.join(DIR, "fluent.conf"))

$LOAD_PATH.unshift(LIB_DIR)
$LOAD_PATH.unshift(File.dirname(__FILE__))

class FluentdTest
  def initialize
    # FIXME aconway 2015-11-25: starting fluentd executable, requires PATH etc. set up"
    @out = IO.popen("fluentd -p #{PLUGIN_DIR} -c #{CONFIG_FILE} -q")
  end

  attr_reader :out

  def stop
    Process.kill :TERM, @out.pid
    Process.wait @out.pid
    puts @out.read
  end
end

class TestFoo < Test::Unit::TestCase

  class SendServer < Qpid::Proton::Handler::MessagingHandler

    def initialize(test, url)
      super()
      @url = url
      @test = test
      @container = Qpid::Proton::Reactor::Container.new(self)
      @container.container_id = "test"
      @container.start
    end

    attr_reader :container, :acceptor, :sender

    def on_start(event)
      @acceptor = @container.listen(@url)
    end

    def on_link_opening(event)
      @test.assert_nil @sender
      @sender = event.sender
    end

    def on_settled(event)
      @settled = true
    end

    def wait
      while @container.process
        return if block_given? and yield
      end
    end

    def send(m)
      @settled = false
      @sender.send m
      wait { @settled }
    end
  end

  def setup
    # FIXME aconway 2015-11-25: random port for tests, need to generate fluent.conf
    @server = SendServer.new(self, "0.0.0.0:5672")
    @server.wait { @server.acceptor }
    @fluentd = FluentdTest.new
    @server.wait { @server.sender }
  end

  def teardown
    @fluentd.stop if @fluentd
  end

  def test_send_amqp
    msg = Qpid::Proton::Message.new
    msg.body = "test_send_amqp"
    @server.send(msg)
    assert_match /[0-9\-: ]+stdout.amqp-test: "test_send_amqp"/, @fluentd.out.readline
    msg.address = "foo"
    msg.body = "test_send_with_addr"
    @server.send(msg)
    assert_match /[0-9\-: ]+stdout.amqp-test.foo: "test_send_with_addr"/, @fluentd.out.readline
  end
end
