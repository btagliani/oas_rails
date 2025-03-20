module OasRails
  module Builders
    class OperationBuilder
      include Extractors::OasRouteExtractor

      def initialize(specification)
        @specification = specification
        @operation = Spec::Operation.new(specification)
      end

      def from_oas_route(oas_route)
        @operation.summary = extract_summary(oas_route:)
        @operation.operation_id = extract_operation_id(oas_route:)
        @operation.description = oas_route.docstring
        @operation.tags = extract_tags(oas_route:)
        @operation.security = extract_security(oas_route:)
        @operation.parameters = ParametersBuilder.new(@specification).from_oas_route(oas_route).build

        # Build and debug the request body
        request_body_ref = RequestBodyBuilder.new(@specification).from_oas_route(oas_route).reference
        if defined?(Rails)
          Rails.logger.debug "DEBUGGING: OperationBuilder#from_oas_route"
          Rails.logger.debug "Request body reference: #{request_body_ref.inspect}"
          Rails.logger.debug "Request body reference to_spec: #{request_body_ref.respond_to?(:to_spec) ? request_body_ref.to_spec : 'No to_spec method'}"
        end
        @operation.request_body = request_body_ref

        @operation.responses = ResponsesBuilder.new(@specification)
                                               .from_oas_route(oas_route)
                                               .add_autodiscovered_responses(oas_route)
                                               .add_default_responses(oas_route, !@operation.security.empty?).build

        Rails.logger.debug "Final operation: #{@operation.to_spec.inspect}" if defined?(Rails)

        self
      end

      def build
        @operation
      end
    end
  end
end
