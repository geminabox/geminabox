# frozen_string_literal: true

require 'nesty'
module Geminabox
  class GemStoreError < StandardError
    attr_reader :code, :reason

    include Nesty::NestedError

    def initialize(code, reason)
      @code = code
      @reason = reason
    end
  end
end
