# frozen_string_literal: true

module KajabiSso
  class BypassChecker
    def self.bypass?(email)
      new(email).bypass?
    end

    def initialize(email)
      @email = email
    end

    def bypass?
      return false if @email.blank?

      domain = @email.split("@").last&.downcase
      Configuration.bypass_domains.include?(domain)
    end
  end
end
