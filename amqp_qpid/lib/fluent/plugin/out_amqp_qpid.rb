# FIXME aconway 2015-12-07: copyright.

require 'qpid_proton'
# TODO: the stuff in qpid_proton_extra will be part of qpid_proton in a future release.
require_relative './qpid_proton_extra'

module Fluent
  class AMQPOutput < BufferedOutput
    NAME = 'amqp_qpid'
    Plugin.register_output(NAME, self)

    config_param :url, :string
    config_param :tag_property, :string, :default => "tag"
    config_param :time_property, :string, :default => "time"
    config_param :reconnect_min, :float, :default => 0.1
    config_param :reconnect_max, :float, :default => 3

    def configure conf
      super
      raise ConfigError, "#{NAME}: 'url' is required" unless @url
      begin
        @url = Qpid::Proton::URL.new @url
      rescue Exception => e
        raise ConfigError, "#{NAME}: 'url' is invalid: #{e}"
      end
      @backoff = Qpid::Proton::Reactor::Backoff.new @reconnect_min, @reconnect_max
    end

    def start
      super
      # FIXME aconway 2015-12-09: rework, on-demand
      @thread = Thread.new do
        while !@stop
          begin
            @driver = Qpid::Proton::ConnectionDriver.new(TCPSocket.new(@url.host, @url.port)) { |engine|
              engine.connection.container = plugin_id
              engine.connection.open
              @sender = engine.connection.open_sender(@url.path)
            }
            @driver.run
          rescue => e
          end
          sleep @backoff.next
        end
      end
    end

    def format(tag, time, record)
      # Use msgpack for fluentd internal buffering
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each do |tag, time, record|
        m = Qpid::Proton::Message.new
        m.body = record
        m[@tag_property] = tag
        m[@time_property] = Time.new time
        @driver.synchronize { @sender.send m }
        # FIXME aconway 2015-12-07: settlment for reliable messages.
      end
    end

    def shutdown
      super
      @driver.synchronize { @driver.engine.to_io.close }
      @thread.join
    rescue
    end
  end
end

