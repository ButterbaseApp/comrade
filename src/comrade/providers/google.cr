require "./oauth2_provider"

module Comrade
  module Providers
    # Google OAuth 2.0 and OpenID Connect provider
    class Google < OAuth2Provider
      def authorization_url : String
        "https://accounts.google.com/o/oauth2/v2/auth"
      end

      def token_url : String
        "https://oauth2.googleapis.com/token"
      end

      def user_url : String
        "https://www.googleapis.com/oauth2/v2/userinfo"
      end

      def openid_user_url : String
        "https://openidconnect.googleapis.com/v1/userinfo"
      end

      def revocation_url : String
        "https://oauth2.googleapis.com/revoke"
      end

      # Google-specific field mappings
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "email", # Google doesn't have username, use email as fallback
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "picture",
        }
      end

      # Override redirect to add Google-specific parameters
      def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                   code_verifier : String? = nil, **options) : String
        state ||= generate_state
        params = {
          "client_id"     => client_id,
          "redirect_uri"  => redirect_uri,
          "response_type" => "code",
          "scope"         => scopes.join(" "),
          "state"         => state,
          "access_type"   => "offline", # Allow refresh token
          "prompt"        => "consent", # Force consent dialog for refresh token
        }

        # Add PKCE parameters for public clients
        if code_verifier && !client_secret
          code_challenge = generate_code_challenge(code_verifier)
          params["code_challenge"] = code_challenge
          params["code_challenge_method"] = "S256"
        end

        # Include OpenID Connect if requested
        if scopes.includes?("openid")
          params["nonce"] = generate_state
        end

        build_auth_url(authorization_url, params)
      end

      # Override get_token to handle Google-specific token response
      def get_token(code : String, state : String? = nil, code_verifier : String? = nil, **options) : Token
        params = {
          "client_id"    => client_id,
          "code"         => code,
          "redirect_uri" => redirect_uri,
          "grant_type"   => "authorization_code",
        }

        # Add client secret if available (confidential client)
        if client_secret
          params["client_secret"] = client_secret
        end

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

      # Override refresh_token to handle Google's refresh token flow
      def refresh_token(refresh_token : String, **options) : Token
        params = {
          "client_id"     => client_id,
          "refresh_token" => refresh_token,
          "grant_type"    => "refresh_token",
        }

        # Add client secret if available
        if client_secret
          params["client_secret"] = client_secret
        end

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", token_url, HTTP::Params.encode(params), headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        # Google may not return refresh token on refresh
        token = Token.from_json_object(data)
        if !token.refresh_token && refresh_token
          # Preserve the original refresh token
          token = Token.new(
            token.access_token,
            refresh_token,
            token.expires_in,
            token.scope,
            token.token_type,
            token.created_at
          )
        end

        token
      end

      # Revoke token (Google supports token revocation)
      def revoke_token(token : String) : Bool
        params = {
          "token" => token,
        }

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", revocation_url, HTTP::Params.encode(params), headers)
        response.success?
      end

      # Default scopes for Google
      def default_scopes : Array(String)
        ["openid", "profile", "email"]
      end
    end
  end
end
