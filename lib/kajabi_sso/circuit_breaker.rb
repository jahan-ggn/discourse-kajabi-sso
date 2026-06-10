# frozen_string_literal: true

module KajabiSso
  class CircuitBreaker
    FAILURE_THRESHOLD = 5
    FAILURE_WINDOW = 60.seconds
    OPEN_DURATION = 300.seconds

    def self.check
      new.check
    end

    def self.record_success
      new.record_success
    end

    def self.record_failure
      new.record_failure
    end

    def check
      raise CircuitOpenError, "Kajabi API is temporarily unavailable" if open? && !expired?

      reset if expired?
    end

    def record_success
      Rails.cache.delete(failure_key)
    end

    def record_failure
      failures = (Rails.cache.read(failure_key) || 0) + 1
      Rails.cache.write(failure_key, failures, expires_in: FAILURE_WINDOW)

      if failures >= FAILURE_THRESHOLD
        Rails.cache.write(open_key, Time.now.to_i, expires_in: OPEN_DURATION)
      end
    end

    private

    def open?
      Rails.cache.read(open_key).present?
    end

    def expired?
      opened_at = Rails.cache.read(open_key)
      return false unless opened_at
      Time.now.to_i - opened_at.to_i > OPEN_DURATION
    end

    def reset
      Rails.cache.delete(open_key)
      Rails.cache.delete(failure_key)
    end

    def failure_key
      Infrastructure::CacheKeyBuilder.build("circuit", "failures")
    end

    def open_key
      Infrastructure::CacheKeyBuilder.build("circuit", "open")
    end
  end
end
