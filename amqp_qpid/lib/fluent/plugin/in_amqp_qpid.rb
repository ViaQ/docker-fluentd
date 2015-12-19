# TODO aconway 2015-12-10: copyright

require 'qpid_proton'
# TODO: the stuff in qpid_proton_extra will be part of qpid_proton in a future release.
require_relative './qpid_proton_extra'

module Fluent
  class AMQPInput < Input
    NAME = 'amqp_qpid'
    Plugin.register_input(NAME, self)

    def initialize
      super
      require 'fluent/parser'
    end

    config_param :url, :string
    config_param :tag, :string
    config_param :reconnect_min, :float, :default => 0.1
    config_param :reconnect_max, :float, :default => 3
    desc 'The format of the payload.'
    config_param :format, :string

    def configure(conf)
      super
      raise ConfigError, "#{NAME}: 'tag' is required" unless @tag
      raise ConfigError, "#{NAME}: 'url' is required" unless @url
      begin
        @url = Qpid::Proton::URL.new @url
      rescue Exception => e
        raise ConfigError, "#{NAME}: 'url' is invalid: #{e}"
      end
      @backoff = Qpid::Proton::Reactor::Backoff.new @reconnect_min, @reconnect_max
      @parser = Plugin.new_parser(@format)
      @parser.configure(conf)
    end

    def start
      super
      log.debug "#{NAME}: connecting on #{@url}"
      @thread = Thread.new do
        while !@stop
          begin
            s = TCPSocket.new @url.host, @url.port
            h = Handler.new plugin_id, @url, @tag, @parser, @router
            @driver = Qpid::Proton::ConnectionDriver.new(s, h)
            @driver.run
          rescue => e
          end
          sleep @backoff.next
        end
      end
    end

    def shutdown
      super
      @stop = true
      @driver.io.close
      @thread.join
    rescue
    end

    class Handler < Qpid::Proton::Handler::MessagingHandler

      def initialize(id, url, tag, parser, router)
        super()
        @id, @url, @tag, @parser, @router = id, url, tag, parser, router
      end

      attr_reader :engine

      def on_start event
        event.connection.container = @id
        event.connection.open   # Open as client.
        @receiver = event.connection.open_session().open_receiver(@url.path)
      end

      def on_message event
        m = event.message
        tag = (m.address and m.address.size > 0) ? "#{@tag}.#{m.address}" : @tag
        @parser.parse(m.body) { |time, record|
          @router.emit(tag, time, record)
        }
      end

      def on_disconnect event
        puts "FIMXE #{NAME}: disconnected, re-connecting"
      end
    end
  end
end

