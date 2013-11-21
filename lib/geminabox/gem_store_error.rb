require 'nesty'
module Geminabox
  class GemStoreError < StandardError
    attr_reader :code, :reason

    include Nesty::NestedError

    def initialize(code, reason)
      @code = code.to_s
      @reason = reason
    end
  end
end
