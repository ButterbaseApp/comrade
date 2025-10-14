require "./oauth2_provider"

module Comrade
  module Providers
    # GitHub OAuth 2.0 provider
    class GitHub < OAuth2Provider
      def authorization_url : String
        "https://github.com/login/oauth/authorize"
      end

      def token_url : String
        "https://github.com/login/oauth/access_token"
      end

      def user_url : String
        "https://api.github.com/user"
      end

      def user_url_with_email : String
        "https://api.github.com/user/emails"
      end

      # GitHub-specific field mappings
      protected def user_field_mappings : Hash(String, String)
        {
          "id"       => "id",
          "nickname" => "login",
          "name"     => "name",
          "email"    => "email",
          "avatar"   => "avatar_url",
        }
      end

      # Override get_user to fetch primary email if not included in main user response
      def get_user(token : Token) : User
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/vnd.github.v3+json",
          "User-Agent"    => "Comrade/#{Comrade::VERSION}",
        }

        # Get user profile
        response = make_request("GET", user_url, nil, headers)
        user_data = parse_json_response(response)

        # Get email if not present in user profile
        if user_data["email"]?.nil?
          email = fetch_primary_email(token)
          # Add email to user data
          if email
            user_hash = user_data.as_h
            user_hash["email"] = JSON::Any.new(email)
            user_data = JSON::Any.new(user_hash)
          end
        end

        User.from_oauth_response(user_data, user_field_mappings)
      end

      # Fetch primary email for user (GitHub requires separate API call for email)
      private def fetch_primary_email(token : Token) : String?
        headers = HTTP::Headers{
          "Authorization" => "Bearer #{token.access_token}",
          "Accept"        => "application/vnd.github.v3+json",
          "User-Agent"    => "Comrade/#{Comrade::VERSION}",
        }

        response = make_request("GET", user_url_with_email, nil, headers)
        emails_data = parse_json_response(response)

        # Find primary email
        if emails_data.as_a?
          emails_data.as_a.each do |email_entry|
            if email_entry["primary"]?.try(&.as_bool) && email_entry["verified"]?.try(&.as_bool)
              return email_entry["email"]?.try(&.as_s)
            end
          end
        end

        # Fallback to first verified email
        if emails_data.as_a?
          emails_data.as_a.each do |email_entry|
            if email_entry["verified"]?.try(&.as_bool)
              return email_entry["email"]?.try(&.as_s)
            end
          end
        end

        nil
      end

      # GitHub doesn't have a standard revocation endpoint
      def revoke_token(token : String) : Bool
        false
      end

      # Default scopes for GitHub
      def default_scopes : Array(String)
        ["user:email"]
      end
    end
  end
end
