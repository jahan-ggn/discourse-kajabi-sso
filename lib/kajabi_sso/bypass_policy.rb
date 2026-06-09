# frozen_string_literal: true

module KajabiSso
  class BypassPolicy
    def self.call(email)
      new(email, Configuration.bypass_domains).bypass?
    end

    def initialize(email, domains)
      @email = email
      @domains = domains
    end

    def bypass?
      return false if @email.blank?

      domain = @email.split("@").last&.downcase
      @domains.include?(domain)
    end
  end
end
