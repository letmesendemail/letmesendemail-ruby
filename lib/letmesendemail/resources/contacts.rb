# frozen_string_literal: true

module LetMeSendEmail
  module Resources
    # Contacts API operations.
    class Contacts < Base
      # Creates a contact.
      # @return [Models::Model]
      def create(email:, first_name: nil, last_name: nil, phone: nil,
                 is_globally_unsubscribed: nil, categories: nil, email_topics: nil)
        body = { email: email }
        body[:first_name] = first_name if first_name
        body[:last_name] = last_name if last_name
        body[:phone] = phone if phone
        body[:is_globally_unsubscribed] = is_globally_unsubscribed unless is_globally_unsubscribed.nil?
        body[:categories] = categories if categories
        body[:email_topics] = email_topics if email_topics
        @client.request(:post, '/contacts', body: body)
      end

      # Lists one cursor page of contacts.
      # @return [Models::Model]
      def list(per_page: nil, after: nil, before: nil)
        @client.request(:get, list_path('contacts', per_page: per_page, after: after, before: before))
      end

      # Retrieves a contact.
      # @param id [String]
      # @return [Models::Model]
      def get(id)
        @client.request(:get, path_for('contacts', id))
      end

      # Updates a contact.
      # @param id [String]
      # @return [Models::Model]
      def update(id, first_name: nil, last_name: nil, phone: nil,
                 is_globally_unsubscribed: nil, categories: nil, email_topics: nil,
                 sync_categories: nil, sync_email_topics: nil)
        body = {}
        body[:first_name] = first_name if first_name
        body[:last_name] = last_name if last_name
        body[:phone] = phone if phone
        body[:is_globally_unsubscribed] = is_globally_unsubscribed unless is_globally_unsubscribed.nil?
        body[:categories] = categories if categories
        body[:email_topics] = email_topics if email_topics
        body[:sync_categories] = sync_categories unless sync_categories.nil?
        body[:sync_email_topics] = sync_email_topics unless sync_email_topics.nil?
        @client.request(:put, path_for('contacts', id), body: body)
      end

      # Deletes a contact.
      # @param id [String]
      # @return [Models::Model]
      def delete(id)
        @client.request(:delete, path_for('contacts', id))
      end
    end
  end
end
