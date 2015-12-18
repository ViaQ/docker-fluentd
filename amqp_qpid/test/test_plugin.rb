# TODO aconway 2015-12-10: copyright

require_relative './helper'
require 'socket'

Thread.abort_on_exception = true

# Simple test server.
class Server < Qpid::Proton::Handler::MessagingHandler

  def initialize(test, url)
    super()
    @lock = Mutex.new
    @cond = ConditionVariable.new
    @url = Qpid::Proton::URL.new url
    @test = test
    @messages = Queue.new
    @senderq = Queue.new
    @lock = Mutex.new
    begin
      @listener = TCPServer.new @url.port
    rescue => e
      raise RuntimeError "FIXME: #{e}: Tests use AMQP port 5672. Should use random port."
    end
    @wake = IO.pipe
    @thread = Thread.new { run }
  end

  attr_reader :messages

  def synchronize
    @lock.synchronize { yield }
    @wake[1] << 'x'
  end

  def run
    engines = []
    while true
      rd = [@listener, @wake[0]] + engines.select { |e| e.can_read? }
      wr = engines.select { |e| e.can_write? }
      ready = IO.select(rd, wr, nil, nil)
      if ready[0].find { |io| io == @wake[0] }
        woke = @wake[0].read(1)
        return if woke == 'X'
      end
      if ready[0].find { |io| io == @listener }
        engines << Qpid::Proton::ConnectionEngine.new(@listener.accept, self)
      end
      engines = engines.select { |e| e.process if !e.closed?; !e.closed? }
    end
  ensure
    engines.each do |e|
      e.to_io.close if !e.closed?
      e.process while !e.closed? rescue nil
    end
    @sender = nil
  end

  def stop
    @wake[1] << 'X'
    @thread.join
    @listener.close
  end

  def restart
    @sender = nil
    @wake[1] << 'D'
    @wake[1] << 'X'
    @thread.join
    @thread = Thread.new { run }
  end

  def on_link_opening(event)
    @senderq << event.link if event.link.sender?
  end

  def on_message(event)
    messages << event.message
  end

  def get_sender
    @sender = @senderq.pop unless @sender
    return @sender
  end
end

class TestFluentPlugin < Test::Unit::TestCase

  def setup
    @server = $server
    @sender = $server.get_sender
    @msg = Qpid::Proton::Message.new
  end

  def round_trip data
    @msg.body = data
    @server.synchronize { @sender.send(@msg) }
    m = @server.messages.pop
    assert_equal data, m.body
    m
  end

  def test_send
    # Send body only, round-trip
    m = round_trip "test_send"
    assert_equal "test.amqp", m['tag']
  end

  def test_send_address
    # Send body with address.
    @msg.address = "foo"
    m = round_trip "test_send_address"
    assert_equal "test.amqp.foo", m['tag']
  end

  def test_reconnect
    # Test multiple reconnects
    for i in 1..3
      round_trip "test_reconnect_before"
      @server.restart
      @sender = @server.get_sender
      round_trip "test_reconnect_after"
    end
  end

  def test_presettled
    @msg = Qpid::Proton::Message.new
    @server.synchronize { @sender.send(@msg).settle }
    (1..10).each { |i|
      @msg.body = i
      @server.synchronize { @sender.send(@msg).settle }
    }
    (1..10).each { |i|
      assert_equal i, @server.messages.pop.body
    }
  end

  # FIXME aconway 2015-12-10: test with acknowledgements.
end

begin
  # FIXME aconway 2015-11-25: random port for tests, need to generate fluent.conf
  fluentd = spawn({"RUBYLIB" => $LOAD_PATH.join(":") }, "fluentd -p #{PLUGIN_DIR} -c #{CONFIG_FILE} -q")
  $server = Server.new(self, "0.0.0.0:5672")
  Test::Unit::AutoRunner.run
ensure
  $server.stop
  Process.kill :TERM, fluentd
  Process.wait fluentd
end

