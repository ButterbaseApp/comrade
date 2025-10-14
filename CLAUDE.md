# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Comrade is a Crystal OAuth library inspired by Laravel Socialite. It provides a simple, elegant interface for OAuth authentication with various providers like GitHub, Google, and more. The library follows a singleton pattern with a centralized Manager class for provider configuration and instance management.

## Development Commands

### Installation and Dependencies
```bash
# Install dependencies
shards install

# Update dependencies
shards update
```

### Building and Testing
```bash
# Run tests
crystal spec

# Run specific test file
crystal spec spec/comrade_spec.cr

# Build the library (creates .a file in lib/)
crystal build src/comrade.cr --link

# Compile with release optimization
crystal build src/comrade.cr --release --no-debug
```

### Linting and Code Quality
```bash
# Run static analysis with Ameba
ameba

# Run Ameba with specific config file (if exists)
ameba --config .ameba.yml
```

## Architecture Overview

### Core Components

**Manager (Singleton Pattern)**
- Central configuration and provider registry
- `src/comrade/manager.cr:6` - Singleton instance with `@@instance`
- Handles provider creation, caching, and HTTP timeout management
- Thread-safe provider instantiation with lazy loading

**Provider System**
- `BaseProvider` abstract class defining the OAuth interface
- `OAuth2Provider` base implementation for OAuth 2.0 flows
- Concrete providers: `GitHub`, `Google` (in `src/comrade/providers/`)
- Provider factory pattern in `Manager#create_provider` (`manager.cr:81`)

**Configuration Management**
- `ProviderConfig` class for provider-specific settings
- Environment variable support via `from_env` method
- Hash-based configuration loading for file-based configs

**Data Models**
- `User` - Represents authenticated user with field mapping support
- `Token` - OAuth token with expiration and refresh handling
- Both models support JSON serialization and raw data access

### Key Design Patterns

1. **Singleton Manager** - Centralized provider management
2. **Factory Pattern** - Dynamic provider creation based on name
3. **Template Method** - BaseProvider defines OAuth flow, providers customize endpoints
4. **Strategy Pattern** - Different authentication strategies per provider
5. **Configuration Builder** - Flexible configuration from multiple sources

### OAuth Flow Architecture

1. **Authorization**: `provider.redirect()` generates auth URL with state/PKCE
2. **Token Exchange**: `provider.get_token()` exchanges code for access token
3. **User Data**: `provider.get_user()` fetches user profile using token
4. **Token Management**: Built-in refresh, expiration checking, and revocation

## Provider Implementation

### Adding New Providers

1. Create provider class inheriting from `OAuth2Provider` or `BaseProvider`
2. Implement required abstract methods:
   - `authorization_url`
   - `token_url`
   - `user_url`
   - `user_field_mappings` (optional)
3. Add provider case to `Manager#create_provider` (`manager.cr:81`)
4. Register provider configuration via `Manager#register_provider`

### Provider-Specific Features

**GitHub**
- Requires separate API call for email (`user_url_with_email`)
- No token revocation support
- Default scopes: `["user:email"]`

**Google**
- OpenID Connect support with `openid` scope
- PKCE support for public clients
- Token revocation endpoint available
- Default scopes: `["openid", "profile", "email"]`

## Configuration

### Environment Variables
```crystal
Comrade.register_provider(:github, "GITHUB_CLIENT_ID", "GITHUB_CLIENT_SECRET")
```

### Hash Configuration
```crystal
config = {
  "name"         => "github",
  "client_id"    => "your-client-id",
  "client_secret" => "your-secret",
  "redirect_uri" => "http://localhost:3000/callback",
  "scopes"       => ["user:email"]
}
Comrade.register_provider(:github, config)
```

### Global Configuration
```crystal
Comrade.configure do |config|
  config.http_timeout = 30
end
```

## Testing

Test files should be placed in `spec/` directory. The project uses Crystal's built-in testing framework with `spec/spec_helper.cr` for common setup.

## Development Notes

- Crystal version: `>= 1.17.1` (currently using 1.17.1)
- Code style follows EditorConfig settings (2-space indentation)
- Ameba is used for static analysis linting
- The library is designed as a shard (Crystal library) not a standalone application
- HTTP requests use Crystal's built-in `HTTP::Client`
- All OAuth responses are parsed as JSON with proper error handling