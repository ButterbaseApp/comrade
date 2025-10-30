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

    # Get a provider instance by enum
    def driver(provider : Provider) : Comrade::Providers::BaseProvider
      provider_name = provider.name
      provider_instance = @providers[provider_name]?

      if provider_instance.nil?
        config = @configs[provider_name]?
        raise ConfigurationException.new("Provider '#{provider_name}' not configured") unless config

        provider_instance = provider.to_provider(config)
        provider_instance.http_client.timeout = @http_timeout
        @providers[provider_name] = provider_instance
      end

      provider_instance
    end

    
    # Check if a provider is configured
    def provider_configured?(name : String) : Bool
      @configs.has_key?(name)
    end

    # Check if a provider is configured (legacy symbol support)
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
