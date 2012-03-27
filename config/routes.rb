AviasalesRorVacancy::Application.routes.draw do

  root :to => "StaticPages#home"

  match 'cursor_position', :to => "StaticPages#cursor_position"
  match 'flights/:iata/city', :to => "flights#show_city"

  resources :trips, :only => [:new, :create]
  resources :cursor_positions, :only =>[:new, :create]


end
