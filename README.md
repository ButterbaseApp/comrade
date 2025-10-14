# Comrade

[![Crystal shard](https://img.shields.io/badge/shard-comrade-blue.svg)](https://github.com/watzon/comrade)
[![CI Status](https://github.com/ButterbaseApp/comrade/actions/workflows/badge.yml/badge.svg)](https://github.com/ButterbaseApp/comrade/actions/workflows/badge.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> A Crystal OAuth library inspired by Laravel Socialite for simple, elegant OAuth authentication.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
  - [Basic Setup](#basic-setup)
  - [Provider Configuration](#provider-configuration)
  - [OAuth Flow](#oauth-flow)
  - [Supported Providers](#supported-providers)
- [API](#api)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## Background

Comrade provides a simple, elegant interface for OAuth authentication with various providers like GitHub, Google, and more. Inspired by Laravel Socialite, it offers a fluent API for handling OAuth flows in Crystal applications.

The library follows a singleton pattern with a centralized Manager for provider configuration and supports both confidential and public client flows, including PKCE for enhanced security.

## Install

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  comrade:
    github: watzon/comrade
    version: ~> 0.1.0
```

Run `shards install` to install the dependency.

## Usage

### Basic Setup

```crystal
require "comrade"

# Configure a provider from environment variables
Comrade.register_provider(
  :github,
  "GITHUB_CLIENT_ID",
  "GITHUB_CLIENT_SECRET",
  "http://localhost:3000/auth/github/callback",
  ["user:email"]
)

# Or configure globally
Comrade.configure do |config|
  config.http_timeout = 30
end
```

### Provider Configuration

#### Environment Variables

```crystal
# Configure GitHub OAuth
Comrade.register_provider(
  :github,
  "GITHUB_CLIENT_ID",
  "GITHUB_CLIENT_SECRET",
  "http://localhost:3000/auth/github/callback",
  ["user:email"]
)

# Configure Google OAuth
Comrade.register_provider(
  :google,
  "GOOGLE_CLIENT_ID",
  "GOOGLE_CLIENT_SECRET",
  "http://localhost:3000/auth/google/callback",
  ["openid", "profile", "email"]
)
```

#### Hash Configuration

```crystal
config = {
  "name"         => "github",
  "client_id"    => "your-github-client-id",
  "client_secret" => "your-github-client-secret",
  "redirect_uri" => "http://localhost:3000/auth/github/callback",
  "scopes"       => ["user:email"]
}

Comrade.register_provider(:github, config)
```

### OAuth Flow

#### 1. Redirect User for Authorization

```crystal
# Get provider instance
github = Comrade.driver(:github)

# Generate authorization URL with state parameter
auth_url = github.redirect(
  scopes: ["user:email"],
  state: "random-state-string"
)

# Redirect user to auth_url
redirect_to auth_url
```

#### 2. Handle Callback and Get User

```crystal
# After user authorizes, exchange code for token
code = params["code"]
state = params["state"]

# Get access token
token = github.get_token(code, state: state)

# Get user information
user = github.user(token)

puts "User: #{user.name} (#{user.email})"
puts "Avatar: #{user.avatar}"
```

#### 3. Token Management

```crystal
# Check if token is expired
if token.expired?
  # Refresh token if available
  if token.refreshable?
    token = github.refresh_token(token.refresh_token.not_nil!)
  end
end

# Revoke token (if supported by provider)
github.revoke_token(token.access_token)
```

### Supported Providers

#### Provider Implementation Status

- [x] **GitHub** - OAuth 2.0 with email fetching, basic scopes
- [x] **Google** - OAuth 2.0 + OpenID Connect, PKCE support, token revocation
- [x] **Facebook/Meta** - OAuth 2.0, Graph API, permissions system
- [x] **Twitter/X** - OAuth 2.0, user profile and tweets access
- [x] **Discord** - OAuth 2.0, rich user/guild data
- [ ] **Microsoft** - OAuth 2.0 + OpenID Connect, Azure AD support
- [ ] **Slack** - OAuth 2.0, workspace integration
- [ ] **LinkedIn** - OAuth 2.0, professional profile data
- [ ] **Apple** - OAuth 2.0 + OpenID Connect, Sign in with Apple
- [ ] **GitLab** - OAuth 2.0, developer platform integration
- [ ] **Bitbucket** - OAuth 2.0, Atlassian ecosystem
- [ ] **Spotify** - OAuth 2.0, music and user data
- [ ] **Strava** - OAuth 2.0, fitness and activity data

#### GitHub

```crystal
github = Comrade.driver(:github)
auth_url = github.redirect(scopes: ["user", "repo"])
user = github.user(token)

# GitHub automatically fetches primary email if not included
# Default scopes: ["user:email"]
```

#### Google

```crystal
google = Comrade.driver(:google)
auth_url = google.redirect(
  scopes: ["openid", "profile", "email"],
  # Google supports offline access for refresh tokens
  code_verifier: google.generate_code_verifier  # PKCE for public clients
)
user = google.user(token)

# Default scopes: ["openid", "profile", "email"]
# Supports token revocation
```

#### Facebook/Meta

```crystal
facebook = Comrade.driver(:facebook)
auth_url = facebook.redirect(
  scopes: ["email", "public_profile"],
  state: "random-state-string"
)
user = facebook.user(token)

# Facebook uses Graph API for user data
# Default scopes: ["email", "public_profile"]
# Supports token revocation via permission removal
# Note: Requires Facebook App with OAuth configuration
```

#### Twitter/X

```crystal
twitter = Comrade.driver(:twitter)
auth_url = twitter.redirect(
  scopes: ["tweet.read", "users.read"],
  state: "random-state-string"
)
user = twitter.user(token)

# Twitter/X uses OAuth 2.0 with v2 API
# Default scopes: ["tweet.read", "users.read"]
# Supports token revocation
# Note: Requires Twitter Developer App with OAuth 2.0 enabled
```

#### Discord

```crystal
discord = Comrade.driver(:discord)
auth_url = discord.redirect(
  scopes: ["identify", "email", "guilds"],
  state: "random-state-string"
)
user = discord.user(token)

# Get user's guilds (servers)
guilds = discord.get_user_guilds(token)

# Discord uses OAuth 2.0 with rich user/guild data
# Default scopes: ["identify", "email"]
# Supports avatar URLs, guild information, and token revocation
# Note: Requires Discord Application with OAuth2 configured
```

## API

### Comrade Module

- `Comrade.driver(name : Symbol)` - Get configured provider instance
- `Comrade.configure(&block)` - Configure global settings
- `Comrade.register_provider(name, ...)` - Register provider configuration
- `Comrade.provider_configured?(name)` - Check if provider is configured
- `Comrade.remove_provider(name)` - Remove provider configuration

### Provider Methods

All providers implement the following interface:

- `redirect(scopes, state, **options)` - Generate authorization URL
- `get_token(code, state, **options)` - Exchange code for access token
- `get_user(token)` - Get user information using access token
- `refresh_token(refresh_token, **options)` - Refresh access token
- `revoke_token(token)` - Revoke access token (if supported)

### User Object

```crystal
user.id        # String - User ID from provider
user.nickname  # String? - Username/handle
user.name      # String? - Full display name
user.email     # String? - Email address
user.avatar    # String? - Avatar URL
user.raw       # JSON::Any - Raw provider response

# Helper methods
user.has_email?      # Bool
user.has_name?       # Bool
user.has_avatar?     # Bool
user.display_name    # String - name || nickname || id
user.to_h            # Hash - User data as hash
user.get_raw_field("field") # Get raw field from provider response
```

### Token Object

```crystal
token.access_token   # String - OAuth access token
token.refresh_token  # String? - Refresh token (if available)
token.expires_in     # Int32? - Token lifetime in seconds
token.scope          # String? - Granted scopes
token.token_type     # String? - Token type (usually "Bearer")
token.created_at     # Time - Token creation time

# Helper methods
token.expired?           # Bool
token.expiring_soon?     # Bool (within 5 minutes by default)
token.expires_at         # Time?
token.refreshable?       # Bool
token.to_h              # Hash - Token data as hash
```

## Security

- **State Parameter**: Always use state parameters to prevent CSRF attacks
- **PKCE Support**: Use PKCE for public clients (mobile apps, SPAs)
- **Token Storage**: Store tokens securely, consider encryption
- **HTTPS**: Always use HTTPS in production for OAuth redirects
- **Scope Limitation**: Request only necessary scopes
- **Token Expiration**: Check token expiration before use

```crystal
# Secure example with state and PKCE
provider = Comrade.driver(:google)
state = provider.generate_state
code_verifier = provider.generate_code_verifier

# Store state and code_verifier in session
session["oauth_state"] = state
session["code_verifier"] = code_verifier

auth_url = provider.redirect(
  scopes: ["openid", "profile", "email"],
  state: state,
  code_verifier: code_verifier
)

# In callback, verify state first
if params["state"] != session["oauth_state"]
  raise "Invalid state parameter"
end
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development

1. Clone the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Install dependencies (`shards install`)
4. Run tests (`crystal spec`)
5. Run linter (`ameba`)
6. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
7. Push to the branch (`git push origin my-new-feature`)
8. Create a new Pull Request

### Commit Messages

This project follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification. Commit messages should be structured as follows:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Common types:**
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Code formatting changes (white-space, etc)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files

**Examples:**
- `feat: add GitHub OAuth provider`
- `fix(auth): resolve token expiration issue`
- `docs: update installation instructions`
- `ci: add multi-version Crystal testing`

### Running Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/comrade_spec.cr

# Run with coverage
crystal spec --coverage
```

### Code Style

This project uses Ameba for static analysis. Run `ameba` to check code style before submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
