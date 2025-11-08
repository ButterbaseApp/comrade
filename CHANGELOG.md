# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-30

### Breaking Changes

- feat!: introduce typed Provider enum for type-safe provider handling
  - Replace Symbol-based provider identification with strongly-typed Provider enum
  - Improves type safety and IDE support while maintaining backward compatibility
  - BREAKING CHANGE: public API now prefers Provider enum over Symbol

### Added

- feat: add WorkOS enterprise SSO provider support
  - Comprehensive WorkOS provider integration enabling enterprise SSO capabilities
  - Support for SAML, OIDC, and direct OAuth providers
  - Connection-based, organization-based, and provider-based authentication flows
  - Group-based access control data and token revocation support

### Bug Fixes

- fix: formatting

## [Unreleased]

### Added

- feat: add Keycloak OAuth 2.0 and OpenID Connect provider support
  - Comprehensive Keycloak provider integration for enterprise identity management
  - Support for realm-based architecture and multi-tenant scenarios
  - OpenID Connect standard compliance with PKCE support
  - Token refresh, revocation, and session management capabilities
  - JSON Web Key Set (JWKS) and OpenID Connect configuration discovery
  - Comprehensive test coverage and documentation

## [0.1.0] - 2025-01-14

### Added

- Complete OAuth 2.0 library inspired by Laravel Socialite
- Singleton Manager pattern for provider configuration and management
- Support for multiple OAuth providers:
  - GitHub (with email fetching)
  - Google (with OpenID Connect support)
  - Facebook
  - Twitter
  - Discord
- Comprehensive token management with refresh support
- PKCE (Proof Key for Code Exchange) support for public clients
- User data mapping and avatar URL handling
- Full test suite with 40 test cases covering all functionality
- Comprehensive documentation and usage examples
- CI/CD pipeline configuration
- Code quality enforcement with Ameba linter

### Infrastructure

- GitHub Actions workflow for automated testing
- Crystal Ameba integration for code linting
- Dependency management via shards
- Test coverage reporting

[Unreleased]: https://github.com/ButterbaseApp/comrade/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ButterbaseApp/comrade/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ButterbaseApp/comrade/releases/tag/v0.1.0
