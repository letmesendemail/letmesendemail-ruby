# frozen_string_literal: true

module LetMeSendEmail
  module Resources
    # Emails API operations.
    class Emails < Base
      # Sends a regular email.
      # @return [Models::Model]
      def send(from:, to:, subject:, html: nil, text: nil, type: nil,
               event_name: nil, email_topic_id: nil, reply_to: nil,
               cc: nil, bcc: nil, headers: nil, attachments: nil,
               idempotency_key: nil)
        body = { from: from, to: to, subject: subject }
        body[:html] = html if html
        body[:text] = text if text
        body[:type] = type if type
        body[:event_name] = event_name if event_name
        body[:email_topic_id] = email_topic_id if email_topic_id
        body[:reply_to] = reply_to if reply_to
        body[:cc] = cc if cc
        body[:bcc] = bcc if bcc
        body[:headers] = headers if headers
        body[:attachments] = attachments if attachments

        extra = idempotency_key ? { 'Idempotency-Key' => idempotency_key } : {}

        @client.request(:post, '/emails', body: body, extra_headers: extra)
      end

      # Sends an email using a template.
      # @return [Models::Model]
      def send_with_template(from:, to:, template_id:, subject: nil,
                             template_variables: nil, type: nil,
                             event_name: nil, email_topic_id: nil,
                             reply_to: nil, cc: nil, bcc: nil,
                             headers: nil, attachments: nil,
                             idempotency_key: nil)
        body = { from: from, to: to, template_id: template_id }
        body[:subject] = subject if subject
        body[:template_variables] = template_variables if template_variables
        body[:type] = type if type
        body[:event_name] = event_name if event_name
        body[:email_topic_id] = email_topic_id if email_topic_id
        body[:reply_to] = reply_to if reply_to
        body[:cc] = cc if cc
        body[:bcc] = bcc if bcc
        body[:headers] = headers if headers
        body[:attachments] = attachments if attachments

        extra = idempotency_key ? { 'Idempotency-Key' => idempotency_key } : {}

        @client.request(:post, '/emails', body: body, extra_headers: extra)
      end

      # Verifies an email address.
      # @param email [String]
      # @return [Models::Model]
      def verify(email)
        @client.request(:post, '/emails/verify', body: { email: email })
      end

      # Lists one cursor page of emails.
      # @return [Models::Model]
      def list(per_page: nil, after: nil, before: nil)
        @client.request(:get, list_path('emails', per_page: per_page, after: after, before: before))
      end

      # Retrieves detailed information for an email.
      # @param id [String]
      # @return [Models::Model]
      def get(id)
        @client.request(:get, path_for('emails', id))
      end
    end
  end
end
