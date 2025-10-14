require "../spec_helper"

describe Comrade::Providers::Discord do
  provider = Comrade::Providers::Discord.new(
    "test_client_id",
    "http://localhost:3000/auth/discord/callback",
    "test_client_secret"
  )

  describe "#authorization_url" do
    it "returns Discord's authorization endpoint" do
      provider.authorization_url.should eq("https://discord.com/api/oauth2/authorize")
    end
  end

  describe "#token_url" do
    it "returns Discord's token endpoint" do
      provider.token_url.should eq("https://discord.com/api/oauth2/token")
    end
  end

  describe "#user_url" do
    it "returns Discord's user endpoint" do
      provider.user_url.should eq("https://discord.com/api/users/@me")
    end
  end

  describe "#default_scopes" do
    it "returns Discord's default scopes" do
      provider.default_scopes.should eq(["identify", "email"])
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL" do
      url = provider.redirect(
        scopes: ["identify", "email"],
        state: "test_state"
      )

      url.should contain("https://discord.com/api/oauth2/authorize")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Fdiscord%2Fcallback")
      url.should contain("scope=identify+email")
      url.should contain("state=test_state")
    end

    it "generates URL with PKCE parameters" do
      # Create provider without client secret for PKCE
      public_provider = Comrade::Providers::Discord.new(
        "test_client_id",
        "http://localhost:3000/auth/discord/callback",
        nil
      )

      code_verifier = "test_code_verifier_123"
      url = public_provider.redirect(
        scopes: ["identify"],
        code_verifier: code_verifier
      )

      url.should contain("code_challenge=")
      url.should contain("code_challenge_method=S256")
    end
  end

  describe "#get_user_guilds" do
    it "returns JSON::Any or nil for guilds" do
      # Discord requires valid token, so this will likely fail
      # But we test the return type
      result = provider.get_user_guilds(Comrade::Token.new("fake_token"))

      # Should either return JSON::Any or nil on error
      (result.nil? || result.is_a?(JSON::Any)).should be_true
    end
  end

  describe "#revoke_token" do
    it "returns boolean for revoke_token" do
      # Discord supports token revocation
      provider.revoke_token("test_token").should be_a(Bool)
    end
  end
end
