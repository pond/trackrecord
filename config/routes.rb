Trackrecord::Application.routes.draw do

  # Map root to the User account home page. The "root" mapping is so that
  # "root_url" exists, since the open_id_authentication plugin requires it.

  get '/' => 'users#home'
  get '/' => 'users#home', :as => :home

  # Mapping for the OpenID login system. The signin and signout
  # entries are for more readable paths in views; they're just
  # aliases for 'new' and 'destroy' actions.

  get '/session' => 'sessions#create', :as  => :open_id_complete

  resource :session

  get '/signin'  => 'sessions#new',     :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout

  # Allow in-progress account signup to be cancelled

  get '/users/cancel/:id' => 'users#cancel', :as => :user_cancel

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

      # This route is rather confusing and was determined by trial and error.
      # The intention is to get a variant of "new" which takes an ID, for the
      # "copy a report" case. The below achieves it (see "rake routes" and
      # look for "saved_reports#new" - it appears twice in different forms).
      # It also creates "user_saved_report_copy_<foo>()" methods.

      get 'new', :to => 'saved_reports#new', :as => 'copy'
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
  resource  :timesheet_force_commit,  :only => [ :new, :create ]

  # Finally, the normal default rules at lowest priority

  get '/:controller/:action/:id' => '#index'
  get '/:controller/:action/:id.:format' => '#index'
end
