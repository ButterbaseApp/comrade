require "json"

module Comrade
  # Represents a user from an OAuth provider
  class User
    getter id : String
    getter nickname : String?
    getter name : String?
    getter email : String?
    getter avatar : String?
    getter raw : JSON::Any

    def initialize(@id : String, @nickname : String? = nil, @name : String? = nil,
                   @email : String? = nil, @avatar : String? = nil, @raw : JSON::Any = JSON::Any.new({} of String => JSON::Any))
    end

    # Create user from OAuth provider response
    def self.from_oauth_response(data : JSON::Any, mappings : Hash(String, String)? = nil) : User
      # Default field mappings for common OAuth providers
      default_mappings = {
        "id"       => "id",
        "nickname" => "login",
        "name"     => "name",
        "email"    => "email",
        "avatar"   => "avatar_url",
      }

      # Merge with custom mappings
      field_mappings = default_mappings.merge(mappings || {} of String => String)

      id = get_field(data, field_mappings["id"])
      raise "Missing user ID in OAuth response" if id.nil? || id.empty?

      nickname = field_mappings["nickname"]? ? get_field(data, field_mappings["nickname"]) : nil
      name = field_mappings["name"]? ? get_field(data, field_mappings["name"]) : nil
      email = field_mappings["email"]? ? get_field(data, field_mappings["email"]) : nil
      avatar = field_mappings["avatar"]? ? get_field(data, field_mappings["avatar"]) : nil

      new(id, nickname, name, email, avatar, data)
    end

    # Get a field from JSON data with fallback
    private def self.get_field(data : JSON::Any, field_path : String) : String?
      return nil if field_path.nil?

      # Support nested field paths like "user.email"
      fields = field_path.split(".")
      current = data

      fields.each do |field|
        return nil unless current.as_h?
        return nil unless current.as_h.has_key?(field)
        current = current[field]
      end

      # Handle different JSON types
      case current.raw
      when String
        current.as_s
      when Int64, Int32
        current.to_s
      when Nil
        nil
      else
        current.to_s
      end
    rescue
      nil
    end

    # Check if user has an email
    def has_email? : Bool
      !email.nil?
    end

    # Check if user has a name
    def has_name? : Bool
      !name.nil?
    end

    # Check if user has an avatar
    def has_avatar? : Bool
      !avatar.nil?
    end

    # Get display name (falls back to nickname if name is not available)
    def display_name : String
      name || nickname || id
    end

    # Get raw field value from provider response
    def get_raw_field(field : String) : JSON::Any?
      raw[field]?
    end

    # Convert to hash
    def to_h : Hash(String, String?)
      {
        "id"       => id,
        "nickname" => nickname,
        "name"     => name,
        "email"    => email,
        "avatar"   => avatar,
      }
    end

    # Convert to JSON
    def to_json : String
      to_h.to_json
    end

    # String representation
    def to_s : String
      "User(id: #{id}, name: #{name}, email: #{email})"
    end
  end
end
