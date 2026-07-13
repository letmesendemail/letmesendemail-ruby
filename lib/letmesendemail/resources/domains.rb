# frozen_string_literal: true

module LetMeSendEmail
  module Resources
    # Domains API operations.
    class Domains < Base
      # Lists one cursor page of domains.
      # @return [Models::Model]
      def list(per_page: nil, after: nil, before: nil)
        @client.request(:get, list_path('domains', per_page: per_page, after: after, before: before))
      end

      # Retrieves a domain.
      # @param id [String]
      # @return [Models::Model]
      def get(id)
        @client.request(:get, path_for('domains', id))
      end

      # Requests verification for a domain name.
      # @param domain [String]
      # @return [Models::Model]
      def verify(domain)
        @client.request(:post, '/domains/verify', body: { domain: domain })
      end
    end
  end
end
