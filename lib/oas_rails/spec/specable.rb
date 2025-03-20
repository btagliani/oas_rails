module OasRails
  module Spec
    module Specable
      def oas_fields
        []
      end

      def to_spec
        hash = {}
        oas_fields.each do |var|
          key = var.to_s

          camel_case_key = key.camelize(:lower).to_sym
          value = send(var)

          if defined?(Rails) && key == "examples"
            Rails.logger.debug "DEBUGGING: Specable#to_spec for examples"
            Rails.logger.debug "Examples value: #{value.inspect}"
          end

          processed_value = if value.respond_to?(:to_spec)
                              value.to_spec
                            elsif value.is_a?(Array) && value.all? { |elem| elem.respond_to?(:to_spec) }
                              value.map(&:to_spec)
                            # elsif value.is_a?(Hash)
                            #   hash = {}
                            #   value.each do |key, object|
                            #     hash[key] = object.to_spec
                            #   end
                            #   hash
                            else
                              value
                            end

          if defined?(Rails) && key == "examples"
            Rails.logger.debug "Processed examples value: #{processed_value.inspect}"
            Rails.logger.debug "Valid? #{!valid_processed_value?(processed_value)}"
          end

          hash[camel_case_key] = processed_value unless valid_processed_value?(processed_value)
        end

        Rails.logger.debug "Final hash examples: #{hash[:examples].inspect}" if defined?(Rails) && hash.key?(:examples)

        hash
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def as_json(options = nil)
        to_spec
      end
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def valid_processed_value?(processed_value)
        # Reference objects are never considered empty/invalid
        return false if defined?(OasRails::Spec::Reference) && processed_value.is_a?(OasRails::Spec::Reference)

        # For other objects, apply the standard checks
        ((processed_value.is_a?(Hash) || processed_value.is_a?(Array)) && processed_value.empty?) || processed_value.nil?
      end

      def snake_to_camel(snake_str)
        words = snake_str.to_s.split('_')
        words[1..].map!(&:capitalize)
        (words[0] + words[1..].join).to_sym
      end
    end
  end
end
