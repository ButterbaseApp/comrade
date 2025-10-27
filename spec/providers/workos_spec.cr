require "../spec_helper"

describe Comrade::Providers::WorkOS do
  provider = Comrade::Providers::WorkOS.new(
    "test_client_id",
    "http://localhost:3000/auth/workos/callback",
    "test_client_secret"
  )

  describe "#authorization_url" do
    it "returns WorkOS's authorization endpoint" do
      provider.authorization_url.should eq("https://api.workos.com/sso/authorize")
    end
  end

  describe "#token_url" do
    it "returns WorkOS's token endpoint" do
      provider.token_url.should eq("https://api.workos.com/sso/token")
    end
  end

  describe "#user_url" do
    it "returns WorkOS's user endpoint" do
      provider.user_url.should eq("https://api.workos.com/sso/profile")
    end
  end

  describe "#default_scopes" do
    it "returns empty array for WorkOS default scopes" do
      provider.default_scopes.should eq([] of String)
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL with connection" do
      url = provider.redirect(
        connection: "conn_123456789",
        state: "test_state"
      )

      url.should contain("https://api.workos.com/sso/authorize")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fworkos%2Fcallback")
      url.should contain("connection=conn_123456789")
      url.should contain("state=test_state")
      url.should contain("response_type=code")
    end

    it "generates correct authorization URL with organization" do
      url = provider.redirect(
        organization: "org_123456789",
        state: "test_state"
      )

      url.should contain("organization=org_123456789")
      url.should contain("state=test_state")
    end

    it "generates correct authorization URL with provider" do
      url = provider.redirect(
        provider: "GoogleOAuth",
        state: "test_state"
      )

      url.should contain("provider=GoogleOAuth")
      url.should contain("state=test_state")
    end

    it "generates authorization URL with additional parameters" do
      url = provider.redirect(
        connection: "conn_123456789",
        domain_hint: "example.com",
        login_hint: "user@example.com",
        scopes: ["profile", "email"]
      )

      url.should contain("connection=conn_123456789")
      url.should contain("domain_hint=example.com")
      url.should contain("login_hint=user%40example.com")
      url.should contain("scope=profile+email")
    end

    it "raises error when no identifier is provided" do
      expect_raises(ArgumentError, "One of connection, organization, or provider must be specified for WorkOS authorization") do
        provider.redirect
      end
    end

    it "raises error for invalid provider" do
      expect_raises(ArgumentError, "Invalid provider 'InvalidProvider'. Valid providers: GoogleOAuth, MicrosoftOAuth, GitHubOAuth, AppleOAuth") do
        provider.redirect(provider: "InvalidProvider")
      end
    end
  end

  describe "#refresh_token" do
    it "raises NotSupportedException" do
      expect_raises(Comrade::NotSupportedException, "WorkOS does not support token refresh") do
        provider.refresh_token("refresh_token")
      end
    end
  end

  describe "#revoke_token" do
    it "returns boolean for revoke_token (without client secret returns false)" do
      provider_without_secret = Comrade::Providers::WorkOS.new(
        "test_client_id",
        "http://localhost:3000/auth/workos/callback"
      )

      result = provider_without_secret.revoke_token("test_token")
      result.should be_false
    end
  end

  describe "#valid_providers" do
    it "returns list of supported OAuth providers" do
      # Test that redirect works with each valid provider
      valid_providers = ["GoogleOAuth", "MicrosoftOAuth", "GitHubOAuth", "AppleOAuth"]

      valid_providers.each do |provider_name|
        url = provider.redirect(provider: provider_name)
        url.should contain("provider=#{provider_name}")
      end
    end
  end
end
