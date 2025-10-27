require "json"
require "time"

module Comrade
  # Represents OAuth tokens returned by providers
  class Token
    getter access_token : String
    getter refresh_token : String?
    getter expires_in : Int32?
    getter scope : String?
    getter token_type : String?
    getter created_at : Time

    def initialize(@access_token : String, @refresh_token : String? = nil, @expires_in : Int32? = nil,
                   @scope : String? = nil, @token_type : String? = nil, @created_at : Time = Time.utc)
    end

    # Create token from JSON response
    def self.from_json(json : String | IO) : Token
      data = JSON.parse(json)
      from_json_object(data)
    end

    # Create token from JSON::Any object
    def self.from_json_object(data : JSON::Any) : Token
      access_token = data["access_token"]?.try(&.as_s) || raise "Missing access_token in response"
      refresh_token = data["refresh_token"]?.try(&.as_s?)
      expires_in = data["expires_in"]?.try(&.as_i?)
      scope = data["scope"]?.try(&.as_s?)
      token_type = data["token_type"]?.try(&.as_s?)

      new(access_token, refresh_token, expires_in, scope, token_type)
    end

    # Check if token is expired
    def expired? : Bool
      return false unless expires = expires_in
      Time.utc > created_at + expires.seconds
    end

    # Check if token is about to expire (within 5 minutes)
    def expiring_soon?(buffer : Int32 = 300) : Bool
      return false unless expires = expires_in
      Time.utc > created_at + (expires - buffer).seconds
    end

    # Get expiration time
    def expires_at : Time?
      return nil unless expires = expires_in
      created_at + expires.seconds
    end

    # Check if token has a refresh token
    def refreshable? : Bool
      !refresh_token.nil?
    end

    # Convert to hash
    def to_h : Hash(String, JSON::Any::Type)
      hash = Hash(String, JSON::Any::Type).new
      hash["access_token"] = access_token
      hash["refresh_token"] = refresh_token if refresh_token
      if expires = expires_in
        hash["expires_in"] = expires.to_i64
      end
      hash["scope"] = scope if scope
      hash["token_type"] = token_type if token_type
      hash["created_at"] = created_at.to_unix
      hash
    end

    # Convert to JSON
    def to_json : String
      to_h.to_json
    end

    # Create token from WorkOS response
    def self.from_workos_response(data : JSON::Any) : Token
      access_token = data["access_token"]?.try(&.as_s) || raise "Missing access_token in WorkOS response"

      # WorkOS typically doesn't provide refresh tokens or expiration
      refresh_token = nil
      expires_in = nil
      scope = nil
      token_type = "Bearer"

      new(access_token, refresh_token, expires_in, scope, token_type)
    end

    # Create token from hash
    def self.from_h(hash : Hash(String, JSON::Any::Type)) : Token
      access_token = hash["access_token"]?.to_s
      raise "Missing access_token" if access_token.empty?

      refresh_token = hash["refresh_token"]?.try(&.to_s)
      expires_in = hash["expires_in"]?.try(&.to_s)
      scope = hash["scope"]?.try(&.to_s)
      token_type = hash["token_type"]?.try(&.to_s)
      created_at_unix = hash["created_at"]?.try(&.to_s) || Time.utc.to_unix.to_s

      expires_in_int = expires_in.try(&.to_i?)
      created_at_int = created_at_unix.to_i64
      created_at = Time.unix(created_at_int)

      new(access_token, refresh_token, expires_in_int, scope, token_type, created_at)
    end
  end
end
