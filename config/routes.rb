# frozen_string_literal: true

KajabiSso::Engine.routes.draw do
  get "/auth/callback" => "auth#callback"
  get "/verify" => "auth#verify"
  post "/webhook/membership" => "webhooks#membership"
end

Discourse::Application.routes.draw { mount ::KajabiSso::Engine, at: "kajabi-sso" }
