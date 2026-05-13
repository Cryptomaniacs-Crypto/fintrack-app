# frozen_string_literal: true

require 'json'
require 'redis'
require_relative 'secure_message'

module FinanceTracker
  # Secure wrappers around rack session values.
  class SecureSession
    class << self
      def setup(redis_server)
        @redis_opts = redis_server.is_a?(Hash) ? redis_server : { url: redis_server }
      end

      def set(session, key, value)
        session[key.to_s] = SecureMessage.encrypt(JSON.generate(value))
        value
      end

      def get(session, key)
        ciphertext = session[key.to_s]
        return nil unless ciphertext

        JSON.parse(SecureMessage.decrypt(ciphertext))
      end

      def delete(session, key)
        session.delete(key.to_s)
      end

      def wipe_redis_sessions
        raise 'Redis server is not configured' unless @redis_opts

        redis = Redis.new(**@redis_opts)
        session_ids = redis.keys
        session_ids.each { |session_id| redis.del(session_id) }
        session_ids.count
      end
    end
  end
end
