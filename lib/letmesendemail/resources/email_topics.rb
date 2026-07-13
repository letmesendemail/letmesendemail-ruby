# frozen_string_literal: true

module LetMeSendEmail
  module Resources
    # Email Topics API operations.
    class EmailTopics < Base
      # Creates an email topic.
      # @return [Models::Model]
      def create(name:, slug:, auto_subscribe: nil, public: nil,
                 description: nil, domain_id: nil)
        body = { name: name, slug: slug }
        body[:auto_subscribe] = auto_subscribe unless auto_subscribe.nil?
        body[:public] = public unless public.nil?
        body[:description] = description if description
        body[:domain] = { id: domain_id } if domain_id
        @client.request(:post, '/email-topics', body: body)
      end

      # Lists one cursor page of email topics.
      # @return [Models::Model]
      def list(per_page: nil, after: nil, before: nil)
        @client.request(:get, list_path('email-topics', per_page: per_page, after: after, before: before))
      end

      # Retrieves an email topic.
      # @param id [String]
      # @return [Models::Model]
      def get(id)
        @client.request(:get, path_for('email-topics', id))
      end

      # Updates an email topic.
      # @param id [String]
      # @return [Models::Model]
      def update(id, name: nil, slug: nil, description: nil, public: nil, auto_subscribe: nil)
        body = {}
        body[:name] = name if name
        body[:slug] = slug if slug
        body[:description] = description if description
        body[:public] = public unless public.nil?
        body[:auto_subscribe] = auto_subscribe unless auto_subscribe.nil?
        @client.request(:put, path_for('email-topics', id), body: body)
      end

      # Deletes an email topic.
      # @param id [String]
      # @return [Models::Model]
      def delete(id)
        @client.request(:delete, path_for('email-topics', id))
      end
    end
  end
end
