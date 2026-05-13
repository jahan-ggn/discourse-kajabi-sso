# frozen_string_literal: true

DiscourseKajabiSso::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseKajabiSso::Engine, at: "discourse-kajabi-sso" }
