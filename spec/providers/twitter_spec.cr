require "../spec_helper"

describe Comrade::Providers::Twitter do
  provider = Comrade::Providers::Twitter.new(
    "test_client_id",
    "http://localhost:3000/auth/twitter/callback",
    "test_client_secret"
  )

  describe "#authorization_url" do
    it "returns Twitter's authorization endpoint" do
      provider.authorization_url.should eq("https://twitter.com/i/oauth2/authorize")
    end
  end

  describe "#token_url" do
    it "returns Twitter's token endpoint" do
      provider.token_url.should eq("https://api.twitter.com/2/oauth2/token")
    end
  end

  describe "#user_url" do
    it "returns Twitter's user endpoint" do
      provider.user_url.should eq("https://api.twitter.com/2/users/me")
    end
  end

  describe "#default_scopes" do
    it "returns Twitter's default scopes" do
      provider.default_scopes.should eq(["tweet.read", "users.read"])
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL" do
      url = provider.redirect(
        scopes: ["tweet.read", "users.read"],
        state: "test_state"
      )

      url.should contain("https://twitter.com/i/oauth2/authorize")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Ftwitter%2Fcallback")
      url.should contain("scope=tweet.read+users.read")
      url.should contain("state=test_state")
    end

    it "generates URL with PKCE parameters" do
      # Create provider without client secret for PKCE
      public_provider = Comrade::Providers::Twitter.new(
        "test_client_id",
        "http://localhost:3000/auth/twitter/callback",
        nil
      )

      code_verifier = "test_code_verifier_123"
      url = public_provider.redirect(
        scopes: ["users.read"],
        code_verifier: code_verifier
      )

      url.should contain("code_challenge=")
      url.should contain("code_challenge_method=S256")
    end
  end

  describe "#revoke_token" do
    it "returns boolean for revoke_token" do
      # Twitter supports token revocation
      provider.revoke_token("test_token").should be_a(Bool)
    end
  end
end
