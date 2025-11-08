require "./oauth2_provider"

module Comrade
  module Providers
    # Authentik OAuth 2.0 and OpenID Connect provider
    class Authentik < OAuth2Provider
      property base_url : String

      def initialize(@client_id : String, @redirect_uri : String, @client_secret : String? = nil, base_url : String? = nil)
        super(@client_id, @redirect_uri, @client_secret)
        @base_url = base_url || extract_base_url_from_redirect_uri
      end

      def authorization_url : String
        "#{base_url}/application/o/authorize/"
      end

      def token_url : String
        "#{base_url}/application/o/token/"
      end

      def user_url : String
        "#{base_url}/application/o/userinfo/"
      end

      def revocation_url : String
        "#{base_url}/application/o/revoke/"
      end

      # Authentik-specific field mappings (OpenID Connect standard)
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "sub",
          "nickname" => "preferred_username",
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "picture",
        }
      end

      # Override redirect to add OpenID Connect support
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

        # Include OpenID Connect if requested
        if scopes.includes?("openid")
          params["nonce"] = generate_state
        end

        build_auth_url(authorization_url, params)
      end

      # Revoke token (Authentik supports token revocation)
      def revoke_token(token : String) : Bool
        params = {
          "token"           => token,
          "client_id"       => client_id,
          "token_type_hint" => "access_token",
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

      # Default scopes for Authentik (OpenID Connect)
      def default_scopes : Array(String)
        ["openid", "profile", "email"]
      end

      # Extract base URL from redirect_uri if base_url not provided
      private def extract_base_url_from_redirect_uri : String
        # Try to extract base URL from redirect_uri if it contains the Authentik domain
        if redirect_uri.includes?("authentik")
          uri = URI.parse(redirect_uri)
          return "#{uri.scheme}://#{uri.host}"
        end

        raise ConfigurationException.new("Unable to determine Authentik base URL. Please provide base_url as the 4th parameter or use an authentik domain in redirect_uri.")
      end
    end
  end
end
