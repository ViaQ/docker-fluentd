# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Test the connection engine and driver  extensions to proton
require_relative './helper'
require 'socket'

class TestProtonEngine < Test::Unit::TestCase

  class Handler < Qpid::Proton::Handler::MessagingHandler
    def initialize
      super
      @links = []
      @messages = []
    end

    attr_reader :links, :messages

    def on_link_opening(event)
      @links << event.link
    end

    def on_message(event)
      @messages << event.message
    end
  end

  # Pump two engines in a blocking style. No threads.
  def test_blocking
    s1, s2 = Socket.pair(:UNIX, :STREAM, 0)
    e1 = Qpid::Proton::ConnectionEngine.new(s1, Handler.new)
    e2 = Qpid::Proton::ConnectionEngine.new(s2, Handler.new)

    assert !e1.connection.remote_active?
    assert !e2.connection.remote_active?
    e1.connection.open()
    until e1.connection.remote_active? && e2.connection.remote_active?
      e1.process(); e2.process()
    end
    ss = e1.connection.open_session
    sender = ss.open_sender("FOO")
    until sender.remote_active?
      e1.process(); e2.process()
    end
    receiver = e2.handler.links[0]
    assert_equal "FOO", receiver.remote_target.address
    m = Qpid::Proton::Message.new # TODO aconway 2015-12-03: add body initializer
    m.body = "TEST"
    sender.send m
    until !e2.handler.messages.empty?
      e1.process(); e2.process()
    end
    assert_equal "TEST", e2.handler.messages[0].body
    e1.connection.close()
    until e1.closed? && e2.closed? 
      e1.process(); e2.process()
    end
  end

  # A MessagingHandler with a TCPServer on a dynamic port
  class Server < Qpid::Proton::Handler::MessagingHandler
      def initialize
        super
        @server = TCPServer.new 0
      end

      def port; @server.addr[1] end

      def run
        Qpid::Proton::ConnectionDriver.new(@server.accept, self).run
      end
  end

  def test_server_receive
    receiver_class = Class.new(Server) do
      def on_message event
        @message = event.message
        event.connection.close
      end

      def run
        super
        return @message.body
      end
    end

    receiver = receiver_class.new
    rt = Thread.new { receiver.run }

    sender = Qpid::Proton::ConnectionDriver.new(Socket.tcp(nil, receiver.port)) do |engine|
      engine.connection.open
      m = Qpid::Proton::Message.new
      m.body = "TEST"
      engine.connection.open_session().open_sender("foo").send(m)
    end
    Thread.new { sender.run }.join
    rt.join
    assert_equal "TEST", rt.value
  end

  def test_server_send
    sender_class = Class.new(Server) do
      def on_link_opening event
        m = Qpid::Proton::Message.new
        m.body = "TEST"
        event.sender.send m
      end
    end

    sender = sender_class.new
    st = Thread.new { sender.run }

    receiver = Qpid::Proton::Handler::MessagingHandler.new
    class << receiver
      def on_start event
        event.connection.open
        event.connection.open_session().open_receiver("foo")
      end

      def on_message event
        @message = event.message
        event.connection.close
      end

      attr_reader :message
    end

    driver = Qpid::Proton::ConnectionDriver.new(Socket.tcp(nil, sender.port), receiver)
    Thread.new { driver.run }.join
    assert_equal "TEST", receiver.message.body
  end


  def test_client_close
    server_class = Class.new(Server) do
      def on_connection_closing event
        @closed_ok = true
      end

      attr_reader :closed_ok

      def run
        super
      end
    end

    server = server_class.new
    rt = Thread.new { server.run }
    client = Qpid::Proton::ConnectionDriver.new(Socket.tcp(nil, server.port)) { |engine|
      engine.connection.open
      engine.connection.close
    }
    Thread.new { client.run }.join
    assert server.closed_ok
  end

  def test_client_disconnect
    server_class = Class.new(Server) do
      def on_connection_closing event
        @closed = true
      end
    end

    server = server_class.new
    rt = Thread.new { server.run rescue nil }
    client = Qpid::Proton::ConnectionEngine.new(Socket.tcp(nil, server.port))
    client.connection.open
    client.io.close
  end

end
