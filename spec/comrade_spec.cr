require "./spec_helper"

describe Comrade do
  describe "Manager" do
    it "configures HTTP timeout" do
      Comrade.configure do |config|
        config.http_timeout = 60
      end

      Comrade.config.http_timeout.should eq(60)
    end

    it "registers provider from environment variables" do
      ENV["TEST_GITHUB_CLIENT_ID"] = "test_id"
      ENV["TEST_GITHUB_CLIENT_SECRET"] = "test_secret"

      Comrade.register_provider(:github, "TEST_GITHUB_CLIENT_ID", "TEST_GITHUB_CLIENT_SECRET", "http://localhost:3000/callback")

      Comrade.provider_configured?(:github).should be_true
      Comrade.remove_provider("github")
    end

    it "raises exception for unconfigured provider" do
      expect_raises(Comrade::ConfigurationException) do
        Comrade.driver(:github) # Valid enum but not configured
      end
    end
  end

  describe "ProviderConfig" do
    it "creates config from hash" do
      config = Comrade::ProviderConfig.new("github", "test_id", "http://localhost:3000/callback", "test_secret", ["user:email", "read:org"])
      config.name.should eq("github")
      config.client_id.should eq("test_id")
      config.client_secret.should eq("test_secret")
      config.redirect_uri.should eq("http://localhost:3000/callback")
      config.scopes.should eq(["user:email", "read:org"])
    end

    it "validates configuration" do
      valid_config = Comrade::ProviderConfig.new("test", "id", "http://localhost/callback")
      valid_config.valid?.should be_true

      invalid_config = Comrade::ProviderConfig.new("", "", "")
      invalid_config.valid?.should be_false
    end

    it "detects confidential vs public clients" do
      confidential = Comrade::ProviderConfig.new("test", "id", "http://localhost/callback", "secret")
      confidential.confidential_client?.should be_true
      confidential.public_client?.should be_false

      public_client = Comrade::ProviderConfig.new("test", "id", "http://localhost/callback")
      public_client.confidential_client?.should be_false
      public_client.public_client?.should be_true
    end
  end

  describe "Token" do
    it "creates token from JSON response" do
      json = %({
        "access_token": "ya29.test_token",
        "refresh_token": "refresh_token_123",
        "expires_in": 3600,
        "scope": "openid profile email",
        "token_type": "Bearer"
      })

      token = Comrade::Token.from_json(json)
      token.access_token.should eq("ya29.test_token")
      token.refresh_token.should eq("refresh_token_123")
      token.expires_in.should eq(3600)
      token.scope.should eq("openid profile email")
      token.token_type.should eq("Bearer")
    end

    it "detects token expiration" do
      # Create a token with a creation time that makes it expired
      past_time = Time.utc - 2.seconds
      expired_token = Comrade::Token.new("expired", nil, 1, nil, nil, past_time)
      expired_token.expired?.should be_true

      valid_token = Comrade::Token.new("valid", nil, 3600)
      valid_token.expired?.should be_false
    end

    it "detects refreshability" do
      refreshable = Comrade::Token.new("token", "refresh_token")
      refreshable.refreshable?.should be_true

      not_refreshable = Comrade::Token.new("token")
      not_refreshable.refreshable?.should be_false
    end

    it "serializes to/from hash" do
      original = Comrade::Token.new("access", "refresh", 3600, "openid email", "Bearer")

      hash = original.to_h
      restored = Comrade::Token.from_h(hash)

      restored.access_token.should eq(original.access_token)
      restored.refresh_token.should eq(original.refresh_token)
      restored.expires_in.should eq(original.expires_in)
      restored.scope.should eq(original.scope)
      restored.token_type.should eq(original.token_type)
    end
  end

  describe "User" do
    it "creates user from OAuth response" do
      data = JSON.parse(%({
        "id": 12345,
        "login": "testuser",
        "name": "Test User",
        "email": "test@example.com",
        "avatar_url": "https://example.com/avatar.jpg"
      }))

      user = Comrade::User.from_oauth_response(data)
      user.id.should eq("12345")
      user.nickname.should eq("testuser")
      user.name.should eq("Test User")
      user.email.should eq("test@example.com")
      user.avatar.should eq("https://example.com/avatar.jpg")
    end

    it "provides display name fallback" do
      user_with_name = Comrade::User.new("1", "nick", "Full Name")
      user_with_name.display_name.should eq("Full Name")

      user_with_nickname = Comrade::User.new("1", "nick")
      user_with_nickname.display_name.should eq("nick")

      user_with_id = Comrade::User.new("1")
      user_with_id.display_name.should eq("1")
    end

    it "checks for presence of fields" do
      complete_user = Comrade::User.new("1", "nick", "Name", "email@example.com", "avatar.jpg")
      complete_user.has_name?.should be_true
      complete_user.has_email?.should be_true
      complete_user.has_avatar?.should be_true

      minimal_user = Comrade::User.new("1")
      minimal_user.has_name?.should be_false
      minimal_user.has_email?.should be_false
      minimal_user.has_avatar?.should be_false
    end
  end

  describe "HTTP Client" do
    it "creates HTTP client with default settings" do
      client = Comrade::Http::Client.new
      client.user_agent.should eq("Comrade/#{Comrade::VERSION}")
      client.timeout.should eq(30)
      client.follow_redirects?.should be_true
      client.max_redirects.should eq(5)
    end

    it "configures client settings" do
      client = Comrade::Http::Client.new
      client.user_agent = "Custom Agent"
      client.timeout = 60

      client.user_agent.should eq("Custom Agent")
      client.timeout.should eq(60)
    end
  end

  describe "Exceptions" do
    it "creates authorization exception with details" do
      ex = Comrade::AuthorizationException.new("invalid_client", "Client authentication failed", "state123")
      ex.error.should eq("invalid_client")
      ex.description.should eq("Client authentication failed")
      ex.state.should eq("state123")
    end

    it "creates HTTP exception with response info" do
      ex = Comrade::HttpException.new(401, "Unauthorized")
      ex.response_code.should eq(401)
      ex.response_body.should eq("Unauthorized")
    end

    it "creates invalid scope exception" do
      ex = Comrade::InvalidScopeException.new(["read:user", "admin:org"])
      ex.scopes.should eq(["read:user", "admin:org"])
    end
  end
end
