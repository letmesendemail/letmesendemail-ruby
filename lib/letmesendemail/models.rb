# frozen_string_literal: true

require 'json'

module LetMeSendEmail
  # Plain-data wrappers for API responses.
  module Models
    # Application-friendly representation of an API response.
    #
    # Nested hashes and arrays are recursively wrapped. Use {#to_h} for a
    # defensive plain-data copy suitable for database persistence.
    class Model
      include Enumerable

      # @param attributes [Hash] response attributes
      def initialize(attributes)
        raise ArgumentError, 'attributes must be a Hash' unless attributes.is_a?(Hash)

        @attributes = attributes.each_with_object({}) do |(key, value), result|
          result[key.to_s.dup.freeze] = Models.wrap(value)
        end.freeze
      end

      # @param key [String, Symbol] field name
      # @return [Object, nil] wrapped field value
      def [](key)
        @attributes[key.to_s]
      end

      # @param key [String, Symbol] field name
      # @return [Object] wrapped field value
      def fetch(key, *defaults, &)
        @attributes.fetch(key.to_s, *defaults, &)
      end

      # @param key [String, Symbol] field name
      # @return [Boolean] whether the field exists
      def key?(key)
        @attributes.key?(key.to_s)
      end

      # Iterates through response fields.
      # @yieldparam key [String]
      # @yieldparam value [Object]
      # @return [Enumerator, self]
      def each(&block)
        return enum_for(:each) unless block

        @attributes.each(&block)
      end

      # @return [Hash] recursive defensive plain-data copy
      def to_h
        Models.unwrap(@attributes)
      end

      # Rails-compatible JSON representation.
      # @return [Hash]
      def as_json(*)
        to_h
      end

      # @return [String] JSON document
      def to_json(*args)
        to_h.to_json(*args)
      end

      # @return [String]
      def inspect
        "#<#{self.class.name} #{@attributes.inspect}>"
      end
    end

    module_function

    # Recursively wraps hashes returned by the API.
    # @param value [Object]
    # @return [Object]
    def wrap(value)
      return value.dup.freeze if value.is_a?(String)
      return Model.new(value) if value.is_a?(Hash)
      return value.map { |item| wrap(item) }.freeze if value.is_a?(Array)

      value
    end

    # Recursively converts models into plain mutable Ruby data.
    # @param value [Object]
    # @return [Object]
    def unwrap(value)
      return value.dup if value.is_a?(String)
      return value.to_h if value.is_a?(Model)
      return value.to_h { |key, item| [key.dup, unwrap(item)] } if value.is_a?(Hash)
      return value.map { |item| unwrap(item) } if value.is_a?(Array)

      value
    end
  end
end
