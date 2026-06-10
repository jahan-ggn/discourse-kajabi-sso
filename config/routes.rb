# frozen_string_literal: true

KajabiSso::Engine.routes.draw do
  post "/webhook/membership" => "webhooks#membership"
  get "/admin/offers" => "admin_offers#index"
end

Discourse::Application.routes.draw do
  mount ::KajabiSso::Engine, at: "kajabi-sso"
  get "/admin/plugins/kajabi-offers" => "admin/plugins#index", :constraints => StaffConstraint.new
end
