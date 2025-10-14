module Comrade
  # Configuration for OAuth providers
  class ProviderConfig
    property name : String
    property client_id : String
    property client_secret : String?
    property redirect_uri : String
    property scopes : Array(String)
    property additional_params : Hash(String, String)

    def initialize(@name : String, @client_id : String, @redirect_uri : String,
                   @client_secret : String? = nil, @scopes : Array(String) = [] of String,
                   @additional_params : Hash(String, String) = {} of String => String)
    end

    # Create config from hash (useful for loading from files)
    def self.from_hash(hash : Hash(String, JSON::Any::Type)) : ProviderConfig
      name = hash["name"]?.try(&.as_s) || raise "Missing provider name"
      client_id = hash["client_id"]?.try(&.as_s) || raise "Missing client_id for provider #{name}"
      redirect_uri = hash["redirect_uri"]?.try(&.as_s) || raise "Missing redirect_uri for provider #{name}"
      client_secret = hash["client_secret"]?.try(&.as_s?)

      scopes = Array(String).new
      if scopes_data = hash["scopes"]?
        if scopes_data.is_a?(Array)
          scopes = scopes_data.map(&.as_s)
        elsif scopes_data.is_a?(String)
          scopes = scopes_data.as_s.split(" ")
        end
      end

      additional_params = Hash(String, String).new
      if params_data = hash["additional_params"]?
        if params_data.is_a?(Hash)
          params_data.as_h.each do |key, value|
            additional_params[key.as_s] = value.as_s?
          end
        end
      end

      new(name, client_id, redirect_uri, client_secret, scopes, additional_params)
    end

    # Create config from environment variables
    #
    # Example:
    #   config = ProviderConfig.from_env("github", "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET")
    def self.from_env(name : String, client_id_env : String, client_secret_env : String? = nil,
                      redirect_uri : String = "", scopes : Array(String) = [] of String) : ProviderConfig
      client_id = ENV[client_id_env]? || raise "Missing environment variable: #{client_id_env}"
      client_secret = client_secret_env ? ENV[client_secret_env]? : nil

      new(name, client_id, redirect_uri, client_secret, scopes)
    end

    # Convert to hash
    def to_h : Hash(String, JSON::Any::Type)
      hash = Hash(String, JSON::Any::Type).new
      hash["name"] = name
      hash["client_id"] = client_id
      hash["redirect_uri"] = redirect_uri
      hash["client_secret"] = client_secret if client_secret
      hash["scopes"] = scopes unless scopes.empty?
      hash["additional_params"] = additional_params unless additional_params.empty?
      hash
    end

    # Check if configuration is valid
    def valid? : Bool
      !name.empty? && !client_id.empty? && !redirect_uri.empty?
    end

    # Check if provider is configured for confidential client (has secret)
    def confidential_client? : Bool
      !(secret = client_secret).nil? && !secret.empty?
    end

    # Check if provider is configured for public client (no secret)
    def public_client? : Bool
      !confidential_client?
    end
  end
end
