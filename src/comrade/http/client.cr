require "http/client"
require "http/params"
require "uri"
require "json"
require "openssl"

module Comrade
  module Http
    # HTTP client abstraction for OAuth requests using Crystal's built-in HTTP client
    class Client
      property user_agent : String = "Comrade/#{Comrade::VERSION}"
      property timeout : Int32 = 30
      property? follow_redirects : Bool = true
      property max_redirects : Int32 = 5

      # Perform GET request
      def get(url : String, headers : HTTP::Headers? = nil) : HTTP::Client::Response
        uri = URI.parse(url)
        client = build_client(uri)

        response_headers = merge_headers(headers)
        response = client.get(uri.request_target, headers: response_headers)
        handle_response(response)
      end

      # Perform POST request
      def post(url : String, body : String? = nil, headers : HTTP::Headers? = nil) : HTTP::Client::Response
        uri = URI.parse(url)
        client = build_client(uri)

        response_headers = merge_headers(headers)
        response = client.post(uri.request_target, headers: response_headers, body: body)
        handle_response(response)
      end

      # Perform POST request with form data
      def post_form(url : String, form_data : Hash(String, String), headers : HTTP::Headers? = nil) : HTTP::Client::Response
        headers ||= HTTP::Headers.new
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        body = HTTP::Params.encode(form_data)
        post(url, body, headers)
      end

      # Perform POST request with JSON data
      def post_json(url : String, json_data : Hash | Array, headers : HTTP::Headers? = nil) : HTTP::Client::Response
        headers ||= HTTP::Headers.new
        headers["Content-Type"] = "application/json"
        headers["Accept"] = "application/json"

        body = json_data.to_json
        post(url, body, headers)
      end

      # Build and configure HTTP client
      private def build_client(uri : URI) : HTTP::Client
        client = HTTP::Client.new(uri)
        client.connect_timeout = timeout.seconds
        client.read_timeout = timeout.seconds
        # Note: HTTP::Client in Crystal doesn't have built-in redirect following
        # This would need to be implemented manually if needed
        client
      end

      # Merge custom headers with default headers
      private def merge_headers(custom_headers : HTTP::Headers?) : HTTP::Headers
        headers = HTTP::Headers.new
        headers["User-Agent"] = user_agent

        if custom_headers
          custom_headers.each do |key, value|
            headers[key] = value
          end
        end

        headers
      end

      # Handle response and raise exceptions for errors
      private def handle_response(response : HTTP::Client::Response) : HTTP::Client::Response
        unless response.success?
          raise HttpException.new(response.status_code, response.body?)
        end

        response
      rescue ex : IO::TimeoutError
        raise HttpException.new(nil, "Request timed out after #{timeout} seconds")
      rescue ex : OpenSSL::Error
        raise HttpException.new(nil, "SSL/TLS error: #{ex.message}")
      rescue ex : Socket::Error
        raise HttpException.new(nil, "Network error: #{ex.message}")
      end
    end
  end
end
