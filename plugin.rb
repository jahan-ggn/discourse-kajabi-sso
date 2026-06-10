# frozen_string_literal: true

# name: discourse-kajabi-sso
# about: Kajabi membership verification and community integration for Discourse
# version: 0.0.1
# authors: Jahan Gagan
# url: https://github.com/jahan-ggn/discourse-kajabi-sso

enabled_site_setting :kajabi_sso_enabled

module ::KajabiSso
  PLUGIN_NAME = "discourse-kajabi-sso"
end

require_relative "lib/kajabi_sso/engine"
require_relative "lib/kajabi_sso/errors"
register_asset "stylesheets/kajabi-login-modal.scss"
register_asset "stylesheets/kajabi-admin-offers.scss"

add_admin_route "discourse_kajabi_sso.admin.nav_title", "kajabi-offers"

after_initialize do
  reloadable_patch { UsersController.prepend(::KajabiSso::UsersControllerExtension) }

  on(:site_setting_changed) do |name, old_val, new_val|
    case name
    when :kajabi_offer_group_mapping
      KajabiSso::Mappings.clear_cache!
    when :kajabi_client_id, :kajabi_client_secret
      KajabiSso::ApiClient.clear_token_cache!
    end
  end
end
