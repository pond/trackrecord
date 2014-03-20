# http://stackoverflow.com/questions/8415676/how-make-contents-of-readme-for-app-appear-in-doc-app-index-html
# http://stackoverflow.com/questions/2068639/how-to-rename-or-move-railss-readme-for-app

Rake::Task[ 'doc:app' ].clear
Rake::Task[ 'doc/app' ].clear
Rake::Task[ 'doc/app/index.html' ].clear

namespace :doc do
  Rake::RDocTask.new( 'app' ) do | rdoc |
    rdoc.rdoc_dir = 'doc/app'
    rdoc.template = ENV['template'] if ENV['template']
    rdoc.title    = ENV['title'] || 'TrackRecord'
    rdoc.main     = 'README.rdoc' # define README.rdoc as index

    rdoc.options << '--line-numbers'
    rdoc.options << '--charset' << 'utf-8'

    rdoc.rdoc_files.include( 'app/**/*.rb' )
    rdoc.rdoc_files.include( 'lib/**/*.rb' )
    rdoc.rdoc_files.include( 'README.rdoc' )
    rdoc.rdoc_files.include( 'CHANGELOG.rdoc' )
    rdoc.rdoc_files.include( 'doc/README_FOR_APP.rdoc' )
  end
end