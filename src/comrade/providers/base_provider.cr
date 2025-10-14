require "uri"
require "random/secure"

module Comrade
  module Providers
    # Abstract base class for all OAuth providers
    abstract class BaseProvider
      getter client_id : String
      getter client_secret : String?
      getter redirect_uri : String
      getter http_client : Http::Client

      def initialize(@client_id : String, @redirect_uri : String, @client_secret : String? = nil)
        @http_client = Http::Client.new
      end

      # Generate authorization URL to redirect user to OAuth provider
      abstract def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                            **options) : String

      # Exchange authorization code for access token
      abstract def get_token(code : String, state : String? = nil, **options) : Token

      # Get user information using access token
      abstract def get_user(token : Token) : User

      # Refresh access token
      abstract def refresh_token(refresh_token : String, **options) : Token

      # Revoke access token (if supported by provider)
      abstract def revoke_token(token : String) : Bool

      # Generate a random state parameter for CSRF protection
      def generate_state : String
        Random::Secure.hex(16)
      end

      # Generate a code verifier for PKCE
      def generate_code_verifier : String
        Random::Secure.base64(32)
      end

      # Generate code challenge from code verifier for PKCE
      def generate_code_challenge(code_verifier : String) : String
        digest = OpenSSL::Digest.new("SHA256")
        digest.update(code_verifier)
        Base64.strict_encode(digest.final).gsub("+", "-").gsub("/", "_").rstrip("=")
      end

      # Build authorization URL with common parameters
      protected def build_auth_url(base_url : String, params : Hash(String, String)) : String
        uri = URI.parse(base_url)

        # Add existing query parameters
        if existing_query = uri.query
          query_params = HTTP::Params.parse(existing_query)
        else
          query_params = HTTP::Params.new
        end

        # Add OAuth parameters
        params.each do |key, value|
          query_params[key] = value
        end

        uri.query = query_params.to_s
        uri.to_s
      end

      # Make HTTP request to provider
      protected def make_request(method : String, url : String, body : String? = nil,
                                 headers : HTTP::Headers? = nil) : HTTP::Client::Response
        case method.upcase
        when "GET"
          http_client.get(url, headers)
        when "POST"
          http_client.post(url, body, headers)
        else
          raise ArgumentError.new("Unsupported HTTP method: #{method}")
        end
      end

      # Parse JSON response
      protected def parse_json_response(response : HTTP::Client::Response) : JSON::Any
        JSON.parse(response.body)
      rescue JSON::ParseException
        raise HttpException.new(response.status_code, "Invalid JSON response: #{response.body}")
      end

      # Validate OAuth response for errors
      protected def validate_oauth_response(data : JSON::Any)
        if error = data["error"]?
          error_string = error.as_s?
          description = data["error_description"]?.try(&.as_s?)
          state = data["state"]?.try(&.as_s?)

          raise AuthorizationException.new(error_string, description, state)
        end
      end

      # Check if required scopes are included
      protected def validate_scopes(requested_scopes : Array(String), granted_scopes : String? = nil)
        return unless granted_scopes

        granted = granted_scopes.split(" ")
        missing = requested_scopes - granted

        unless missing.empty?
          raise InvalidScopeException.new(missing)
        end
      end
    end
  end
end
