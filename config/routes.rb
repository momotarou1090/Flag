Rails.application.routes.draw do
  root 'tweets#index'
  resources :tweets
  devise_for :users

  resources :users do
    member do
      post 'follow'
      delete 'unfollow'
      get :following, :followers
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
