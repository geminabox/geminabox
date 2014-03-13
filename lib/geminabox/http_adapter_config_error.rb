module Geminabox
  class HttpAdapterConfigError < StandardError
    def initialize(method_name, returns)
      super("#{method_name} must be defined, and return #{returns}")
    end
  end
end
