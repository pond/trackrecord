########################################################################
# File::    eager_load_report_generators.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Eager-load all report generator classes in the "lib"
#           folder so that available generators can be enumerated via
#           the base class's "subclasses" array.
# ----------------------------------------------------------------------
#           26-Jul-2013 (ADH): Created.
########################################################################

# http://stackoverflow.com/questions/13220165/eager-loading-of-rails-lib

Dir[ "#{ Rails.root }/lib/report_generators/*.rb" ].each { | file | load file }
