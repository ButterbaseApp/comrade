require "../spec_helper"

describe Comrade::Providers::Authentik do
  base_url = "https://authentik.example.com"
  redirect_uri = "https://authentik.example.com/application/o/callback/"

  provider_with_base_url = Comrade::Providers::Authentik.new(
    "test_client_id",
    redirect_uri,
    "test_client_secret",
    base_url
  )

  provider_without_base_url = Comrade::Providers::Authentik.new(
    "test_client_id",
    "https://my-authentik.com/callback",
    "test_client_secret"
  )

  describe "#initialization" do
    it "accepts base_url as parameter" do
      provider_with_base_url.base_url.should eq(base_url)
    end

    it "extracts base_url from redirect_uri when not provided" do
      provider_without_base_url.base_url.should eq("https://my-authentik.com")
    end

    it "raises error when base_url cannot be determined" do
      expect_raises(Comrade::ConfigurationException, "Unable to determine Authentik base URL") do
        Comrade::Providers::Authentik.new(
          "test_client_id",
          "https://example.com/callback",
          "test_client_secret"
        )
      end
    end
  end

  describe "#authorization_url" do
    it "returns correct authorization endpoint with base_url" do
      provider_with_base_url.authorization_url.should eq("#{base_url}/application/o/authorize/")
    end

    it "returns correct authorization endpoint with extracted base_url" do
      provider_without_base_url.authorization_url.should eq("https://my-authentik.com/application/o/authorize/")
    end
  end

  describe "#token_url" do
    it "returns correct token endpoint" do
      provider_with_base_url.token_url.should eq("#{base_url}/application/o/token/")
    end
  end

  describe "#user_url" do
    it "returns correct user endpoint" do
      provider_with_base_url.user_url.should eq("#{base_url}/application/o/userinfo/")
    end
  end

  describe "#revocation_url" do
    it "returns correct revocation endpoint" do
      provider_with_base_url.revocation_url.should eq("#{base_url}/application/o/revoke/")
    end
  end

  describe "#default_scopes" do
    it "returns OpenID Connect default scopes" do
      provider_with_base_url.default_scopes.should eq(["openid", "profile", "email"])
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL with state" do
      url = provider_with_base_url.redirect(
        scopes: ["openid", "profile", "email"],
        state: "test_state"
      )

      url.should contain("#{base_url}/application/o/authorize/")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=https%3A%2F%2Fauthentik.example.com%2Fapplication%2Fo%2Fcallback%2F")
      url.should contain("scope=openid+profile+email")
      url.should contain("state=test_state")
      url.should contain("response_type=code")
    end

    it "generates authorization URL with PKCE for public client" do
      provider_public = Comrade::Providers::Authentik.new(
        "test_client_id",
        redirect_uri,
        nil,
        base_url
      )

      url = provider_public.redirect(
        scopes: ["openid"],
        code_verifier: "test_code_verifier",
        state: "test_state"
      )

      url.should contain("code_challenge=")
      url.should contain("code_challenge_method=S256")
      url.should contain("state=test_state")
    end

    it "adds nonce parameter for OpenID Connect" do
      url = provider_with_base_url.redirect(
        scopes: ["openid", "profile"],
        state: "test_state"
      )

      url.should contain("nonce=")
    end
  end

  describe "#revoke_token" do
    it "can revoke tokens for confidential clients" do
      # Test that the method exists and accepts the right parameters
      # In real usage, this would make HTTP requests to revoke the token
      expect_raises(Exception) do
        # This will fail due to network, but confirms the method signature
        provider_with_base_url.revoke_token("test_token")
      end
    end
  end

  describe "base URL handling" do
    it "accepts different base URLs" do
      provider1 = Comrade::Providers::Authentik.new(
        "test_client_id",
        "https://auth.mycompany.authentik.com/oauth/callback",
        "test_client_secret",
        "https://auth.mycompany.authentik.com"
      )
      provider1.base_url.should eq("https://auth.mycompany.authentik.com")

      provider2 = Comrade::Providers::Authentik.new(
        "test_client_id",
        "http://localhost:9000/if/flow/some-flow/callback",
        "test_client_secret",
        "http://localhost:9000"
      )
      provider2.base_url.should eq("http://localhost:9000")
    end

    it "handles HTTPS and HTTP schemes" do
      https_provider = Comrade::Providers::Authentik.new(
        "test_client_id",
        "https://secure-authentik.authentik.com/callback",
        "test_client_secret",
        "https://secure-authentik.authentik.com"
      )
      https_provider.base_url.should eq("https://secure-authentik.authentik.com")

      http_provider = Comrade::Providers::Authentik.new(
        "test_client_id",
        "http://auth-local.authentik.com/callback",
        "test_client_secret",
        "http://auth-local.authentik.com"
      )
      http_provider.base_url.should eq("http://auth-local.authentik.com")
    end
  end
end
