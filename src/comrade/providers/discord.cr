require "./oauth2_provider"

module Comrade
  module Providers
    # Discord OAuth 2.0 provider
    class Discord < OAuth2Provider
      def authorization_url : String
        "https://discord.com/api/oauth2/authorize"
      end

      def token_url : String
        "https://discord.com/api/oauth2/token"
      end

      def user_url : String
        "https://discord.com/api/users/@me"
      end

      def user_guilds_url : String
        "https://discord.com/api/users/@me/guilds"
      end

      def revocation_url : String
        "https://discord.com/api/oauth2/token/revoke"
      end

      # Discord-specific field mappings
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "username",
          "name"     => "global_name", # Discord has global_name and username
          "email"    => "email",
          "avatar"   => "avatar",
        }
      end

      # Override redirect to add Discord-specific parameters
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

      # Override get_token to handle Discord-specific token response
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

      # Override get_user to handle Discord's user API
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        response = make_request("GET", user_url, nil, headers)
        user_data = parse_json_response(response)

        # Discord returns avatar hash, need to construct full URL
        if avatar_hash = user_data["avatar"]?.try(&.as_s?)
          user_hash = user_data.as_h
          user_id = user_data["id"].as_s

          # Construct Discord CDN URL for avatar
          avatar_url = "https://cdn.discordapp.com/avatars/#{user_id}/#{avatar_hash}"
          if avatar_hash.starts_with?("a_")
            avatar_url += ".gif"
          else
            avatar_url += ".png"
          end

          user_hash["avatar"] = JSON::Any.new(avatar_url)
          user_data = JSON::Any.new(user_hash)
        end

        User.from_oauth_response(user_data, user_field_mappings)
      end

      # Get user's guilds (servers) - Discord-specific feature
      def get_user_guilds(token : Token) : JSON::Any?
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        response = make_request("GET", user_guilds_url, nil, headers)
        parse_json_response(response)
      rescue Comrade::HttpException
        nil
      end

      # Override refresh_token to handle Discord's refresh token flow
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

        # Discord may not return refresh token on refresh
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

      # Revoke token (Discord supports token revocation)
      def revoke_token(token : String) : Bool
        params = Hash(String, String).new
        params["token"] = token

        headers = HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        # Add client authentication if available
        if secret = client_secret
          params["client_id"] = client_id
          params["client_secret"] = secret
        end

        response = make_request("POST", revocation_url, HTTP::Params.encode(params), headers)
        response.success?
      rescue Comrade::HttpException
        # Return false if revocation fails
        false
      end

      # Default scopes for Discord
      def default_scopes : Array(String)
        ["identify", "email"]
      end
    end
  end
end
