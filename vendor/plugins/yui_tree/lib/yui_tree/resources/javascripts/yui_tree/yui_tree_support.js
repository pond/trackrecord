/************************************************************************
 * File:    yui_tree_support.js                                         *
 *          Hipposoft 2009                                              *
 *                                                                      *
 * Purpose: Client-side support code for the YUI Tree View component as *
 *          used by the "yui_tree" Rails plugin.                        *
 *                                                                      *
 * History: 13-Nov-2009 (ADH): Created by combining fragments of inline *
 *                             JavaScript inside "yui_tree.rb".         *
 ************************************************************************/

/* The outer object is just a container for namespace and options which the
 * inner, entire self contained block 'onPageLoad' references from scope.
 * The block is invoked when the page loads; it defines various local
 * variables and methods and starts tree construction.
 *
 * You MUST provide the following options in the input parameter hash:
 *
 *   ==========================================================================
 *   Key             Value
 *   ==========================================================================
 *   divID           ID of a DIV element inside which the tree is built.
 *   --------------------------------------------------------------------------
 *   multiple        If 'true' the tree supports multiple selections, else
 *                   only one item can be selected a time.
 *   --------------------------------------------------------------------------
 *   rootCollection  Array of root node objects for the tree trunk. See the
 *                   creation of "nodeObj" in function "addChildren" for an
 *                   example of one fully populated node object. Note the way
 *                   the ID property is stored, in particular.
 *   --------------------------------------------------------------------------
 *   xhrURL          URL to use for XHR requests.
 *   --------------------------------------------------------------------------
 *   xhrTimeout      XHR request timeout in milliseconds (0 = never).
 *   --------------------------------------------------------------------------
 *   exclude         Array of IDs of nodes to exclude from the tree; may be
 *                   empty. Excluded nodes are either completely omitted or, if
 *                   not leaf nodes, are shown but cannot be selected
 *                   (highlighted). Their children are thus accessible and
 *                   potentially selectable, unless they too are excluded.
 *   --------------------------------------------------------------------------
 *   expand          Array of IDs of nodes to auto-expand; may be empty.
 *   --------------------------------------------------------------------------
 *   highlight       Array of IDs of nodes to auto-highlight; may be empty.
 *   --------------------------------------------------------------------------
 *   formFieldID     ID of the form element to receive the comma-separated list
 *                   list of selected node IDs. This must be given as it is the
 *                   only way for the client to know which items were selected.
 *                   The item's "value" attribute is given the list of items,
 *                   as a string. Typically a hidden INPUT element is used.
 *   ==========================================================================
 *
 * Items like "highlight" and "formFieldID" are valid for single-selection
 * trees as well as multiple selection trees - the highlight array would only
 * contain one entry and the value attribute of the form field would be updated
 * with just a single ID as a string.
 *
 * You MAY provide the following options in the input parameter hash:
 *
 *   ==========================================================================
 *   Key             Value
 *   ==========================================================================
 *   bodyClass       HTML class name to add to the BODY element, if wanted.
 *   --------------------------------------------------------------------------
 *   dataForXHRCall  Extra parameter data to send in XHR request (may be an
 *                   empty string) - will be URI encoded for safety. Gets sent
 *                   value for a 'data' key in the query string.
 *   --------------------------------------------------------------------------
 *   selectLeafOnly  If 'true', only leaf nodes can be selected (highlighted).
 *                   If omitted or 'false', any node can be selected.
 *   --------------------------------------------------------------------------
 *   propagateUp     If 'true', highlights are propagated up from a node
 *                   manually highlighted by a user (towards the root). Only
 *                   valid for multiple selection trees.
 *   --------------------------------------------------------------------------
 *   propagateDown   As above, but propagates down the tree (towards the leaf).
 *                   Spreads to all subnodes in as many branches as there may
 *                   be below the user-highlighted node. The propagate up/down
 *                   options operate globally on all tree nodes. Only valid for
 *                   multiple selection trees.
 *   --------------------------------------------------------------------------
 *   nameFieldID     ID of the page element for which innerHTML is written,
 *                   with the labels of any nodes held in the tree. Various
 *                   related options modify the behaviour and are listed below.
 *   --------------------------------------------------------------------------
 *   nameLeafNodesOnly  If 'true', only leaf nodes are included in the name
 *                   field. Defaults to 'false' if omitted (all node labels
 *                   of selected nodes are shown in the name field element).
 *   --------------------------------------------------------------------------
 *   nameFieldSeparator  A string used to separate the names written into the
 *                   name field element. Defaults to a single space. Can use
 *                   HTML here - e.g. '<br />' to put names on different lines.
 *   --------------------------------------------------------------------------
 *   nameFieldBlank  A string used for display in the name field element when
 *                   no nodes are selected. Defaults to an empty string, so
 *                   the name field is left empty with no nodes chosen.
 *   --------------------------------------------------------------------------
 *   nameIncludeParents  If you want to include the labels of all parents of a
 *                   node whenever that node's label is added to the name field
 *                   element, so that each entry in the element is in effect a
 *                   visual breadcrumb trail of the branch to and including the
 *                   node, then specify a non-empty string which will be used
 *                   as a separator between the various parent labels leading
 *                   to the node. If omitted or an empty string, only the label
 *                   of the selected node is shown; its parents' labels aren't.
 *   --------------------------------------------------------------------------
 *   formLeafNodesOnly  If 'true', only leaf nodes are included in the IDs
 *                   written into the hidden form element (see 'formFieldID').
 *                   Otherwise, any selected node is included.
 *   ==========================================================================
 */

