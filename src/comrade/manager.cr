require "./providers/base_provider"

module Comrade
  # Manager class for handling OAuth providers and configuration
  class Manager
    @@instance = Manager.new

    def self.instance
      @@instance
    end

    @providers : Hash(String, Comrade::Providers::BaseProvider)
    @configs : Hash(String, ProviderConfig)
    @http_timeout : Int32

    def initialize
      @providers = Hash(String, Comrade::Providers::BaseProvider).new
      @configs = Hash(String, ProviderConfig).new
      @http_timeout = 30
    end

    # Configure global settings
    def configure(& : Manager -> _)
      yield self
    end

    # Set HTTP timeout for all providers
    def http_timeout=(timeout : Int32)
      @http_timeout = timeout
      @providers.each do |_, provider|
        provider.http_client.timeout = timeout
      end
    end

    # Get HTTP timeout
    def http_timeout : Int32
      @http_timeout
    end

    # Get current configuration
    def config : Manager
      self
    end

    # Register a provider configuration
    def register_provider(name : String, config : ProviderConfig)
      @configs[name.to_s] = config
    end

    # Register a provider configuration from hash
    def register_provider(name : String, hash : Hash(String, JSON::Any::Type))
      config = ProviderConfig.from_hash(hash)
      register_provider(name, config)
    end

    # Register a provider configuration from environment variables
    def register_provider(name : String, client_id_env : String, client_secret_env : String? = nil,
                          redirect_uri : String = "", scopes : Array(String) = [] of String)
      config = ProviderConfig.from_env(name, client_id_env, client_secret_env, redirect_uri, scopes)
      register_provider(name, config)
    end

    # Get a provider instance by name
    def driver(name : Symbol) : Comrade::Providers::BaseProvider
      provider_name = name.to_s
      provider = @providers[provider_name]?

      if provider.nil?
        config = @configs[provider_name]?
        raise ConfigurationException.new("Provider '#{provider_name}' not configured") unless config

        provider = create_provider(name, config)
        provider.http_client.timeout = @http_timeout
        @providers[provider_name] = provider
      end

      provider
    end

    # Create provider instance based on name
    private def create_provider(name : Symbol, config : ProviderConfig) : Comrade::Providers::BaseProvider
      case name
      when :github
        Providers::GitHub.new(config.client_id, config.redirect_uri, config.client_secret)
      when :google
        Providers::Google.new(config.client_id, config.redirect_uri, config.client_secret)
      when :facebook
        Providers::Facebook.new(config.client_id, config.redirect_uri, config.client_secret)
      when :twitter
        Providers::Twitter.new(config.client_id, config.redirect_uri, config.client_secret)
      when :discord
        Providers::Discord.new(config.client_id, config.redirect_uri, config.client_secret)
      else
        raise ConfigurationException.new("Unknown provider: #{name}")
      end
    end

    # Check if a provider is configured
    def provider_configured?(name : Symbol) : Bool
      @configs.has_key?(name.to_s)
    end

    # Get all configured provider names
    def configured_providers : Array(String)
      @configs.keys
    end

    # Remove a provider configuration
    def remove_provider(name : String)
      @configs.delete(name)
      @providers.delete(name)
    end

    # Clear all provider configurations
    def clear_providers
      @configs.clear
      @providers.clear
    end

    # Load configuration from hash (useful for loading from files)
    def load_config(hash : Hash(String, JSON::Any::Type))
      hash.each do |name, config_hash|
        if config_hash.is_a?(Hash)
          register_provider(name, config_hash.as_h)
        end
      end
    end

    # Get provider configuration
    def get_provider_config(name : String) : ProviderConfig?
      @configs[name]?
    end
  end
end
