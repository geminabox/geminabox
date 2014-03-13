module Geminabox
  class HttpDummy < HttpAdapter

    attr_accessor :default_response

    def get_content(*args)
      default_response
    end

    def get(*args)
      Response.new default_response
    end

    def post(*args)
      Response.new default_response
    end

    def set_auth(*args)
      true
    end

    class Response
      attr_reader :default
      def initialize(default)
        @default = default
      end

      def body
        default
      end

      def status
        default
      end

      def code
        default
      end
    end

  end
end
