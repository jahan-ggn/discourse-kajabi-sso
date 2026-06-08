# frozen_string_literal: true

module KajabiSso
  module UserTracker
    def self.track!(user)
      UserCustomField.find_or_initialize_by(
        user_id: user.id,
        name: "kajabi_sso"
      ).update!(value: "1")
    end
  end
end
