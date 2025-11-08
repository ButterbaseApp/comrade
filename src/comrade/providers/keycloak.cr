require "./oauth2_provider"

module Comrade
  module Providers
    # Keycloak OAuth 2.0 and OpenID Connect provider
    # Keycloak is an open-source identity and access management solution
    class Keycloak < OAuth2Provider
      property base_url : String
      property realm : String

      def initialize(@client_id : String, @redirect_uri : String, @client_secret : String? = nil,
                     base_url : String? = nil, realm : String? = nil)
        super(@client_id, @redirect_uri, @client_secret)
        @base_url = base_url || extract_base_url_from_redirect_uri
        @realm = realm || extract_realm_from_config
      end

      def authorization_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/auth"
      end

      def token_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/token"
      end

      def user_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/userinfo"
      end

      def revocation_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/revoke"
      end

      def end_session_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/logout"
      end

      def jwks_url : String
        "#{base_url}/realms/#{realm}/protocol/openid-connect/certs"
      end

      def well_known_url : String
        "#{base_url}/realms/#{realm}/.well-known/openid-configuration"
      end

      # Keycloak-specific field mappings (OpenID Connect standard)
      def user_field_mappings : Hash(String, String)
        {
          "id"       => "sub",
          "nickname" => "preferred_username",
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "picture",
        }
      end

      # Override redirect to add OpenID Connect support with PKCE
      def redirect(scopes : Array(String) = [] of String, state : String? = nil,
                   code_verifier : String? = nil, nonce : String? = nil, **options) : String
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

        # Include OpenID Connect if requested
        if scopes.includes?("openid")
          params["nonce"] = nonce || generate_state
        end

        build_auth_url(authorization_url, params)
      end

      # Get user information with enhanced error handling for Keycloak
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/json",
        }

        response = make_request("GET", user_url, nil, headers)
        data = parse_json_response(response)

        User.from_keycloak_response(data, user_field_mappings)
      end

      # Refresh token with Keycloak-specific handling
      def refresh_token(refresh_token : String, scope : String? = nil, **options) : Token
        params = HTTP::Params.build do |form|
          form.add("client_id", client_id)
          if secret = client_secret
            form.add("client_secret", secret)
          end
          form.add("refresh_token", refresh_token)
          form.add("grant_type", "refresh_token")
          if scope
            form.add("scope", scope)
          end
        end

        headers = HTTP::Headers{
          "Accept"       => "application/json",
          "Content-Type" => "application/x-www-form-urlencoded",
        }

        response = make_request("POST", token_url, params, headers)
        data = parse_json_response(response)
        validate_oauth_response(data)

        Token.from_keycloak_response(data)
      end

      # Revoke token (Keycloak supports token revocation)
      def revoke_token(token : String, token_type_hint : String? = "access_token") : Bool
        params = {
          "token"           => token,
          "client_id"       => client_id,
          "token_type_hint" => token_type_hint,
        }

        # Add client secret if available (confidential client)
        if secret = client_secret
          params["client_secret"] = secret
        end

        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("POST", revocation_url, HTTP::Params.encode(params), headers)
        response.success?
      end

      # End session (logout user)
      def end_session(id_token_hint : String? = nil, post_logout_redirect_uri : String? = nil) : String
        params = Hash(String, String).new

        if id_token_hint
          params["id_token_hint"] = id_token_hint
        end

        if post_logout_redirect_uri
          params["post_logout_redirect_uri"] = post_logout_redirect_uri
        end

        build_auth_url(end_session_url, params)
      end

      # Get OpenID Connect configuration from well-known endpoint
      def oidc_configuration : JSON::Any
        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("GET", well_known_url, nil, headers)
        parse_json_response(response)
      end

      # Get JSON Web Key Set for token validation
      def jwks : JSON::Any
        headers = HTTP::Headers{
          "Accept" => "application/json",
        }

        response = make_request("GET", jwks_url, nil, headers)
        parse_json_response(response)
      end

      # Default scopes for Keycloak (OpenID Connect)
      def default_scopes : Array(String)
        ["openid", "profile", "email"]
      end

      # Extract base URL from redirect_uri if base_url not provided
      private def extract_base_url_from_redirect_uri : String
        # Try to extract base URL from redirect_uri if it contains the Keycloak domain
        if match = redirect_uri.match(/^(https?:\/\/[^\/]+)/)
          return match[1]
        end

        raise ConfigurationException.new("Unable to determine Keycloak base URL. Please provide base_url as the 4th parameter.")
      end

      # Extract realm from configuration or use default
      private def extract_realm_from_config : String
        # Try to extract realm from redirect_uri
        if match = redirect_uri.match(/\/realms\/([^\/]+)/)
          return match[1]
        end

        # Default to master realm
        "master"
      end
    end
  end
end
