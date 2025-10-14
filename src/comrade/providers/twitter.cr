require "./oauth2_provider"

module Comrade
  module Providers
    # Twitter/X OAuth 2.0 provider
    class Twitter < OAuth2Provider
      def authorization_url : String
        "https://twitter.com/i/oauth2/authorize"
      end

      def token_url : String
        "https://api.twitter.com/2/oauth2/token"
      end

      def user_url : String
        "https://api.twitter.com/2/users/me"
      end

      def revocation_url : String
        "https://api.twitter.com/2/oauth2/revoke"
      end

      # Twitter-specific field mappings
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "username",
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "profile_image_url",
        }
      end

      # Override redirect to add Twitter-specific parameters
      def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                   code_verifier : String? = nil, **options) : String
        state ||= generate_state
        params = {
          "client_id"             => client_id,
          "redirect_uri"          => redirect_uri,
          "response_type"         => "code",
          "scope"                 => scopes.join(" "),
          "state"                 => state,
          "code_challenge"        => "challenge",
          "code_challenge_method" => "plain",
        }

        # Add PKCE parameters for public clients
        if code_verifier && !client_secret
          code_challenge = generate_code_challenge(code_verifier)
          params["code_challenge"] = code_challenge
          params["code_challenge_method"] = "S256"
        end

        build_auth_url(authorization_url, params)
      end

      # Override get_token to handle Twitter-specific token response
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
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        response = make_request("POST", token_url, HTTP::Params.encode(params), headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        Token.from_json_object(data)
      end

      # Override get_user to handle Twitter's v2 API
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        # Twitter v2 API requires user.fields parameter
        params = {
          "user.fields" => "created_at,description,location,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified",
        }

        response = make_request("GET", "#{user_url}?#{HTTP::Params.encode(params)}", nil, headers)
        user_data = parse_json_response(response)

        # Twitter v2 API returns data in a "data" field
        if data_field = user_data["data"]?
          user_data = data_field
        end

        # Twitter doesn't include email in user endpoint by default
        # Email requires separate scope and endpoint if needed
        user_hash = user_data.as_h

        # Add placeholder for email if not included
        unless user_hash.has_key?("email")
          # Email requires "tweet.read users.read email" scopes and is only available
          # with separate API call, so we'll leave it nil for now
        end

        User.from_oauth_response(JSON::Any.new(user_hash), user_field_mappings)
      end

      # Override refresh_token to handle Twitter's refresh token flow
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
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        response = make_request("POST", token_url, HTTP::Params.encode(params), headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        # Twitter may not return refresh token on refresh
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

      # Revoke token (Twitter supports token revocation)
      def revoke_token(token : String) : Bool
        params = {
          "token"           => token,
          "token_type_hint" => "access_token",
        }

        headers = HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        # Add client authentication if available
        if client_secret
          auth = Base64.strict_encode("#{client_id}:#{client_secret}")
          headers["Authorization"] = "Basic #{auth}"
        end

        response = make_request("POST", revocation_url, HTTP::Params.encode(params), headers)
        response.success?
      rescue Comrade::HttpException
        # Return false if revocation fails
        false
      end

      # Default scopes for Twitter
      def default_scopes : Array(String)
        ["tweet.read", "users.read"]
      end
    end
  end
end
