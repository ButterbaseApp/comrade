module Comrade
  # Custom exceptions for OAuth-related errors
  class Exception < ::Exception
  end

  # Raised when OAuth provider configuration is invalid
  class ConfigurationException < Exception
  end

  # Raised when OAuth authorization fails
  class AuthorizationException < Exception
    getter error : String?
    getter description : String?
    getter state : String?

    def initialize(@error : String?, @description : String? = nil, @state : String? = nil)
      super("OAuth authorization failed: #{error}#{description ? " - #{description}" : ""}")
    end
  end

  # Raised when HTTP request to OAuth provider fails
  class HttpException < Exception
    getter response_code : Int32?
    getter response_body : String?

    def initialize(@response_code : Int32?, @response_body : String? = nil)
      super("HTTP request failed#{response_code ? " with status #{response_code}" : ""}#{response_body ? ": #{response_body}" : ""}")
    end
  end

  # Raised when OAuth state is invalid or missing
  class InvalidStateException < Exception
    def initialize(message = "Invalid or missing OAuth state parameter")
      super(message)
    end
  end

  # Raised when OAuth token is invalid or expired
  class InvalidTokenException < Exception
    def initialize(message = "Invalid or expired OAuth token")
      super(message)
    end
  end

  # Raised when requested OAuth scopes are invalid
  class InvalidScopeException < Exception
    getter scopes : Array(String)

    def initialize(@scopes : Array(String))
      super("Invalid OAuth scopes: #{@scopes.join(", ")}")
    end
  end

  # Raised when an operation is not supported by the provider
  class NotSupportedException < Exception
    def initialize(message = "Operation not supported by this OAuth provider")
      super(message)
    end
  end
end
