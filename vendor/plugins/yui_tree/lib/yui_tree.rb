########################################################################
# File::    yui_tree.rb
# (C)::     Hipposoft 2009
#
# Purpose:: A Rails interface to the Yahoo Interface Library tree
#           component, for YUI version 2.7.0.
# ----------------------------------------------------------------------
#           06-Apr-2009 (ADH): Created.
########################################################################

module YuiTree
  mattr_accessor :default_options

  YUI_TREE_DEFAULT_TITLE_METHOD = 'name'.freeze

  module ClassMethods

    # Define the "uses_yui_tree" class method, which sets up instance variables
    # "<tt>@yui_tree_options</tt>" and "<tt>@uses_yui_tree</tt>" within any
    # controller calling the method. See "self.included" in the plugin code for
    # more information.
    #
    # The "uses_yui_tree" method can be passed two optional options hashes. The
    # first specifies options for the YUI tree. The second is passed directly
    # to the Rails before_filter[http://api.rubyonrails.org/classes/ActionController/Filters/ClassMethods.html#M000526]
    # method as filter options and this lets you state conditions for which
    # "uses_yui_tree" applies (e.g. "<tt>:only => ...</tt>" for only certain
    # actions or "<tt>:except => ...</tt>" for all actions except those listed).
    # See the Rails filter API documentation[http://api.rubyonrails.org/classes/ActionController/Filters/ClassMethods.html]
    # for full details.
    #
    # Most options for YUI trees can be specified in any of three places:
    #
    # 1. In the YAML configuration file.
    # 2. In a call to "uses_yui_tree" from a controller.
    # 3. In a call to the "YuiTree::YuiTreeHelper.yui_tree" helper method from
    #    a view.
    #
    # Options in the YAML file are application-global and overriden by those
    # specified in a controller, which are controller-global and in turn
    # overriden by local options given to helper method calls in views.
    #
    # Some options only make sense if specified in the YAML
    # configuration file and so cannot be specified elsewhere. When installed
    # the plugin writes a default configuration file in "config/yui_tree.yml";
    # see this for further information on the option meainings:
    #
    # - <tt>:version</tt>
    # - <tt>:javascript_base_uri</tt>
    # - <tt>:additional_yui_javascripts</tt> (an optional item)
    #
    # The following options usually only make sense if given in the YAML
    # configuration file and have default values written there, but they can
    # be specified per-controller or in each helper call in views if you really
    # want to do that:
    #
    # - <tt>:xhr_timeout</tt>
    # - <tt>:div_class</tt> (the class assigned to any DIV into which a YUI
    #   tree is built)
    #
    # These options can appear in the YAML file or here only, but not in helper
    # calls for individual views:
    #
    # - <tt>:body_class</tt> (a class name added to any existing class name(s)
    #   on the BODY element of the HTML document) - if "<tt>yui-skin-sam</tt>"
    #   is used then CSS files for this skin will be included automatically,
    #   else you must manually ensure that all relevant CSS resources are
    #   included.
    #
    # Other options must be specified in calls to "uses_yui_tree", or to a
    # helper function like "YuiTree::YuiTreeHelper.yui_tree" as they have no
    # default values. You could put them into the YAML file but due to the
    # nature of the options it is very likely that you'll specify them in
    # method calls instead. In fact it's more likely that you will want to
    # specify them in calls made in views rather than here in "uses_yui_tree",
    # but you can establish Controller-global defaults by specifying the
    # options here if you find this useful.
    #
    # <tt>:root_model</tt>::
    #   If your model supports tree/nested-set like behaviour - for example,
    #   if your model declares "<tt>acts_as_nested_set</tt>" via the
    #   Awesome Nested Set[http://github.com/collectiveidea/awesome_nested_set/]
    #   plugin - then specify the root model class here (e.g specify
    #   "<tt>:root_model => Location</tt>" or "<tt>:root_model =>
    #   Category</tt>") as a Controller-global default. Nested set behaviour
    #   assumes a class method called "roots" which takes no parameters and
    #   returns an array of model instances which are tree roots; and an
    #   instance method "leaf?" which also takes no parameters and returns
    #   '<tt>true</tt>' if the instance has no children (is a leaf node),
    #   else returns '<tt>false</tt>'.
    #
    #   The root model is used by YUI tree creation code (e.g. see helper
    #   method "YuiTree::YuiTreeHelper.yui_tree") to generate the root data set
    #   for the initial tree view. Alternatively, specify this when you make
    #   the call to e.g. "YuiTree::YuiTreeHelper.yui_tree" if you don't want to
    #   set a default here. By default the helper code calls an instance method
    #   called "name" to obtain label text for the tree nodes. Use the
    #   "<tt>:root_title_method</tt>" option (see below) to specify a different
    #   method name if necessary.
    #
    #   The root and child items can be sorted in various ways. See method
    #   "yui_tree_handled_xhr_request?" method for further information.
    #
    #   If you want to supply the collection of root objects yourself, rather
    #   than using a "<tt>:root_model</tt>" (see above) and its "roots" class
    #   method, you can do so when building the tree in a view through a call
    #   to the "YuiTree::YuiTreeHelper.yui_tree" helper method. See its
    #   "<tt>:root_collection</tt>" option for details. Whenever you need to
    #   assemble an array of objects to be used as roots or children, you must
    #   always build those objects with the "YuiTree.make_node_object" method.
    #
    # <tt>:root_title_method</tt>::
    #   If using "<tt>:root_model</tt>" (see above) but with a model which uses
    #   something other than a "name" method to return text for showing in tree
    #   nodes, then specify the alternative method's name here as a symbol. It
    #   must be an instance method for the model in question and should return
    #   a non-empty string.
    #
    # <tt>:xhr_url_method</tt>::
    #   Name of a method which will be invoked to get the *prefix* of a URL
    #   used to fetch more tree data (when parent nodes are expanded for the
    #   first time). This is usually a path to a controller's 'index' action,
    #   e.g. "<tt>:locations_path</tt>" or "<tt>:categories_path</tt>". The
    #   corresponding Controller action must return an array of child data. It
    #   can use the "yui_tree_handled_xhr_request?" method to do this
    #   or use entirely custom code. It must return an array of child data as
    #   described above (see "<tt>:root_model</tt>"), generating array entries
    #   with the "YuiTree.make_node_object" method. The parent's database ID is
    #   delivered to the controller action via the "params" hash under key
    #   "<tt>:tree_parent_id</tt>" and may have a string, symbol or integer
    #   value type.
    #
    # Some options are likely to be set per-tree but do have default values:
    #
    # <tt>:select_leaf_only</tt>::
    #     Set to '<tt>true</tt>' if leaves (nodes without children) can be
    #     selected but parents cannot, else '<tt>false</tt>'. Has an internal
    #     default value of '<tt>false</tt>' (i.e. can select anything).
    #
    # A few YUI tree options can be set as global defaults when making calls
    # to "uses_yui_tree", but such defaults only make sense if you use a single
    # tree in any of the containing controller's views. For example, the option
    # giving the ID of enclosing DIV inside which the tree is built falls into
    # this category, since no two elements in a valid HTML document are allowed
    # to have the same ID. It is up to you where you choose to specify these
    # options - here, or individual calls to "YuiTree::YuiTreeHelper.yui_tree".
    #
    # <tt>:div_id</tt>::
    #   ID given to the DIV container into which trees are built. Only specify
    #   this as a controller-global default if you are only going to use one
    #   tree control in any given view, else more than one DIV container for
    #   more than one tree view would have the same ID; or make very sure that
    #   any views using more than one tree view specify overriding DIV IDs in
    #   those views' calls to "YuiTree::YuiTreeHelper.yui_tree".
    #
    # <tt>:div_class</tt>::
    #   As "<tt>:div_id</tt>", but even less frequently used! Usually you will
    #   want application-wide styles to apply to trees via CSS and thus specify
    #   a single application-global class name in the YUI tree plugin's YAML
    #   configuration file, rather than specifying a controller-global value
    #   here, or even a per-tree value in indivdual calls to
    #   "YuiTree::YuiTreeHelper.yui_tree". Nonetheless, the facility exists to
    #   use any of those three approaches should they prove useful to you.
    #
    # <tt>:target_form_field_id</tt>::
    #   Whenever a node is selected, its database ID is written as a value of
    #   the "<tt>value</tt>" (sic.) attribute of the HTML element identified by
    #   this option so that a related form submission will contain the
    #   selected ID. The field is usually a hidden INPUT element.
    #
    #   Although the tree has a multiple selection mode (see the documentation
    #   for "YuiTree::YuiTreeHelper.yui_tree" for details), by default it
    #   assumes that you always want to ultimately let the user select a single
    #   item in the tree and have that item's database ID passed back to a
    #   controller in a related form submission.
    #
    #   A value of 0 may indicate that a blank entry is use and has been
    #   selected. See option "<tt>:include_blank</tt>" in helper method
    #   "YuiTree::YuiTreeHelper.yui_tree".
    #
    #   An empty string indicates that no nodes were highlighted at all. If you
    #   allow such things you should probably interpret this the same as the
    #   user explicitly selecting a blank entry. It's good to allow both as it
    #   isn't too friendly to assume the user will mean that deselecting all
    #   nodes means "none/blank"; it's good to have an explicit entry for that.
    #   You can still fault a no-selection form submission from the controller
    #   if the target form field value is empty rather than zero, should you
    #   wish to do so.
    #
    # <tt>:target_name_field_id</tt>::
    #   Optional; if included, then when a node is selected, its display text
    #   is written as innerHTML inside the identified element. This lets you
    #   show the user which node was selected by its text, as well as by the
    #   TreeView's own highlight mechanism. This is handy if you're worried
    #   that a selected node in a collapsed branch remains selected, albeit
    #   invisibly - a TreeView implementation quirk, it seems.
    #
    #   If you specify a value for the "<tt>:include_blank</tt>" option in a
    #   call to helper method "YuiTree::YuiTreeHelper.yui_tree", then note that
    #   the specified string will be written into the name field if either a
    #   "blank" tree entry item is explicitly selected, or if all items in the
    #   tree are entirely deselected. This goes back to the idea in
    #   "<tt>:target_form_field_id</tt>" above of a zero ID value, or a blank
    #   ID value, being usually treated as the same thing; but again, the
    #   controller can always treat the two conditions as distinct from one
    #   another if it so wishes.
    #
    #
    # == Example
    #
    #   # Location model "acts_as_nested_set"; uses Awesome Nested Set plugin;
    #   # thus has "roots" and "leaf?" methods which act as expected. Location
    #   # objects have a displayable name property in "name".
    #
    #   uses_yui_tree(
    #     { :root_model => Location, :xhr_url_method => :locations_path },
    #     { :only => [ :edit, :update ] }
    #   )
    #
    # This prepares the Controller for a YUI tree using a "Location" model. The
    # tree will obtain new data by a JSON XHR request to the URL returned by a
    # call to "locations_path" with ".js" added as a suffix. Only the ":edit"
    # and ":update" actions can use the tree. Listing both of these actions in
    # the ":only" clause is vital since the Controller's "update" code might
    # re-render the "edit" view (and thus the tree) because of form validation
    # errors. Alternatively use ":exclude" rather than ":only", or omit such a
    # clause altogether to prepare all the controller's views for YUI trees.
    #
    # An XHR URL method of "locations_path" will (assuming sane routes!) lead
    # to an "index" action of a controller for the Location model. The index
    # method must be aware of the YUI tree JSON requests - see
    # "yui_tree_handled_xhr_request?" or use the usual Rails
    # "<tt>respond_to do |format| ... format.js do ...</tt>" construct.
    #
    #   def index
    #     return if yui_tree_handled_xhr_request?( Location );
    #     # ...other processing code...
    #   end
    #
    # A helper method such as "YuiTree::YuiTreeHelper.yui_tree" must be invoked
    # somewhere in the ":edit" action's view (e.g. in "edit.html.erb") so that
    # the tree actually gets built:
    #
    #   <%= hidden_field_tag( 'foo', '[currently selected item ID here]' ) %>
    #   <%= yui_tree( :target_form_field_id => 'foo' ) %>
    #
    def uses_yui_tree( tree_options = {}, filter_options = {} )
      proc = Proc.new do | c |
        c.instance_variable_set( :@yui_tree_options, tree_options )
        c.instance_variable_set( :@uses_yui_tree,    true         )
      end

      before_filter( proc, filter_options )

      # See the dummy, static version of "yui_tree_handled_xhr_request?" below
      # for documentation.
      #
      self.class_eval %(
        define_method( :yui_tree_handled_xhr_request? ) do | model, *optional |
          result = false

          # WARNING: By default Rails treats XHR requests as ".js" format, if
          # no other format indication (e.g. filename extension, very specific
          # HTTP Accept header) exists. As a result this code can be run for
          # other XHR requests coming into your controller even though you
          # think it ought not to be. Hence the "params.has_key?" check, to try
          # and guard against accidental execution.

          if ( request.xhr? && params.has_key?( :tree_parent_id ) )
            respond_to do | format |
              format.js do

                # Use find_by_id() rather than just find() to avoid an exception if
                # the item cannot be located.

                parent = model.find_by_id( params[ :tree_parent_id ] )

                if ( parent.nil? )
                  render :json => []
                else
                  children = parent.children()

                  if ( model.respond_to?( :apply_default_sort_order ) )
                    model.apply_default_sort_order( children )
                  end

                  children.map!() do | child |
                    YuiTree::make_node_object(
                      child.id,
                      child.send( optional[ 0 ] || YuiTree::YUI_TREE_DEFAULT_TITLE_METHOD ),
                      child.send( optional[ 1 ] || :leaf? )
                    )
                  end

                  render :json => children
                end

                result = true

              end # format.js do
            end   # respond_to do | format |
          end     # if ( request.xhr? ... )

          result # Can't do "return result"; leads to ThreadError exception.

        end # define_method...
      )
    end # def uses_yui_tree...

    # When the tree calls back via AJAX and needs some children to fill in a
    # tree branch, call here to return appropriate data. Pass in the model to
    # find from (e.g. Category, Location - a class, not a string or symbol),
    # then optionally the name of the model instance method used to obtain the
    # text to show for each node (default is "name") and the name of a method
    # used to find out if the item is a leaf (default is "leaf?") - it should
    # return 'true' if so, else 'false'. Models which "act_as_nested_set" using
    # the Awesome Nested Set[http://github.com/collectiveidea/awesome_nested_set/tree/master]
    # plug-in are compatible with the defaults.
    #
    # If you want the tree order items automatically sorted then add a class
    # method called "apply_default_sort_order" to your model. This is passed an
    # array of model object instances and should sort the array in-place (e.g.
    # with the Array "sort!" method). The method's return value is ignored. If
    # the model has no "apply_default_sort_order" method then the collection
    # retrieved from the database is left in default sort order. If you have
    # simple requirements then using a call to Rails'
    # "default_scope[http://api.rubyonrails.org/classes/ActiveRecord/Base.html#M002313]"
    # method from your model is the most efficient way to achieve sorted
    # results. For example, in your model issue:
    #
    #   default_scope( { :order => 'name DESC' } )
    #
    # ...to have all collections of that model returned by finder methods
    # sorted in descending order by a "name" field by default. This applies
    # to _all_ finds done by your application, not just those related to YUI
    # trees, so use the "apply_default_sort_order" approach to restrict the
    # ordering to YUI tree views only.
    #
    # == Example
    #
    # A controller example inside an action which gets invoked when the XHR
    # request comes in:
    #
    #   def action_name
    #     return if yui_tree_handled_xhr_request?( Location, :title, :isLeaf? )
    #     # ...rest of normal action code...
    #   end
    #
    # This would handle YUI tree requests for a Location model using method
    # "title" (rather than the default of "name") to obtain the human-readable
    # names of locations and method "isLeaf?" (rather than the default of
    # "leaf?") to determine whether or not the item is at the end of a branch.
    #
    def yui_tree_handled_xhr_request?
      # This method is generated dynamically at run-time, the dynamic version
      # overwriting this one. The method here exists purely so that the RDoc
      # documentation generator will create documentation for the method.
      # Please see the implementation of "uses_yui_tree" above to see the code
      # for the dynamically generated method.
    end
  end # module ClassMethods

  # Simple helper method which builds an object suitable for rendering as
  # JSON and sending to the YUI tree as node data. Pass an object ID, name
  # to show in the tree and 'true' if this is a leaf, else 'false'. Returns
  # an appropriate Ruby object upon which "to_json" may be called. Call using
  # code such as "YuiTree::make_node_object(...)".
  #
  # The text given in the second parameter is made HTML-safe with "h(...)".
  # The output must be made JS-safe somehow, e.g. by "render :js => <objects>"
  # for one returned object or an array of them in controller handling XHR
  # requests in a "format.js do ..." block or by the necessity of turning the
  # objects into a JS equivalent by calling "to_json", which handles escaping
  # for you.
  #
  # An optional fourth parameter can be given - this is used as an extra class
  # name on the node text. You can specialise individual node appearance with
  # this and CSS, but only if you make custom nodes externally. If you use the
  # default internal code for acts-as-tree-like data sets, no special class
  # name will be applied to any nodes.
  #
  def self.make_node_object( id, name, isLeaf, className = nil )
    {
      :id        => id.to_s,#id.to_i,
      :label     => ERB::Util.h( name.to_s ),
      :isLeaf    => !! isLeaf,
      :className => className
    }
  end

  # Add in the YUI tree class methods and establish the helper calls
  # when the module gets included.
  #
  def self.included( base )
    if ( YuiTree.default_options.nil? )
      config_file = File.join( RAILS_ROOT, 'config', 'yui_tree.yml' )

      if ( File.readable?( config_file ) )
        YuiTree.default_options = YAML.load_file( config_file ).symbolize_keys
      else
        YuiTree.default_options = {}
      end
    end

    base.extend( ClassMethods  )
    base.helper( YuiTreeHelper )
  end

  # The helper module - methods for use within views.
  #
  module YuiTreeHelper

    # Include CSS and JavaScript related to the YUI tree if it is used by the
    # current view (established by a "YuiTree::ClassMethods.uses_yui_tree" call
    # made within the Controller). Invoke this helper within the HEAD section
    # of an XHTML view using, for example, this line of code:
    #
    #   <%= include_yui_tree_if_used -%>
    #
    # Note that a trailing newline *is* output so you can call the helper with
    # the "-%>" closing ERB tag (as shown in the previous paragraph) to avoid
    # inserting a single blank line into your output in the event that the
    # plugin is *not* used by the current view.
    #
    # If you like to keep indentation in your rendered HTML files, you may want
    # any lines output by this plugin to be indented too. Pass an optional
    # string to the method to cause all output from this call to be prefixed
    # accordingly.
    #
    def include_yui_tree_if_used( line_prefix = nil )
      yui_tree_init( line_prefix ) if using_yui_tree?
    end

    # Returns 'true' if configured to use the YUI tree control for the view
    # related to the current request. See the "uses_yui_tree" class method for
    # more information.
    #
    def using_yui_tree?
      ! @uses_yui_tree.nil?
    end

    # Build a YUI tree at the point where the method is called - e.g. place
    # within the body of an XHTML document using "<%= yui_tree(...) %>". By
    # default the tree has no option buttons next to entries and is designed
    # to allow the selection of any single item from within it.
    #
    # An options hash must be passed. It *may* contain any of the options
    # specified as available in a call to "YuiTree::ClassMethods.uses_yui_tree"
    # and *must* at least contain values for the following keys unless they
    # have been given values in the YAML configuration file (uncommon) or the
    # view's corresponding controller's call to
    # "YuiTree::ClassMethods.uses_yui_tree" (more common):
    #
    # * <tt>:xhr_url_method</tt>
    # * <tt>:target_form_field_id</tt>
    # * <tt>:select_leaf_only</tt>
    # * <tt>:root_model</tt> _or_ <tt>:root_collection</tt> (see below)
    # * <tt>:root_title_method</tt> (perhaps, if using <tt>:root_model</tt>)
    # * <tt>:root_collection</tt> - if your model does *not* match the
    #   characteristics described for option "<tt>:root_model</tt>" in the
    #   "YuiTree::ClassMethods.uses_yui_tree" method documentation, then you
    #   must provide an array of objects defining the roots of the tree.
    #   Construct array entries by calling "YuiTree::make_node_object". The
    #   resulting collection is later turned into a JavaScript-safe array by
    #   a wider call to "to_json" on a JavaScript options hash which gets
    #   created by the YUI tree instantiation helper code; you don't need
    #   to worry about HTML or JavaScript escaping of any values yourself.
    #
    # The following option values can be specified technically in any of the
    # locations described by the documentation for the
    # "YuiTree::ClassMethods.uses_yui_tree" method, but it is very uncommon
    # to use them anywhere other than a call here, to "yui_tree". Each of the
    # items is optional and modifies tree behaviour in some way. Some of the
    # options work together, so use of one may mean you must also use another.
    # Any such relationships are described below:
    #
    # <tt>:include_blank</tt>::
    #   A string if you want that string to be included at the top of the roots
    #   of the tree as an item that indicates nothing/none/blank - an ID of
    #   zero is associated with it. This option works whether you use the
    #   plugin's generation of the root dataset via "<tt>:root_model</tt>" or
    #   if you generate your own dataset and provide it through
    #   "<tt>:root_collection</tt>". Of course, you can always add your own
    #   blank entry/entries in the latter case, but using the
    #   "<tt>:include_blank</tt>" might be more convenient and keep your code
    #   clean.
    #
    #   The reason you pass a string rather than, say, a boolean is so that you
    #   can pass any relevant message, including one looked up from an
    #   internationalisation locale file (assuming Rails >= 2.3.x).
    #
    #   Note that this string is used if a nodes is deselected so that no nodes
    #   are highlighted and the "<tt>:target_name_field_id</tt>" option has
    #   been set up - the string is written as innerHTML of the name field.
    #
    # <tt>:exclude</tt>::
    #   An ID as an integer, or an object with a method 'id' which returns its
    #   ID as an integer, or an array of either of these types (they can be
    #   mixed in the same array). Specifies items which will not be included
    #   in the tree even if the Controller returns them at any point. This
    #   works at the node addition level in JS, so it is *not a security
    #   feature*. If you don't want something to be seen by a user, don't let
    #   the Controller send it out in the first place. The exclusion feature is
    #   useful if using, say, a tree to assign a parent to an existing item
    #   within a hierarchy - you don't want to let the user try and assign the
    #   item _itself_ as a parent, so exclude it.
    #
    #   If you exclude a non-leaf item, it will be shown in the tree but will
    #   not be selectable. This way, children can still be selected. At
    #   present the code is "sort of" clever enough to know if no children
    #   are going to be present due to exclusions, in that it will try to
    #   fetch child nodes but when they all get excluded the Yahoo tree view
    #   itself will stop trying further and change the node indicator on the
    #   parent to being a branch, rather than a toggle control. It does mean
    #   one technically unnecessary AJAX request and associated UI update
    #   delay though, but it's a much simpler mechanism than trying to work
    #   such things out up-front.
    #
    # <tt>:expand</tt>::
    #   As "<tt>:exclude</tt>", but specifies nodes which will be automatically
    #   expanded whenever they are added to the tree. Node that if you add a
    #   non-root node to the exclusions list, you must also add any if its
    #   parents (i.e. its complete set of ancestors) back to the root if you
    #   want that whole branch to be expanded automatically. Otherwise the
    #   branch starting from the child will only automatically expand if the
    #   user expands the parent node which contains it.
    #
    # <tt>:highlight</tt>::
    #   As "<tt>:exclude</tt>" but only takes a single item not an array;
    #   specifies an item to be highlighted when the tree is created. Once
    #   highlighted initially, the item is forgotten and will not be
    #   auto-highlighted again. If a non-root item then it will only be
    #   highlighted when the branch containing it is opened; in general you
    #   will probably want to use the "<tt>:expand</tt>" option in cojunction
    #   with "<tt>:highlight</tt>" for non-root nodes.
    #
    # <tt>:multiple</tt>::
    #   A boolean (defaults to '<tt>false</tt>') which says that multiple
    #   items may be selected in the tree. See below for more.
    #
    # <tt>:form_leaf_nodes_only</tt>::
    #   If '<tt>true</tt>', only the IDs of _leaf_ nodes will be written into
    #   the form field identified by the mandatory
    #   "<tt>:target_form_field_id</tt>" option. Defaults to '<tt>false</tt>'
    #   so that any selected (highlighted) node is included, leaf or otherwise.
    #
    # <tt>:data_for_xhr_call</tt>::
    #   An optional string which if included will be added to the parameters
    #   used when the XHR call to retrieve more node items is made. If using
    #   the built-in "YuiTree::ClassMethods.yui_tree_handled_xhr_request?"
    #   method then this is of no use, but if you write a custom handler then
    #   the data string provides a crude but effective way of passing in
    #   external data. Usually, the data is used as some kind of filter,
    #   restricting the range of nodes which the XHR handler method would
    #   otherwise have returned. Note that the string will be run through the
    #   'j' helper to make it JS-safe, so some characters may not be treated
    #   quite how you expect - avoid literal single quotes, double quotes and
    #   backslashes in particular. The string will appear in the params hash
    #   under the key "<tt>:data</tt>". An empty string given here is treated
    #   the same way as if the option had been completely omitted.
    #
    # The options hash *must not* contain any of the following keys since this
    # would interfere with values set for those same options elsewhere and
    # provoke undefined behaviour (one part of your view would disagree with
    # another part of your view). If present, these keys will be deleted.
    #
    # - <tt>:body_class</tt>
    #
    # Any other YUI tree options not listed above are irrelevant here.
    #
    # Note that you must *never mix* the use of options "<tt>:root_model</tt>"
    # and "<tt>:root_collection</tt>" between this call and any other places
    # where options may be specified; if you do, results will be undefined.
    #
    #
    # == Multiple selection trees
    #
    # If '<tt>:multiple</tt>' is '<tt>true</tt>' the tree allows multiple check
    # boxes to be selected. Selecting a child does not cause its parents to
    # change state by default - the user is free to choose any collection of
    # nodes without constraint - but that can be changed with options listed
    # below.
    #
    # Option key "<tt>:highlight</tt>" now begins to work as "<tt>:expand</tt>"
    # or "<tt>:exclude</tt>" in that it can take a single item or an array of
    # items to be highlighted. If you use "<tt>:expand</tt>" to auto-expand
    # highlighted nodes, remember that you need to specify all ancestors of any
    # non-root node you want expanded.
    #
    # The form field specified in "<tt>:target_form_field_id</tt>" has its
    # value populated using a comma-separated list of IDs of selected items.
    # The container specified in "<tt>:target_name_field_id</tt>", if any, will
    # have its value populated using a space-separated list of names of
    # selected items. You can customise this list of names with the following
    # extra options only relevant to multiple selection trees using
    # "<tt>:target_name_field_id</tt>":
    #
    # <tt>:name_field_separator</tt>::
    #   Text to use as a separator between items in the name field. Defaults
    #   to a single space. Must be JS single quoted string safe. May be HTML
    #   (e.g. "<br />").
    #
    # <tt>:name_include_parents</tt>::
    #   If you want to include the names of all parent nodes whenever a node's
    #   label is used for the name field so that each text entry reflects the
    #   whole of the branch of the tree used to reach the node in question,
    #   then set this option to a string which is used as a separator between
    #   each of the parent items. Must be JS single quoted string safe. May be
    #   HTML or even an empty string to directly concatenate parent names. By
    #   default names of parents are not included - only the label of the
    #   individual node is added to the name field.
    #
    # <tt>:name_leaf_nodes_only</tt>::
    #   If '<tt>true</tt>', use only labels of leaf nodes for name field text;
    #   don't include others. Useful in conjunction with the
    #   "<tt>:name_include_parents</tt>" option, since when the latter is in
    #   use, individual entries in the name field will already indicate the
    #   labels for the complete branch leading to a node so including names of
    #   non-leaf items would only lead to duplication. By default names of all
    #   nodes are included.
    #
    # Once multiple items are selectable, it becomes desirable to be able to
    # control the YUI tree's highlight propagation features - that is, when a
    # node is selected, should its parent and/or child nodes be automatically
    # selected as well? The following options control this behaviour. The
    # settings apply to every node in the tree.
    #
    # <tt>:propagate_up</tt>::
    #   If '<tt>true</tt>', selecting any node causes all parent nodes on the
    #   same branch to be selected, if any. By default this option is disabled.
    #
    # <tt>:propagate_down</tt>::
    #   If '<tt>true</tt>', selecting any node causes all child nodes in the
    #   tree below this node, if any, to be selected. By default this option
    #   is disabled.
    #
    def yui_tree( options )

      # Reject options which are explicitly not allowed here.

      options.delete( :body_class )

      # Merge default from-YAML options, options given in the "uses_yui_tree"
      # call and mandatory passed-in options for this method. We store the view
      # options in the main options store to override previously set defaults.

      defaults = YuiTree.default_options.merge( @yui_tree_options || {} )
      options  = defaults.merge( options )

      # Extract items of interest for which default values exist.

      xhr_timeout          = options.delete( :xhr_timeout_ms       ) || YUI_TREE_DEFAULT_TIMEOUT
      body_class           = options.delete( :body_class           ) || YUI_TREE_DEFAULT_BODY_CLASS
      div_class            = options.delete( :div_class            ) || YUI_TREE_DEFAULT_DIV_CLASS
      div_id               = options.delete( :div_id               ) || YUI_TREE_DEFAULT_DIV_ID
      select_leaf_only     = options.delete( :select_leaf_only     ) || YUI_TREE_DEFAULT_LEAF_ONLY

      # Extract other options, raising exceptions if anything mandatory has
      # been omitted.

      xhr_url_method       = options.delete( :xhr_url_method       ) || raise( YUI_MISSING_OPTS_ERROR % :xhr_url_method       )
      target_form_field_id = options.delete( :target_form_field_id ) || raise( YUI_MISSING_OPTS_ERROR % :target_form_field_id )
      target_name_field_id = options.delete( :target_name_field_id )
      root_model           = options.delete( :root_model           )
      root_title_method    = options.delete( :root_title_method    ) || YuiTree::YUI_TREE_DEFAULT_TITLE_METHOD
      root_collection      = options.delete( :root_collection      )
      include_blank        = options.delete( :include_blank        )
      exclude              = options.delete( :exclude              )
      expand               = options.delete( :expand               )
      highlight            = options.delete( :highlight            )
      form_leaf_nodes_only = options.delete( :form_leaf_nodes_only ) || false
      data_for_xhr_call    = options.delete( :data_for_xhr_call    )

      multiple             = options.delete( :multiple             ) || false
      propagate_up         = options.delete( :propagate_up         ) || false
      propagate_down       = options.delete( :propagate_down       ) || false
      name_field_separator = options.delete( :name_field_separator ) || ' '
      name_include_parents = options.delete( :name_include_parents )
      name_leaf_nodes_only = options.delete( :name_leaf_nodes_only ) || false

      xhr_url = send( xhr_url_method )

      # Allow minor API misuse...

      multiple = true  if ( multiple == :true  )
      multiple = false if ( multiple == :false )

      # Build a root collection if working with the "root_model" option.

      if ( root_model.nil? && root_collection.nil? )
        raise ( YUI_MISSING_OPTS_ERROR % 'root_model" or ":root_collection' )
      elsif root_collection.nil?
        root_model      = root_model.to_s.constantize
        root_instances  = root_model.roots()

        if ( root_model.respond_to?( :apply_default_sort_order ) )
          root_model.apply_default_sort_order( root_instances )
        end

        root_collection = root_instances.map() do | root_item |
          YuiTree::make_node_object(
            root_item.id,
            root_item.send( root_title_method ),
            root_item.leaf?
          )
        end
      end

      # Add in a blank entry if necessary.

      unless ( include_blank.nil? )
        blank_item = YuiTree::make_node_object( '0', include_blank, true )
        root_collection.unshift( blank_item )
      end

      # Build the DIV for the tree then initialise the object for the lengthy
      # script which manages the tree. Compile and return the HTML and JS data.

      result = content_tag(
        :div,
        '',
        {
          :class => "#{ div_class } ygtv-checkbox",
          :id    => div_id
        }
      ) + "\n"

      options_hash = {

        # Mandatory

        :divID              => div_id,
        :multiple           => !! multiple,
        :rootCollection     => root_collection,
        :xhrURL             => xhr_url,
        :xhrTimeout         => xhr_timeout,
        :exclude            => coerce_to_array( exclude   ),
        :expand             => coerce_to_array( expand    ),
        :highlight          => coerce_to_array( highlight ),
        :formFieldID        => target_form_field_id,

        # Optional

        :bodyClass          => body_class,
        :dataForXHRCall     => data_for_xhr_call,
        :selectLeafOnly     => !! select_leaf_only,
        :propagateUp        => !! propagate_up,
        :propagateDown      => !! propagate_down,
        :nameFieldID        => target_name_field_id,
        :nameLeafNodesOnly  => !! name_leaf_nodes_only,
        :nameFieldSeparator => name_field_separator,
        :nameFieldBlank     => include_blank,
        :nameIncludeParents => name_include_parents,
        :formLeafNodesOnly  => form_leaf_nodes_only

      }.delete_if { | k, v | v.nil? }

      # The use of 'to_json' ensures that strange JS characters get properly
      # escaped, among other things.

      js = "  var options = #{ options_hash.to_json };\n" <<
           "  new uk_org_pond_yui_tree_support( options );"

      return ( result << javascript_tag( js ) )
    end

  private

    # Default option values should all come from the configuration YAML data,
    # but the user may have elected to delete entries or omit the entire file.

    YUI_TREE_DEFAULT_BASE_URI   = '//yui.yahooapis.com'.freeze
    YUI_TREE_DEFAULT_VERSION    = '2.7.0'.freeze
    YUI_TREE_DEFAULT_TIMEOUT    = '20000'.freeze
    YUI_TREE_DEFAULT_BODY_CLASS = 'yui-skin-sam'.freeze
    YUI_TREE_DEFAULT_DIV_CLASS  = 'yui-tree-container'.freeze
    YUI_TREE_DEFAULT_DIV_ID     = YUI_TREE_DEFAULT_DIV_CLASS
    YUI_TREE_DEFAULT_LEAF_ONLY  = false

    YUI_MISSING_OPTS_ERROR = 'You must give a value for the ":%s" key of the options hash in "yui_tree()"'.freeze

    # Return data suitable for an XHTML document HEAD section to establish
    # basic requirements for a YUI tree view. Does not generate JavaScript
    # which will actually construct and invoke the tree; just handles the
    # tree's prerequisites. Pass a string to use as a prefix for each line
    # of the output data or 'nil' for none.
    #
    def yui_tree_init( line_prefix )
      options      = YuiTree.default_options.merge( @yui_tree_options || {} )

      base_uri     = options.delete( :javascript_base_uri        ) || YUI_TREE_DEFAULT_BASE_URI
      version      = options.delete( :version                    ) || YUI_TREE_DEFAULT_VERSION
      body_class   = options.delete( :body_class                 ) || YUI_TREE_DEFAULT_BODY_CLASS
      extra_yui_js = options.delete( :additional_yui_javascripts ) || []

      result       = ''
      compression  = RAILS_ENV == 'development' ? '' : '-min'

      # Select the uncompressed, easy to read/debug JS files in development
      # mode, else the compressed "-min" variants.

      if body_class == 'yui-skin-sam'
        result << stylesheet_link_tag( "#{ base_uri }/#{ version }/build/treeview/assets/treeview-skin.css" ) + "\n"
      end

      # The Yahoo DOM event script is only available in compressed form, so
      # include this separately from those with normal and "-min" variants.

      result << javascript_include_tag( "#{base_uri}/#{version}/build/yahoo-dom-event/yahoo-dom-event.js" ) + "\n"

      yui_scripts  = %w{element/element connection/connection treeview/treeview}
      yui_scripts += extra_yui_js
      yui_scripts.each do | script |
        result << javascript_include_tag( "#{ base_uri }/#{ version }/build/#{ script }#{ compression }.js" ) + "\n"
      end

      result << javascript_include_tag( 'yui_tree/yui_tree_support.js' ) + "\n"
      result.gsub!( /^/, line_prefix ) unless ( line_prefix.nil? || line_prefix.empty? )

      return result
    end

    # Coerce an object into a JS array.
    #
    def coerce_to_array( data )
      return []       if     ( data.nil?           )
      return [ data ] unless ( data.is_a?( Array ) )
      return data;
    end
  end
end

# Install the controller and helper methods.

ActionController::Base.send( :include, YuiTree )
ActionView::Base.send :include, YuiTree::YuiTreeHelper
