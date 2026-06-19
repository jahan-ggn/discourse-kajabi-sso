# frozen_string_literal: true

module KajabiSso
  class UserFinder
    def self.find(email)
      User.real.find_by_email(email)
    end

    def self.find_or_provision(email, name)
      find(email) || UserProvisioner.provision(email, name: name)
    end
  end
end
