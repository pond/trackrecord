# http://stackoverflow.com/questions/8415676/how-make-contents-of-readme-for-app-appear-in-doc-app-index-html

Rake::Task[ 'doc:app' ].clear
Rake::Task[ 'doc/app' ].clear
Rake::Task[ 'doc/app/index.html' ].clear

namespace :doc do
  Rake::RDocTask.new( 'app' ) do | rdoc |
    rdoc.rdoc_dir = 'doc/app'
    rdoc.title    = 'YOUR_TITLE'
    rdoc.main     = 'doc/README_FOR_APP' # define README_FOR_APP as index

    rdoc.options << '--charset' << 'utf-8'

    rdoc.rdoc_files.include( 'app/**/*.rb' )
    rdoc.rdoc_files.include( 'lib/**/*.rb' )
    rdoc.rdoc_files.include( 'doc/README_FOR_APP' )
  end
end