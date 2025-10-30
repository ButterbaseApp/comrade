require "./comrade/**"

# Comrade - A Crystal OAuth library inspired by Laravel Socialite
#
# Comrade provides a simple, elegant interface for OAuth authentication with
# various providers like GitHub, Google, Facebook, and more.
#
# Example:
#   github = Comrade.driver(Provider::Github)
#   auth_url = github.redirect(scopes: ["user:email"])
#   user = github.user(callback_code)
module Comrade
  VERSION = "0.1.0"

  # Main manager for accessing OAuth providers
  #
  # Returns a provider instance for the given driver
  #
  # Examples:
  #   github = Comrade.driver(Provider::Github)
  #   google = Comrade.driver(:google)  # Symbol automatically converts to Provider::Google
  def self.driver(provider : Provider)
    Manager.instance.driver(provider)
  end

  # Configure global settings
  #
  # Example:
  #   Comrade.configure { |config| config.http_timeout = 30 }
  def self.configure(&block : Manager -> _)
    Manager.instance.configure(&block)
  end

  # Get the current manager configuration
  def self.config
    Manager.instance.config
  end

  # Register a provider configuration from environment variables
  #
  # Examples:
  #   Comrade.register_provider(Provider::Github, "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET")
  #   Comrade.register_provider(:google, "GOOGLE_CLIENT_ID")  # Symbol automatically converts
  def self.register_provider(provider : Provider, client_id_env : String, client_secret_env : String? = nil,
                             redirect_uri : String = "", scopes : Array(String) = [] of String)
    Manager.instance.register_provider(provider.name, client_id_env, client_secret_env, redirect_uri, scopes)
  end

  # Check if a provider is configured
  #
  # Examples:
  #   Comrade.provider_configured?(Provider::Github)
  #   Comrade.provider_configured?(:google)  # Symbol automatically converts
  def self.provider_configured?(provider : Provider) : Bool
    Manager.instance.provider_configured?(provider.name)
  end

  # Remove a provider configuration
  def self.remove_provider(name : String)
    Manager.instance.remove_provider(name)
  end
end
