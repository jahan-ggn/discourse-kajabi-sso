# frozen_string_literal: true

module KajabiSso
  class UserProvisioner
    def self.provision(email, name: nil)
      new(email, name: name).provision
    end

    def initialize(email, name: nil)
      @email = email
      @name = name
    end

    def provision
      username = UserNameSuggester.suggest(@name.presence || @email)
      display_name =
        @name.presence || @email.split("@").first&.titleize || username

      user =
        User.new(
          email: @email,
          username: username,
          name: display_name,
          staged: false,
          active: true,
          approved: true,
          trust_level: TrustLevel[0]
        )

      user.save
      user
    end
  end
end
