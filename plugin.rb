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
require_relative "lib/kajabi_sso/users_controller_extension"

register_asset "stylesheets/common/kajabi-sso.scss"

after_initialize { UsersController.prepend(::KajabiSso::UsersControllerExtension) }
