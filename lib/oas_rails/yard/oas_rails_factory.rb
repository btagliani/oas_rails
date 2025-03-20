module OasRails
  module YARD
    class OasRailsFactory < ::YARD::Tags::DefaultFactory
      # Parses a tag that represents a request body.
      # @param tag_name [String] The name of the tag.
      # @param text [String] The tag text to parse.
      # @return [RequestBodyTag] The parsed request body tag object.
      def parse_tag_with_request_body(tag_name, text)
        description, klass, schema, required = extract_description_and_schema(text)
        RequestBodyTag.new(tag_name, description, klass, schema:, required:)
      end

      # Parses a tag that represents a request body example.
      # @param tag_name [String] The name of the tag.
      # @param text [String] The tag text to parse.
      # @return [RequestBodyExampleTag] The parsed request body example tag object.
      def parse_tag_with_request_body_example(tag_name, text)
        # Check if text is valid for parsing
        return RequestBodyExampleTag.new(tag_name, "Default request", content: {}) if text.nil? || text.strip.empty?

        # Try to extract using the regex
        begin
          # Use a regex that supports multiline content with proper capture groups
          match = text.match(/^(.*?)\s*\[([^\]]*)\]\s*(.*)$/m)

          if match.nil?
            # If regex fails, try a simpler approach
            description = text.split(/\s*\[/).first&.strip || "Request"
            return RequestBodyExampleTag.new(tag_name, description, content: {})
          end

          description = match[1].strip
          type = match[2].strip
          content_text = match[3]

          # Check if content is just an opening brace (multiline content)
          if content_text.strip == '{' || content_text.strip == '{ '
            Rails.logger.info("Request body example for '#{description}' appears to have multiline content that couldn't be fully parsed") if defined?(Rails) && Rails.respond_to?(:logger)
            return RequestBodyExampleTag.new(tag_name, description, content: {})
          end

          content = eval_content(content_text)
          RequestBodyExampleTag.new(tag_name, description, content: content)
        rescue StandardError => e
          # In case of parsing error, return a default request body example tag
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.error("Failed to parse request body example tag: #{e.message}\nText: #{text}")
          else
            puts "Failed to parse request body example tag: #{e.message}\nText: #{text}"
          end
          RequestBodyExampleTag.new(tag_name, "Default request", content: {})
        end
      end

      # Parses a tag that represents a parameter.
      # @param tag_name [String] The name of the tag.
      # @param text [String] The tag text to parse.
      # @return [ParameterTag] The parsed parameter tag object.
      def parse_tag_with_parameter(tag_name, text)
        name, location, schema, required, description = extract_name_location_schema_and_description(text)
        ParameterTag.new(tag_name, name, description, schema, location, required:)
      end

      # Parses a tag that represents a response.
      # @param tag_name [String] The name of the tag.
      # @param text [String] The tag text to parse.
      # @return [ResponseTag] The parsed response tag object.
      def parse_tag_with_response(tag_name, text)
        name, code, schema = extract_name_code_and_schema(text)
        ResponseTag.new(tag_name, code, name, schema)
      end

      # Parses a tag that represents a response example.
      # @param tag_name [String] The name of the tag.
      # @param text [String] The tag text to parse.
      # @return [ResponseExampleTag] The parsed response example tag object.
      def parse_tag_with_response_example(tag_name, text)
        # Check if text is valid for parsing
        return ResponseExampleTag.new(tag_name, "Default response", content: {}, code: "200") if text.nil? || text.strip.empty?

        # Try to extract name, code, and hash using the helper method
        begin
          description, code, hash = extract_name_code_and_hash(text)

          # Make sure we have all necessary values
          description = "Response" if description.nil? || description.strip.empty?
          code = "200" if code.nil? || code.strip.empty?
          hash = {} if hash.nil?

          ResponseExampleTag.new(tag_name, description, content: hash, code:)
        rescue StandardError => e
          # In case of parsing error, return a default response example tag
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.error("Failed to parse response example tag: #{e.message}\nText: #{text}")
          else
            puts "Failed to parse response example tag: #{e.message}\nText: #{text}"
          end
          ResponseExampleTag.new(tag_name, "Default response", content: {}, code: "200")
        end
      end

      private

      # Reusable method for extracting description, type, and content with an option to process content.
      # @param text [String] The text to parse.
      # @param process_content [Boolean] Whether to evaluate the content as a hash.
      # @return [Array] An array containing the description, type, and content or remaining text.
      def extract_description_type_and_content(text, process_content: false, expresion: /^(.*?)\s*\[(.*)\]\s*(.*)$/)
        match = text.match(expresion)
        raise ArgumentError, "Invalid tag format: #{text}" if match.nil?

        description = match[1].strip
        type = match[2].strip
        content = process_content ? eval_content(match[3].strip) : match[3].strip

        [description, type, content]
      end

      # Specific method to extract description and schema for request body tags.
      # @param text [String] The text to parse.
      # @return [Array] An array containing the description, class, schema, and required flag.
      def extract_description_and_schema(text)
        description, type, = extract_description_type_and_content(text)
        klass, schema, required = type_text_to_schema(type)
        [description, klass, schema, required]
      end

      # Specific method to extract name, location, and schema for parameters.
      # @param text [String] The text to parse.
      # @return [Array] An array containing the name, location, schema, and required flag.
      def extract_name_location_schema_and_description(text)
        match = text.match(/^(.*?)\s*\[(.*?)\]\s*(.*)$/)
        name, location = extract_text_and_parentheses_content(match[1].strip)
        schema, required = type_text_to_schema(match[2].strip)[1..]
        description = match[3].strip
        [name, location, schema, required, description]
      end

      # Specific method to extract name, code, and schema for responses.
      # @param text [String] The text to parse.
      # @return [Array] An array containing the name, code, and schema.
      def extract_name_code_and_schema(text)
        name, code = extract_text_and_parentheses_content(text)
        _, type, = extract_description_type_and_content(text)
        schema = type_text_to_schema(type)[1]
        [name, code, schema]
      end

      # Specific method to extract name, code, and hash for responses examples.
      # @param text [String] The text to parse.
      # @return [Array] An array containing the name, code, and hash.
      def extract_name_code_and_hash(text)
        # First get the name and code part
        name_with_code = text.split(/\s*\[/).first
        name, code = extract_text_and_parentheses_content(name_with_code&.strip)

        # Handle case where name and code extraction fails
        if name.nil? || code.nil?
          # Try to extract just the name without parentheses
          name = name_with_code&.strip
          code = "200" # Default to 200 if code can't be extracted
        end

        # Then get the hash content part which can be multiline
        # This regex matches anything in square brackets and grabs the content
        bracket_match = text.match(/\[(.*)\]/m)
        return [name, code, {}] unless bracket_match

        bracket_content = bracket_match[1].strip

        # Check if the content is a Ruby hash directly inside the brackets
        if bracket_content.start_with?('{') && bracket_content.end_with?('}')
          hash = eval_content(bracket_content)
          return [name, code, hash]
        end

        # Otherwise, try the standard approach with content after the bracket
        type_content = text.match(/\[(.*?)\]\s*(.*)/m)
        return [name, code, {}] unless type_content

        # Extract the content after the closing bracket
        content_text = type_content[2]

        # If content is just '{' or starts with '{' but is incomplete,
        # the content might continue on the next lines in the comment block
        if content_text.strip == '{' || content_text.strip == '{ '
          # In this case, we can't extract meaningful content from just this method
          # We'll return an empty hash, but log a message suggesting to look at surrounding context
          Rails.logger.info("Response example for '#{name}' appears to have multiline content that couldn't be fully parsed") if defined?(Rails) && Rails.respond_to?(:logger)
          return [name, code, {}]
        end

        hash = eval_content(content_text)
        [name, code, hash]
      end

      # Evaluates a string as a hash, handling errors gracefully.
      # @param content [String] The content string to evaluate.
      # @return [Hash] The evaluated hash, or an empty hash if an error occurs.
      # rubocop:disable Security/Eval
      def eval_content(content)
        # Handle nil or empty content
        return {} if content.nil? || content.strip.empty?

        # Handle potential multiline content by normalizing the string
        content = content.strip

        # Special case: if content is just '{' or '{ ' (often happens with multiline YARD comments)
        return {} if ['{', '{ '].include?(content)

        # Fix for multiline content
        # If content contains newlines, we need to ensure it's a valid Ruby hash
        if content.include?("\n")
          # Remove all leading '#' characters that might be from YARD comments
          content = content.lines.map do |line|
            line.sub(/^\s*#\s*/, '').rstrip
          end.join(' ').strip
        end

        # Make sure braces are balanced
        open_count = content.count('{')
        close_count = content.count('}')

        # If braces aren't balanced, try to fix or return empty hash
        if open_count != close_count
          return {} unless open_count > close_count

          # Add missing closing braces
          content += '}' * (open_count - close_count)

          # Unbalanced in the other direction - can't properly fix this

        end

        begin
          result = eval(content)
          # Make sure we return a hash
          result.is_a?(Hash) ? result : {}
        rescue StandardError => e
          # Log the error for debugging purposes
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.error("Failed to parse example content: #{e.message}\nContent: #{content}")
          else
            puts "Failed to parse example content: #{e.message}\nContent: #{content}"
          end
          {}
        end
      end
      # rubocop:enable Security/Eval

      # Parses the position name and location from input text.
      # @param input [String] The input text to parse.
      # @return [Array] An array containing the name and location.
      def extract_text_and_parentheses_content(input)
        return unless input =~ /^(.+?)\(([^)]+)\)/

        text = ::Regexp.last_match(1).strip
        parenthesis_content = ::Regexp.last_match(2).strip
        [text, parenthesis_content]
      end

      # Extracts the text and whether it's required.
      # @param text [String] The text to parse.
      # @return [Array] An array containing the text and a required flag.
      def text_and_required(text)
        if text.start_with?('!')
          [text.sub(/^!/, ''), true]
        else
          [text, false]
        end
      end

      # Matches and validates a description and type from text.
      # @param text [String] The text to parse.
      # @return [MatchData] The match data from the regex.
      def description_and_type(text)
        match = text.match(/^(.*?)\s*\[(.*?)\]\s*(.*)$/)
        raise ArgumentError, "The request body tag is not valid: #{text}" if match.nil?

        match
      end

      # Checks if a given text refers to an ActiveRecord class.
      # @param text [String] The text to check.
      # @return [Boolean] True if the text refers to an ActiveRecord class, false otherwise.
      def active_record_class?(text)
        klass = text.constantize
        klass.ancestors.map(&:to_s).include? 'ActiveRecord::Base'
      rescue StandardError
        false
      end

      # Converts type text to a schema, checking if it's an ActiveRecord class.
      # @param text [String] The type text to convert.
      # @return [Array] An array containing the class, schema, and required flag.
      def type_text_to_schema(text)
        type_text, required = text_and_required(text)

        if active_record_class?(type_text)
          klass = type_text.constantize
          schema = Builders::EsquemaBuilder.build_outgoing_schema(klass:)
        else
          schema = JsonSchemaGenerator.process_string(type_text)[:json_schema]
          klass = Object
        end
        [klass, schema, required]
      end
    end
  end
end
