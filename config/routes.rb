ActionController::Routing::Routes.draw do | map |

  # Helper method to make named routes easier (from a RailsCast)

  # def map.controller_actions( controller, actions )
  #   actions.each do | action |
  #     self.send(
  #       "#{controller}_#{action}",
  #       "#{controller}/#{action}",
  #       :controller => controller,
  #       :action => action
  #     )
  #   end
  # end

  # Map root to the User account home page. The "root" mapping is so that
  # "root_url" exists, since the open_id_authentication plugin requires it.

  map.root      :controller => 'users', :action => 'home'
  map.home '/', :controller => 'users', :action => 'home'

  # Mapping for the OpenID login system. The signin and signout
  # entries are for more readable paths in views; they're just
  # aliases for 'new' and 'destroy' actions.

  map.open_id_complete '/session', :controller => 'sessions', :action => 'create', :requirements => { :method => :get }
  map.resource :session

  map.signin  '/signin',  :controller => 'sessions', :action => 'new'
  map.signout '/signout', :controller => 'sessions', :action => 'destroy'

  # Allow in-progress account signup to be cancelled

  map.user_cancel '/users/cancel/:id', :controller => 'users', :action => 'cancel'

  # Shortcut GET-style report route for copy-and-paste report-in-a-URI
  
  map.report_shortcut '/reports/report.html', :controller => 'reports', :action => 'create', :requirements => { :method => :get }

  # Get common named routes for our resources

  map.resources :customers,      :has_many => [ :tasks                  ]
  map.resources :projects,       :has_many => [ :tasks                  ]
  map.resources :control_panels, :has_many => [ :tasks                  ]
  map.resources :users,          :has_many => [ :tasks, :timesheets     ]
  map.resources :tasks,          :has_many => [ :users, :timesheet_rows ]
  map.resources :timesheets,     :has_many => [ :timesheet_rows         ]
  map.resources :audits
  map.resources :reports
  map.resources :charts
  map.resources :task_imports
  map.resources :trees

  # Finally, the normal default rules at lowest priority

  map.connect '/:controller/:action/:id'
  map.connect '/:controller/:action/:id.:format'
end
