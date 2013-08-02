/************************************************************************\
 * File:    safe_in_place_editing.js                                    *
 *          Hipposoft 2008                                              *
 *                                                                      *
 * Purpose: Safe, lockable in-place editing - client-side code.         *
 *                                                                      *
 * History: 24-Jun-2008 (ADH): Created.                                 *
\************************************************************************/

/* Stop "Jack &amp; Jill", written for display purposes into an HTML page,
 * from being edited as exactly that - "Jack &amp; Jill" - if the in-place
 * editor is activated due to Prototype's use of "innerHTML" in its internal
 * "getText" function. See:
 *
 *   http://github.com/madrobby/scriptaculous/wikis/ajax-inplaceeditor
 */

Object.extend
(
    Ajax.InPlaceEditor.prototype,
    {
        getText: function()
        {
            return this.element.childNodes[ 0 ] ? this.element.childNodes[ 0 ].nodeValue : '';
        }
    }
);

/* Support the "on success" and "on failure" functions */

var safeInPlaceEditorDoneFailureReport = false;

/* Custom in-place editor "on failure" function */

function safeInPlaceEditorOnFailure( transport )
{
    if ( transport.responseText )
    {
        safeInPlaceEditorRaiseAlert( transport );
        safeInPlaceEditorDoneFailureReport = true;
    }
    else
    {
        safeInPlaceEditorDoneFailureReport = false;
    }
}

/* Custom in-place editor "on complete" function (call by proxy to set
 * the value of 'lockVar' with the name of the lock variable, if any,
 * held in global (i.e. 'window') context).
 */

function safeInPlaceEditorOnComplete( transport, element, lockVar )
{
    if ( transport.status == 200 )
    {
        if ( lockVar ) window[ lockVar ] += 1;
    }
    else if ( ! safeInPlaceEditorDoneFailureReport )
    {
        safeInPlaceEditorRaiseAlert( transport );
    }

    safeInPlaceEditorDoneFailureReport = false;
}

/* Helper function - raise an alert describing the given transport object's
 * responseText value.
 */

function safeInPlaceEditorRaiseAlert( transport )
{
    alert
    (
        "Error communicating with the server: " +
        transport.responseText.stripTags()
    );
}
