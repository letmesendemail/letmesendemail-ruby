# frozen_string_literal: true

module LetMeSendEmail
  module Resources
    # Contact Categories API operations.
    class ContactCategories < Base
      # Creates a contact category.
      # @return [Models::Model]
      def create(name:, slug: nil)
        body = { name: name }
        body[:slug] = slug if slug
        @client.request(:post, '/contact-categories', body: body)
      end

      # Lists one cursor page of contact categories.
      # @return [Models::Model]
      def list(per_page: nil, after: nil, before: nil)
        @client.request(:get, list_path('contact-categories', per_page: per_page, after: after, before: before))
      end

      # Retrieves a contact category.
      # @param id [String]
      # @return [Models::Model]
      def get(id)
        @client.request(:get, path_for('contact-categories', id))
      end

      # Updates a contact category.
      # @param id [String]
      # @return [Models::Model]
      def update(id, name:, slug: nil)
        body = { name: name }
        body[:slug] = slug if slug
        @client.request(:put, path_for('contact-categories', id), body: body)
      end

      # Deletes a contact category.
      # @param id [String]
      # @return [Models::Model]
      def delete(id)
        @client.request(:delete, path_for('contact-categories', id))
      end
    end
  end
end
