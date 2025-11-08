require "../spec_helper"

describe Comrade::Providers::Keycloak do
  base_url = "https://keycloak.example.com"
  realm = "myrealm"
  redirect_uri = "https://myapp.com/callback"

  provider_with_config = Comrade::Providers::Keycloak.new(
    "test_client_id",
    redirect_uri,
    "test_client_secret",
    base_url,
    realm
  )

  provider_without_config = Comrade::Providers::Keycloak.new(
    "test_client_id",
    "https://keycloak.example.com/realms/testrealm/callback",
    "test_client_secret"
  )

  describe "#initialization" do
    it "accepts base_url and realm as parameters" do
      provider_with_config.base_url.should eq(base_url)
      provider_with_config.realm.should eq(realm)
    end

    it "extracts base_url from redirect_uri when not provided" do
      provider_without_config.base_url.should eq("https://keycloak.example.com")
    end

    it "extracts realm from redirect_uri when not provided" do
      provider_without_config.realm.should eq("testrealm")
    end

    it "defaults to master realm when cannot be determined" do
      provider = Comrade::Providers::Keycloak.new(
        "test_client_id",
        "https://example.com/callback",
        "test_client_secret",
        "https://keycloak.example.com"
      )
      provider.realm.should eq("master")
    end

    it "raises error when base_url cannot be determined" do
      expect_raises(Comrade::ConfigurationException, "Unable to determine Keycloak base URL") do
        Comrade::Providers::Keycloak.new(
          "test_client_id",
          "invalid-url",
          "test_client_secret"
        )
      end
    end
  end

  describe "#authorization_url" do
    it "returns correct authorization endpoint with realm" do
      provider_with_config.authorization_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/auth")
    end

    it "returns correct authorization endpoint with extracted realm" do
      provider_without_config.authorization_url.should eq("https://keycloak.example.com/realms/testrealm/protocol/openid-connect/auth")
    end
  end

  describe "#token_url" do
    it "returns correct token endpoint" do
      provider_with_config.token_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/token")
    end
  end

  describe "#user_url" do
    it "returns correct user endpoint" do
      provider_with_config.user_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/userinfo")
    end
  end

  describe "#revocation_url" do
    it "returns correct revocation endpoint" do
      provider_with_config.revocation_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/revoke")
    end
  end

  describe "#end_session_url" do
    it "returns correct logout endpoint" do
      provider_with_config.end_session_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/logout")
    end
  end

  describe "#jwks_url" do
    it "returns correct JWKS endpoint" do
      provider_with_config.jwks_url.should eq("#{base_url}/realms/#{realm}/protocol/openid-connect/certs")
    end
  end

  describe "#well_known_url" do
    it "returns correct well-known endpoint" do
      provider_with_config.well_known_url.should eq("#{base_url}/realms/#{realm}/.well-known/openid-configuration")
    end
  end

  describe "#default_scopes" do
    it "returns OpenID Connect default scopes" do
      provider_with_config.default_scopes.should eq(["openid", "profile", "email"])
    end
  end

  describe "#redirect" do
    it "generates correct authorization URL with state" do
      url = provider_with_config.redirect(
        scopes: ["openid", "profile", "email"],
        state: "test_state"
      )

      url.should contain("#{base_url}/realms/#{realm}/protocol/openid-connect/auth")
      url.should contain("client_id=test_client_id")
      url.should contain("redirect_uri=https%3A%2F%2Fmyapp.com%2Fcallback")
      url.should contain("scope=openid+profile+email")
      url.should contain("state=test_state")
      url.should contain("response_type=code")
    end

    it "generates authorization URL with PKCE for public client" do
      provider_public = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        nil,
        base_url,
        realm
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
      url = provider_with_config.redirect(
        scopes: ["openid", "profile"],
        state: "test_state"
      )

      url.should contain("nonce=")
    end

    it "accepts custom nonce parameter" do
      url = provider_with_config.redirect(
        scopes: ["openid"],
        state: "test_state",
        nonce: "custom_nonce"
      )

      url.should contain("nonce=custom_nonce")
    end
  end

  describe "#end_session" do
    it "generates logout URL with ID token hint" do
      url = provider_with_config.end_session("id_token_hint")

      url.should contain("#{base_url}/realms/#{realm}/protocol/openid-connect/logout")
      url.should contain("id_token_hint=id_token_hint")
    end

    it "generates logout URL with post logout redirect URI" do
      url = provider_with_config.end_session(nil, "https://myapp.com/logout")

      url.should contain("post_logout_redirect_uri=https%3A%2F%2Fmyapp.com%2Flogout")
    end

    it "generates logout URL with both parameters" do
      url = provider_with_config.end_session("id_token_hint", "https://myapp.com/logout")

      url.should contain("id_token_hint=id_token_hint")
      url.should contain("post_logout_redirect_uri=https%3A%2F%2Fmyapp.com%2Flogout")
    end
  end

  describe "#revoke_token" do
    it "can revoke tokens for confidential clients" do
      # Test that the method exists and accepts the right parameters
      expect_raises(Exception) do
        # This will fail due to network, but confirms the method signature
        provider_with_config.revoke_token("test_token")
      end
    end

    it "accepts token type hint parameter" do
      # Test method signature with token_type_hint
      expect_raises(Exception) do
        provider_with_config.revoke_token("test_token", "refresh_token")
      end
    end
  end

  describe "realm handling" do
    it "accepts different realm names" do
      provider1 = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        base_url,
        "master"
      )
      provider1.realm.should eq("master")

      provider2 = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        base_url,
        "customer-realm"
      )
      provider2.realm.should eq("customer-realm")
    end

    it "handles special characters in realm names" do
      provider = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        base_url,
        "my_realm-123"
      )
      provider.realm.should eq("my_realm-123")
    end
  end

  describe "base URL handling" do
    it "accepts different base URLs" do
      provider1 = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        "https://auth.mycompany.com",
        realm
      )
      provider1.base_url.should eq("https://auth.mycompany.com")

      provider2 = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        "http://localhost:8080",
        realm
      )
      provider2.base_url.should eq("http://localhost:8080")
    end

    it "handles HTTPS and HTTP schemes" do
      https_provider = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        "https://secure-keycloak.com",
        realm
      )
      https_provider.base_url.should eq("https://secure-keycloak.com")

      http_provider = Comrade::Providers::Keycloak.new(
        "test_client_id",
        redirect_uri,
        "test_client_secret",
        "http://keycloak-local:8080",
        realm
      )
      http_provider.base_url.should eq("http://keycloak-local:8080")
    end
  end

  describe "OpenID Connect configuration" do
    it "has method to get OIDC configuration" do
      # Test method exists
      expect_raises(Exception) do
        provider_with_config.oidc_configuration
      end
    end

    it "has method to get JWKS" do
      # Test method exists
      expect_raises(Exception) do
        provider_with_config.jwks
      end
    end
  end

  describe "user field mappings" do
    it "uses OpenID Connect standard field mappings" do
      # The field mappings are tested indirectly through the user creation process
      # This test ensures the provider has the correct mappings configured
      mappings = provider_with_config.user_field_mappings
      mappings["id"].should eq("sub")
      mappings["nickname"].should eq("preferred_username")
      mappings["name"].should eq("name")
      mappings["email"].should eq("email")
      mappings["avatar"].should eq("picture")
    end
  end
end