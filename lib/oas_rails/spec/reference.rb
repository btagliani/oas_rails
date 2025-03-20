module OasRails
  module Spec
    class Reference
      include Specable
      attr_reader :ref

      def initialize(ref)
        @ref = ref
      end

      def to_spec
        if defined?(Rails)
          Rails.logger.debug "DEBUGGING: Reference#to_spec"
          Rails.logger.debug "Reference @ref: #{@ref}"
        end

        { '$ref' => @ref }
      end

      def as_json(options = nil)
        if defined?(Rails)
          Rails.logger.debug "DEBUGGING: Reference#as_json"
          Rails.logger.debug "Options: #{options.inspect}"
        end

        to_spec
      end

      def empty?
        false # A reference is never considered empty
      end
    end
  end
end
