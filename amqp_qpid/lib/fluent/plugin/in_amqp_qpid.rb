# TODO aconway 2015-11-24: copyright

# FIXME aconway 2015-11-24:
# - error handling: bad config, bad url, connection failures etc.
# - security support: SSL, SASL?

# FIXME aconway 2015-11-25: the GVL is locked during the process call so reactor
# is busy-looping with timeout 0 which is burning CPU. Need to fix this.

require 'qpid_proton'

module Fluent
  class AMQPInput < Input
    NAME = 'amqp_qpid'
    Fluent::Plugin.register_input(NAME, self)

    config_param :tag, :string, :default => NAME
    config_param :url, :string, :default => "amqp://guest:guest@localhost:5672/fluent"

    class Handler < Qpid::Proton::Handler::MessagingHandler
      def initialize(id, url, tag)
        super()
        @container = Qpid::Proton::Reactor::Container.new([self])
        @container.container_id = id if id
        @tag = tag
        @url = url

        @lock = Mutex.new
        @running = true
      end

      def on_start(event)
        @receiver = event.container.create_receiver(@url)
      end

      def on_message(event)
        m = event.message
        tag = (m.address and m.address.size > 0) ? "#{@tag}.#{m.address}" : @tag
        Engine.emit(tag, Time.new.to_i, m.body)
      end

      def run
        @container.start
        while @lock.synchronize { @running }
          @container.process
        end
        @receiver.connection.close
        @container.process      # Process final connection close events.
      ensure
        @container.stop
      end

      def shutdown
        @lock.synchronize {
          @running = false
          @container.wakeup
        }
      end
    end

    def configure(conf)
      super
      raise ConfigError, "'url' must be specified" unless @url
    end

    def start
      @handler = Handler.new plugin_id, @url, @tag
      @thread = Thread.new { @handler.run }
    end

    def shutdown
      @handler.shutdown
      @thread.join
      super
    end

  end # class AMQPInput
end
