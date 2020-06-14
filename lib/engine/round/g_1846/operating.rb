# frozen_string_literal: true

require_relative '../operating'

module Engine
  module Round
    module G1846
      class Operating < Operating
        MINOR_STEPS = %i[
          token_or_track
          route
          dividend
        ].freeze

        STEPS = %i[
          issue
          token_or_track
          route
          dividend
          train
          company
        ].freeze

        STEP_DESCRIPTION = {
          issue: 'Issue or Redeem Shares',
          token_or_track: 'Place a Token or Lay Track',
          route: 'Run Routes',
          dividend: 'Pay or Withhold Dividends',
          train: 'Buy Trains',
          company: 'Purchase Companies',
        }.freeze

        SHORT_STEP_DESCRIPTION = {
          issue: 'Issue/Redeem',
          token_or_track: 'Token/Track',
          route: 'Routes',
          train: 'Train',
          company: 'Company',
        }.freeze

        def select(entities)
          minors, corporations = entities.partition(&:minor?)
          minors + corporations.select(&:floated?).sort
        end

        def steps
          @current_entity.minor? ? self.class::MINOR_STEPS : self.class::STEPS
        end

        def can_lay_track?
          @step == :token_or_track && !skip_track
        end

        def can_place_token?
          @step == :token_or_track && !skip_token
        end

        def issuable_shares
          num_shares = @current_entity.num_player_shares - @current_entity.num_market_shares
          bundles = @current_entity.bundles_for_corporation(@current_entity)
          share_price = @game.stock_market.find_share_price(@current_entity, :left).price

          bundles
            .each { |bundle| bundle.share_price = share_price }
            .reject { |bundle| bundle.num_shares > num_shares }
        end

        def redeemable_shares
          share_price = @game.stock_market.find_share_price(@current_entity, :right).price

          @game
            .share_pool
            .bundles_for_corporation(@current_entity)
            .each { |bundle| bundle.share_price = share_price }
            .reject { |bundle| @current_entity.cash < bundle.price }
        end

        private

        def ignore_action?(action)
          return false if action.is_a?(Action::SellShares) && action.entity.corporation?

          case action
          when Action::PlaceToken, Action::LayTile
            return true if !skip_token || !skip_track
          end

          super
        end

        def count_actions(type)
          @current_actions.count { |action| action.is_a?(type) }
        end

        def skip_token
          return true if count_actions(Action::PlaceToken).positive?

          super
        end

        def skip_track
          @current_entity.cash < @game.class::TILE_COST || count_actions(Action::LayTile) > 1
        end

        def skip_issue
          issuable_shares.empty? && redeemable_shares.empty?
        end

        def skip_dividend
          return super if @current_entity.corporation?

          revenue = @current_routes.sum(&:revenue)
          process_dividend(Action::Dividend.new(
            @current_entity,
            kind: revenue.positive? ? 'payout' : 'withhold',
          ))
          true
        end

        def skip_token_or_track
          skip_track && skip_token
        end

        def process_sell_shares(action)
          return super if action.entity.player?

          @game.share_pool.sell_shares(action.bundle)
        end

        def process_buy_shares(action)
          @game.share_pool.buy_shares(@current_entity, action.bundle)
        end

        def tile_cost(tile, abilities)
          [@game.class::TILE_COST, tile.upgrade_cost(abilities)].max
        end

        def payout(revenue)
          return super if @current_entity.corporation?

          @log << "#{@current_entity.name} pays out #{@game.format_currency(revenue)}"

          amount = revenue / 2

          [@current_entity, @current_entity.owner].each do |entity|
            @log << "#{entity.name} receives #{@game.format_currency(amount)}"
            @bank.spend(amount, entity)
          end
        end
      end
    end
  end
end