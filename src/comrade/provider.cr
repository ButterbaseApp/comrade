module Comrade
  # Enum for supported OAuth providers
  enum Provider
    Github
    Google
    Facebook
    Twitter
    Discord
    Workos
    Authentik

    # Convert the enum to a provider instance
    #
    # Example:
    #   provider = Provider::Github.to_provider(config)
    def to_provider(config : ProviderConfig) : Providers::BaseProvider
      case self
      when .github?
        Providers::GitHub.new(config.client_id, config.redirect_uri, config.client_secret)
      when .google?
        Providers::Google.new(config.client_id, config.redirect_uri, config.client_secret)
      when .facebook?
        Providers::Facebook.new(config.client_id, config.redirect_uri, config.client_secret)
      when .twitter?
        Providers::Twitter.new(config.client_id, config.redirect_uri, config.client_secret)
      when .discord?
        Providers::Discord.new(config.client_id, config.redirect_uri, config.client_secret)
      when .workos?
        Providers::WorkOS.new(config.client_id, config.redirect_uri, config.client_secret)
      when .authentik?
        base_url = config.additional_params["base_url"]?
        Providers::Authentik.new(config.client_id, config.redirect_uri, config.client_secret, base_url)
      else
        raise ConfigurationException.new("Unknown provider: #{self}")
      end
    end

    # Get the provider name as a string
    def name : String
      case self
      when .github?    then "github"
      when .google?    then "google"
      when .facebook?  then "facebook"
      when .twitter?   then "twitter"
      when .discord?   then "discord"
      when .workos?    then "workos"
      when .authentik? then "authentik"
      else
        self.to_s.downcase
      end
    end
  end
end
