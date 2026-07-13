# frozen_string_literal: true

require 'uri'

module LetMeSendEmail
  module Resources
    # Shared resource URL and pagination behavior.
    class Base
      # @param client [Client]
      def initialize(client)
        @client = client
      end

      private

      def path_for(collection, id)
        "/#{collection}/#{@client.resource_path_segment(id)}"
      end

      def list_path(collection, per_page:, after:, before:)
        raise ArgumentError, 'after and before cannot be used together' if after && before

        params = {}
        params[:per_page] = per_page unless per_page.nil?
        params[:after] = after unless after.nil?
        params[:before] = before unless before.nil?
        params.empty? ? "/#{collection}" : "/#{collection}?#{URI.encode_www_form(params)}"
      end
    end
  end
end
