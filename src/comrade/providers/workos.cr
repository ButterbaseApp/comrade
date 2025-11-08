require "./oauth2_provider"

module Comrade
  module Providers
    # WorkOS SSO provider - Enterprise-ready OAuth 2.0 authentication
    # Supports SSO via SAML, OIDC, and direct OAuth providers
    class WorkOS < OAuth2Provider
      def authorization_url : String
        "https://api.workos.com/sso/authorize"
      end

      def token_url : String
        "https://api.workos.com/sso/token"
      end

      def user_url : String
        "https://api.workos.com/sso/profile"
      end

      # Generate authorization URL with WorkOS-specific parameters
      def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                   connection : String? = nil, organization : String? = nil,
                   provider : String? = nil, domain_hint : String? = nil,
                   login_hint : String? = nil, **options) : String
        state ||= generate_state
        params = {
          "client_id"     => client_id,
          "redirect_uri"  => redirect_uri,
          "response_type" => "code",
          "state"         => state,
        }

        # Add WorkOS-specific parameters
        params["connection"] = connection if connection
        params["organization"] = organization if organization
        params["provider"] = provider if provider
        params["domain_hint"] = domain_hint if domain_hint
        params["login_hint"] = login_hint if login_hint

        # Add scopes if provided (WorkOS doesn't always require scopes)
        if !scopes.empty?
          params["scope"] = scopes.join(" ")
        end

        # Validate that at least one identifier is provided
        validate_workos_params(connection, organization, provider)

        build_auth_url(authorization_url, params)
      end

      # Exchange authorization code for access token
      def get_token(code : String, state : String? = nil, **options) : Token
        params = HTTP::Params.build do |form|
          form.add("client_id", client_id)
          if secret = client_secret
            form.add("client_secret", secret)
          end
          form.add("code", code)
          form.add("grant_type", "authorization_code")
        end

        headers = HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        response = make_request("POST", token_url, params, headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        # WorkOS token response structure
        Token.from_workos_response(data)
      end

      # Get user information using access token
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        response = make_request("GET", user_url, nil, headers)
        data = parse_json_response(response)

        User.from_workos_response(data, user_field_mappings)
      end

      # WorkOS doesn't support traditional token refresh
      # Tokens are typically valid until revoked
      def refresh_token(refresh_token : String, **options) : Token
        raise NotSupportedException.new("WorkOS does not support token refresh. Use the original token until revoked.")
      end

      # Revoke access token (WorkOS supports this)
      def revoke_token(token : String) : Bool
        return false unless client_secret

        params = HTTP::Params.build do |form|
          form.add("client_id", client_id)
          form.add("client_secret", client_secret)
          form.add("token", token)
        end

        headers = HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        begin
          response = make_request("POST", revoke_token_url, params, headers)
          response.success?
        rescue
          false
        end
      end

      # WorkOS-specific field mappings for user data
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "email"    => "email",
          "nickname" => "email", # Fallback to email if no nickname
          "name"     => "first_name",
          "avatar"   => "profile_picture_url",
        }
      end

      # Get revocation URL
      private def revoke_token_url : String
        "https://api.workos.com/sso/revoke"
      end

      # Validate WorkOS authorization parameters
      private def validate_workos_params(connection : String?, organization : String?, provider : String?)
        unless connection || organization || provider
          raise ArgumentError.new("One of connection, organization, or provider must be specified for WorkOS authorization")
        end

        # Validate provider if specified
        if provider && !valid_providers.includes?(provider)
          raise ArgumentError.new("Invalid provider '#{provider}'. Valid providers: #{valid_providers.join(", ")}")
        end
      end

      # List of valid direct OAuth providers
      private def valid_providers : Array(String)
        [
          "GoogleOAuth",
          "MicrosoftOAuth",
          "GitHubOAuth",
          "AppleOAuth",
        ]
      end

      # Default scopes for WorkOS (typically empty for SSO)
      def default_scopes : Array(String)
        [] of String
      end
    end
  end
end
