/************************************************************************
 * File:    check_box_toggler.js                                        *
 *          Hipposoft 2008                                              *
 *                                                                      *
 * Purpose: Create a selection list which helps a user change the state *
 *          of (potentially) large numbers of check boxes.              *
 *                                                                      *
 *          To use, call check_box_toggle_field from an inline script.  *
 *                                                                      *
 * History: 12-Jun-2008 (ADH): Created.                                 *
 ************************************************************************/

/* Write out a selection list entirely in JS which toggles a set of check
 * boxes according to items selected within it. Pass the ID to assign to
 * the SELECT container and a class name which is applied to any of the
 * check boxes that you want to include in the list's actions. If you want
 * any extra HTML written as a prefix or suffix, pass that in too.
 */

function check_box_toggle_field( id, className, prefix, suffix )
{
    if ( ! $$ ) return;

    var doc = '<select id="' + id + '">'
              + '<option disabled="disabled" selected="selected">Select...</option>'
              + '<option>All</option>'
              + '<option>None</option>'
              + '<option>Invert</option>'
            + '</select>';

    if ( prefix ) doc = prefix + doc;
    if ( suffix ) doc = doc + suffix;

    document.write( doc );

    var list = document.getElementById( id );
    if ( ! list ) return;

    new SelectionHandler( list, className );
}

/* Object which handles selection list changes; by using an object, extra
 * information can be carried through by an event and the EventListener
 * interface.
 */

function SelectionHandler( list, className )
{
    this.list      = list;
    this.className = className;

    list.addEventListener( 'change', this, false );
}

/* Handle changes in the selection list */

SelectionHandler.prototype.handleEvent = function( event )
{
    /* Perform the relevant action on the check boxes */

    $$( 'input.' + this.className ).each
    (
        function( box )
        {
            switch ( event.currentTarget.selectedIndex )
            {
                case 1: box.checked = true;          break;
                case 2: box.checked = false;         break;
                case 3: box.checked = ! box.checked; break;
            }
        }
    );

    /* Restore the default selected item in the list */

    event.currentTarget.options[ 0 ].selected = true;
}
