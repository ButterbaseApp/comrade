require "../spec_helper"

describe Comrade::Providers::Facebook do
  provider = Comrade::Providers::Facebook.new(
    "test_client_id",
    "http://localhost:3000/auth/facebook/callback",
    "test_client_secret"
  )

  describe "#authorization_url" do
    it "returns Facebook's authorization endpoint" do
      provider.authorization_url.should eq("https://www.facebook.com/v18.0/dialog/oauth")
    end
  end

  describe "#token_url" do
    it "returns Facebook's token endpoint" do
      provider.token_url.should eq("https://graph.facebook.com/v18.0/oauth/access_token")
    end
  end

  describe "#user_url" do
    it "returns Facebook's user endpoint" do
      provider.user_url.should eq("https://graph.facebook.com/me")
    end
  end

  describe "#default_scopes" do
    it "returns Facebook's default scopes" do
      provider.default_scopes.should eq(["email", "public_profile"])
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL" do
      url = provider.redirect(
        scopes: ["email", "public_profile"],
        state: "test_state"
      )

      url.should contain("https://www.facebook.com/v18.0/dialog/oauth")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fauth%2Ffacebook%2Fcallback")
      url.should contain("scope=email+public_profile")
      url.should contain("state=test_state")
    end

    it "generates URL with PKCE parameters" do
      # Create provider without client secret for PKCE
      public_provider = Comrade::Providers::Facebook.new(
        "test_client_id",
        "http://localhost:3000/auth/facebook/callback",
        nil
      )

      code_verifier = "test_code_verifier_123"
      url = public_provider.redirect(
        scopes: ["email"],
        code_verifier: code_verifier
      )

      url.should contain("code_challenge=")
      url.should contain("code_challenge_method=S256")
    end
  end

  describe "#revoke_token" do
    it "returns false for revoke_token (DELETE not supported)" do
      # Facebook supports token revocation but DELETE method not implemented yet
      provider.revoke_token("test_token").should be_false
    end
  end
end
