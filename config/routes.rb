Trackrecord::Application.routes.draw do

  # Map root to the User account home page. The "root" mapping is so that
  # "root_url" exists, since the open_id_authentication plugin requires it.

  match '/' => 'users#home'
  match '/' => 'users#home', :as => :home

  # Mapping for the OpenID login system. The signin and signout
  # entries are for more readable paths in views; they're just
  # aliases for 'new' and 'destroy' actions.

  get '/session' => 'sessions#create', :as  => :open_id_complete

  resource :session

  match '/signin'  => 'sessions#new',     :as => :signin
  match '/signout' => 'sessions#destroy', :as => :signout

  # Allow in-progress account signup to be cancelled

  match '/users/cancel/:id' => 'users#cancel', :as => :user_cancel

  # Get common named routes for our resources. Don't be confused by the rather
  # esoteric use of Ruby block syntax here - this is just defining some nested
  # routes; e.g. customers have many tasks, so tasks are defined as resources
  # within customers. The longhand equivalent would be:
  #
  #   resources :customers do
  #     resources :tasks
  #   end
  #
  # ...and the Rails 2 equivalent used to be:
  #
  #  map.resources :customers, :has_many => [ :tasks ]

  resources( :customers      ) { resources :tasks                            }
  resources( :projects       ) { resources :tasks                            }
  resources( :control_panels ) { resources :tasks                            }
  resources( :tasks          ) { resources :users; resources :timesheet_rows }
  resources( :timesheets     ) { resources :timesheet_rows                   }

  resources( :users ) do
    resources :tasks
    resources :timesheets

    resources :saved_reports do
      get 'delete', :on => :member
    end

    resource :saved_reports_by_task,     :controller => :saved_reports_by_task,     :only => :create
    resource :saved_reports_by_project,  :controller => :saved_reports_by_project,  :only => :create
    resource :saved_reports_by_customer, :controller => :saved_reports_by_customer, :only => :create
    resource :saved_reports_by_user,     :controller => :saved_reports_by_user,     :only => :create
  end

  resources :audits
  resources :reports
  resources :charts
  resource  :task_imports
  resources :trees

  resources :help

  resource  :saved_report_auto_title, :only => :show

  # Finally, the normal default rules at lowest priority

  match '/:controller/:action/:id' => '#index'
  match '/:controller/:action/:id.:format' => '#index'
end
