# frozen_string_literal: true

require_relative 'base'

module Engine
  module Step
    class Dividend < Base
      ACTIONS = %w[dividend].freeze

      def actions(_entity)
        return [] unless @round.routes

        ACTIONS
      end

      def process_dividend(_action)
        pass!
      end
    end
  end
end