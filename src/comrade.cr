require "./comrade/**"

# Comrade - A Crystal OAuth library inspired by Laravel Socialite
#
# Comrade provides a simple, elegant interface for OAuth authentication with
# various providers like GitHub, Google, Facebook, and more.
#
# Example:
#   github = Comrade.driver(:github)
#   auth_url = github.redirect(scopes: ["user:email"])
#   user = github.user(callback_code)
module Comrade
  VERSION = "0.1.0"

  # Main manager for accessing OAuth providers
  #
  # Returns a provider instance for the given driver
  #
  # Example:
  #   github = Comrade.driver(:github)
  #   google = Comrade.driver(:google)
  def self.driver(name : Symbol)
    Manager.instance.driver(name)
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
  def self.register_provider(name : Symbol, client_id_env : String, client_secret_env : String? = nil,
                             redirect_uri : String = "", scopes : Array(String) = [] of String)
    Manager.instance.register_provider(name.to_s, client_id_env, client_secret_env, redirect_uri, scopes)
  end

  # Check if a provider is configured
  def self.provider_configured?(name : Symbol) : Bool
    Manager.instance.provider_configured?(name)
  end

  # Remove a provider configuration
  def self.remove_provider(name : String)
    Manager.instance.remove_provider(name)
  end
end
