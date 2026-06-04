# frozen_string_literal: true

KajabiSso::Engine.routes.draw { post "/webhook/membership" => "webhooks#membership" }

Discourse::Application.routes.draw { mount ::KajabiSso::Engine, at: "kajabi-sso" }
