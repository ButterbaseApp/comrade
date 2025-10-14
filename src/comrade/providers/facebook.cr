require "./oauth2_provider"

module Comrade
  module Providers
    # Facebook/Meta OAuth 2.0 provider
    class Facebook < OAuth2Provider
      def authorization_url : String
        "https://www.facebook.com/v18.0/dialog/oauth"
      end

      def token_url : String
        "https://graph.facebook.com/v18.0/oauth/access_token"
      end

      def user_url : String
        "https://graph.facebook.com/me"
      end

      def revocation_url : String
        "https://graph.facebook.com/v18.0/me/permissions"
      end

      # Facebook-specific field mappings
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "name", # Facebook doesn't have username, use name as fallback
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "picture",
        }
      end

      # Override redirect to add Facebook-specific parameters
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

        # Add PKCE parameters for public clients
        if code_verifier && !client_secret
          code_challenge = generate_code_challenge(code_verifier)
          params["code_challenge"] = code_challenge
          params["code_challenge_method"] = "S256"
        end

        build_auth_url(authorization_url, params)
      end

      # Override get_token to handle Facebook-specific token response
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

      # Override get_user to handle Facebook's Graph API fields
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        # Facebook Graph API requires fields parameter
        params = {
          "fields" => "id,name,email,picture.type(large)",
        }

        response = make_request("GET", "#{user_url}?#{HTTP::Params.encode(params)}", nil, headers)
        user_data = parse_json_response(response)

        # Handle picture field which returns an object
        if picture_data = user_data["picture"]?
          if picture_url = picture_data["data"]?.try(&.["url"]?)
            # Extract the picture URL and add it as picture field
            user_hash = user_data.as_h
            user_hash["picture"] = JSON::Any.new(picture_url.as_s)
            user_data = JSON::Any.new(user_hash)
          end
        end

        User.from_oauth_response(user_data, user_field_mappings)
      end

      # Override refresh_token to handle Facebook's refresh token flow
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

        # Facebook may not return refresh token on refresh
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

      # Revoke token (Facebook supports permission revocation via DELETE)
      def revoke_token(token : String) : Bool
        # Facebook's Graph API uses DELETE for revoking permissions
        # But our HTTP client doesn't support DELETE, so we'll return false for now
        # This would need to be implemented with a custom HTTP request
        false
      end

      # Default scopes for Facebook
      def default_scopes : Array(String)
        ["email", "public_profile"]
      end
    end
  end
end
