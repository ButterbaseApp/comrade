require "base64"

module Comrade
  module Providers
    # Base implementation for OAuth 2.0 providers
    abstract class OAuth2Provider < BaseProvider
      abstract def authorization_url : String
      abstract def token_url : String
      abstract def user_url : String

      # Generate authorization URL
      def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                   code_verifier : String? = nil, **options) : String
        state ||= generate_state
        params = {
          "client_id"     => client_id,
          "redirect_uri"  => redirect_uri,
          "response_type" => "code",
          "scope"         => scopes.join(" "),
          "state"         => state,
        }

        # Add PKCE parameters for public clients (no client secret)
        if code_verifier && !client_secret
          code_challenge = generate_code_challenge(code_verifier)
          params["code_challenge"] = code_challenge
          params["code_challenge_method"] = "S256"
        end

        build_auth_url(authorization_url, params)
      end

      # Exchange authorization code for access token
      def get_token(code : String, state : String? = nil, code_verifier : String? = nil, **options) : Token
        params = {
          "client_id"     => client_id,
          "client_secret" => client_secret || "",
          "code"          => code,
          "redirect_uri"  => redirect_uri,
          "grant_type"    => "authorization_code",
        }

        # Add code verifier for PKCE
        if code_verifier
          params["code_verifier"] = code_verifier
        end

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", token_url, HTTP::Params.encode(params), headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        Token.from_json_object(data)
      end

      # Get user information using access token
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        response = make_request("GET", user_url, nil, headers)
        data = parse_json_response(response)

        User.from_oauth_response(data, user_field_mappings)
      end

      # Refresh access token
      def refresh_token(refresh_token : String, **options) : Token
        params = {
          "client_id"     => client_id,
          "client_secret" => client_secret || "",
          "refresh_token" => refresh_token,
          "grant_type"    => "refresh_token",
        }

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", token_url, HTTP::Params.encode(params), headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        Token.from_json_object(data)
      end

      # Revoke access token (optional - providers may not support this)
      def revoke_token(token : String) : Bool
        return false unless respond_to?(:revocation_url)

        params = {
          "client_id"     => client_id,
          "client_secret" => client_secret || "",
          "token"         => token,
        }

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", revocation_url, HTTP::Params.encode(params), headers)
        response.success?
      end

      # Get user information directly from authorization code
      def user(code : String, state : String? = nil, **options) : User
        token = get_token(code, state, **options)
        get_user(token)
      end

      # Get access token information
      def tokens(code : String, state : String? = nil, **options) : Token
        get_token(code, state, **options)
      end

      # Provider-specific field mappings for user data
      # Override in provider implementations
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "login",
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "avatar_url",
        }
      end
    end
  end
end