function uk_org_pond_yui_tree_support( options )
{
  this.onPageLoad = function()
  {
    var parentHltList = [];
    var tree;
    var formField, nameField;
    var formLeafNodesOnly = false;
    
    if ( options.bodyClass )
    {
      var body = document.getElementsByTagName( 'body' )[ 0 ]
      var elt  = new YAHOO.util.Element( body );

      elt.addClass( options.bodyClass );
    }

    if ( options.formFieldID ) formField = document.getElementById( options.formFieldID );
    if ( options.nameFieldID ) nameField = document.getElementById( options.nameFieldID );

    /* This gets used whenever node highlight states change, so cache it for
     * a (tiny) bit of extra speed.
     */

    if ( options.formLeafNodesOnly ) formLeafNodesOnly = true;

    /* If using a name field but highlighting no items initially, make sure it
     * is clear. The caller may have put some kind of "please wait" text in
     * there to cover up the script loading / initialisation time, but with no
     * nodes to initially highlight, we'd otherwise never overwrite that.
     */

    if ( nameField && ( ! options.highlight || options.highlight.length == 0 ) ) nameField.innerHTML = '';

    /* Search array 'array' for item 'value' and return 'true' if it is found
     * else 'false'. The third parameter controls deletion - if 'true', a
     * found item will also be removed from the array.
     */

    function findItem( array, value, deleteIfFound )
    {
      for ( var i = 0, j = array.length; i < j; i ++ )
      {
        if ( array[ i ] == value )
        {
          if ( deleteIfFound ) array.splice( i, 1 );
          return true;
        }
      }

      return false;
    }

    /* Make an XHR call to load node child data. Pass the parent node and a
     * function to call when the XHR system gets a response (success or
     * failure).
     */

    function loadNodeData( node, fnLoadComplete )
    {
      var sUrl     = options.xhrURL + ".js?tree_parent_id=" + encodeURI( node.data.org_uk_pond_yui_tree_id );
      var callback =
      {
        /* Argument data to pass to the XHR response handlers below */

        argument:
        {
          "node": node,
          "fnLoadComplete": fnLoadComplete
        },

        /* After 'timeout' ms, the tree gives up and assumes no children */

        timeout: options.xhrTimeout,

        /* If the XHR call is successful, process the node data */

        success: function( oResponse )
        {
          var oResults = eval( '(' + oResponse.responseText + ')' );

          addChildren( node, oResults );
          oResponse.argument.fnLoadComplete();
        },

        /* If the XHR call is not successful, tell the tree to stop waiting */

        failure: function( oResponse ) { oResponse.argument.fnLoadComplete(); }
      };

      /* Add extra parameters if necessary then make the call */

      if ( options.dataForXHRCall )
      {
        sUrl += "&data=" + encodeURI( options.dataForXHRCall );
      }

      YAHOO.util.Connect.asyncRequest( 'GET', sUrl, callback );
    }

    /* Unfortunately YUI trees leave it up to the handler code to propagate
     * events for nodes using highlight propagation. We have to jump through
     * quite a few hoops to simulate the propagation of highlight events
     * from a custom click handler and make sure that children are added
     * automatically when parents are highlighted if the subtrees have not
     * yet been expanded, propagating the highlight and related events as
     * each subtree loads.
     *
     * In the 'addChildren' method, a given parent node has a given array of
     * child nodes added. We handle automatic node highlight and expansion
     * here, along with checking the 'parentHltList' array to see if propagated
     * selections should be continued for XHR-loaded data. See also function
     * 'markForChildHighlightAndExpansion'.
     */

    function addChildren( parentNode, childArray )
    {
      for ( var i = 0, j = childArray.length; i < j; i ++ )
      {
        var childObj = childArray[ i ];
        var canHigh  = options.selectLeafOnly ? childObj.isLeaf : true;

        if ( findItem( options.exclude, childObj.id, false ) )
        {
          if ( childObj.isLeaf ) continue;
          else canHigh = false;
        }

        var nodeObj =
        {
          label:                   childObj.label,
          isLeaf:                  childObj.isLeaf,
          className:               childObj.className,
          enableHighlight:         canHigh,
          multiExpand:             options.multiple,
          propagateHighlightUp:    options.multiple && options.propagateUp,
          propagateHighlightDown:  options.multiple && options.propagateDown,
          org_uk_pond_yui_tree_id: childObj.id
        }

        var tempNode = new YAHOO.widget.TextNode( nodeObj, parentNode, false );

        if ( findItem( options.expand, childObj.id, true ) ) tempNode.expand();

        var highlightIsPropagating = findItem( parentHltList, parentNode.data.org_uk_pond_yui_tree_id, false );
        if ( highlightIsPropagating || findItem( options.highlight, childObj.id, true ) )
        {
          tempNode.highlight( false ); /* False => *do* send related event */
          if ( highlightIsPropagating ) markForChildHighlightAndExpansion( tempNode );
        }
      }
    }

    /* A YUI tree node click handler. See the Tree View "clickEvent"
     * documentation for event details. Deals with the click by toggling the
     * selected node's highlight state, then, since YUI tree doesn't do this
     * for us, propagates a "highlight changed" event up and down the tree
     * from the clicked-upon node if that node is itself configured to
     * propagate the highlight. YUI tree will have done the highlighting, but
     * won't have auto-expanded any non-leaf nodes with children which we
     * should select (and wouldn't itself auto-select them later either), nor
     * does it generate the highlight event.
     *
     * For speed we don't actually try and generate a "highlightEvent" for
     * each altered node - we just call the handler function directly.
     */

    function nodeClickedUpon( event )
    {
      var node = event.node;
      node.toggleHighlight();

      if ( node.propagateHighlightUp )
      {
        var nextNode = node;

        while ( ( nextNode = nextNode.parent ) && nextNode.depth >= 0 )
        {
          nodeHighlightChanged( nextNode );
        }
      }

      /* Inner function - simulate propagation of "highlightEvent" to the
       * children of the given parent node, iff that node is not a leaf and
       * has the "propagateHighlightDown" flag set.
       */

      function inlineChildPropagator( node )
      {
        if ( node.propagateHighlightDown && ! node.isLeaf )
        {
          var children = node.children;
          var length   = children.length;
          var index;

          for ( index = 0; index < length; index ++ )
          {
            var child = children[ index ];

            nodeHighlightChanged  ( child );
            inlineChildPropagator ( child );
          }

          /* Since this node is not a child, if its children aren't rendered we
           * should take note in 'parentHltList' of whether or not those children
           * ought to be auto-highlighted if later loaded.
           */

          if ( ! node.childrenRendered ) markForChildHighlightAndExpansion( node );
        }
      }

      inlineChildPropagator( node );
      return false;
    }

    /* A YUI tree highlight change handler. See the Tree View "highlightEvent"
     * documentation for event details. Gets passed the node which has just
     * changed highlight state (by the time of calling, it should have been
     * updated and be at its new highlight state already).
     *
     * Deals with updating the form field recording selected node IDs and the
     * page element into which, optionally, labels from selected nodes are
     * written as a read-only visual record for the user.
     */

    function nodeHighlightChanged( node )
    {
      if ( formField )
      {
        /* Parse the existing ID set and add or remove the changed item. Most
         * of this code is only necessary for multiple selection trees but
         * works fine for single selection trees too.
         */

        var idVal = node.data.org_uk_pond_yui_tree_id;
        var idStr = formField.getAttribute( 'value' ) || '';
        var idAry = idStr ? idStr.split( ',' ) : [];

        /* Only update the form field if options allow any node to be included
         * or if this node is a leaf.
         */

        if ( ! formLeafNodesOnly || node.isLeaf )
        {
          if ( node.highlightState == 0 )
          {
            findItem( idAry, idVal, true /* true => remove item */ );
          }
          else
          {
            if ( findItem( idAry, idVal, false ) == false ) idAry.push( idVal );
          }

          formField.setAttribute( 'value', idAry.join( ',' ) );
        }

        /* Update the corresponding display field */

        if ( nameField )
        {
          var len   = idAry.length;
          var text  = '';
          var label = '';

          for ( var i = 0; i < len; i ++ )
          {
            var node = tree.getNodeByProperty( 'org_uk_pond_yui_tree_id', idAry[ i ] );

            if ( node != null && ( ! options.nameLeafNodesOnly || node.isLeaf ) )
            {
              label = node.label;

              if ( options.nameIncludeParents )
              {
                var nextNode = node;

                while ( ( nextNode = nextNode.parent ) && nextNode.label )
                {
                  label = nextNode.label + options.nameIncludeParents + label;
                }
              }

              if ( text.length > 0 ) text += ( options.nameFieldSeparator || ' ' );
              text += label;
            }
          }

          if ( text == '' && options.nameFieldBlank ) text = options.nameFieldBlank;
          nameField.innerHTML = text;
        }
      }
    }

    /* Given a node which has been identified as one which uses downwards
     * highlight propagation and which has just changed highlight state, work
     * out if the node should be added to the parent highlight list in
     * "parentHltList" so that its children will be auto-highlighted if the
     * node is later expanded. If using a name field element to show the labels
     * of selected nodes, the children will be expanded immediately so that
     * their names can be shown.
     */

    function markForChildHighlightAndExpansion( node )
    {
      /* Make sure the node's ID is first removed from the parent highlight
       * array so we don't end up with multiple inclusions, then push it back
       * onto the array if that node is now highlighted.
       */

      var id = node.data.org_uk_pond_yui_tree_id;
      findItem( parentHltList, id, true /* Remove item */ );

      if ( node.highlightState > 0 )
      {
        parentHltList.push( id );

        /* When auto-highlighting parent nodes as part of highlight propagation,
         * it is necessary to auto-expand those parents to reveal their children
         * if the labels of all selected items are being written into an HTML
         * element; otherwise, the list of children is unknown, so there's no
         * way to know what labels to add to the HTML element. This turns out to
         * be desirable in general, not least because it ensures that selected
         * IDs of all children are likely to be written into the hidden form
         * field, although there's always a chance that the user could submit a
         * containing form before this process completes.
         *
         * [TODO] Solve the issue of form submission prior to child expansion.
         * [TODO] Bear in mind that some branches may have expanded, but others
         * [TODO] may not, so it's basically impossible to handle in the client
         * [TODO] code - a solution is required herein.
         */

        node.expand();
      }
    }

    /* Build the YUI tree based on options passed into the encapsulating
     * object's constructor.
     */

    function buildTree()
    {
      tree = new YAHOO.widget.TreeView( options.divID );
      tree.setDynamicLoad( loadNodeData, 1 /* 1 => display leaves without "+" */ );
      tree.singleNodeHighlight = ! options.multiple;

      var root  = tree.getRoot();
      var array = ( options.rootCollection );

      addChildren( root, array );

      /* It's these event handler references which cause everything else herein
       * to avoid garbage collection even if there are no visible permanent
       * external references. External callers wanting to create multiple trees
       * do not need to invent unique global variable names to which to assign
       * instances of the "uk_org_pond_yui_tree_support" object - they can just
       * do 'new uk_org_pond_yui_tree_support(...);'.
       */

      tree.subscribe( 'clickEvent',     nodeClickedUpon      );
      tree.subscribe( 'highlightEvent', nodeHighlightChanged );

      tree.draw();
    }

    /* With everything now defined and ready, start the tree builder */

    buildTree();
  }

  /* Once the page has loaded, run the tree support code */

  YAHOO.util.Event.addListener( window, 'load', this.onPageLoad );
}
