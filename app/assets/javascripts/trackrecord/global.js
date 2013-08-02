/************************************************************************
 * File:    global.js                                                   *
 *          Hipposoft 2008-2013                                         *
 *                                                                      *
 * Purpose: Various JavaScript patches.                                 *
 *                                                                      *
 *          Rails provides a simple hook in views that uses JS to       *
 *          temporarily disable a form submission button when it is     *
 *          activated, both to stop double submissions and to give the  *
 *          user some feedback (since the text can change, e.g. from    *
 *          "Save" to "Saving...", when the button is disabled). Some   *
 *          browsers, however, do not restore the button to its prior   *
 *          state when the 'back' button is used. Attempt to patch      *
 *          around the problem.                                         *
 *                                                                      *
 * History: 09-Mar-2008 (ADH): Created as "application.js".             *
 *          18-Jul-2013 (ADH): Moved to "trackrecord/global.js".        *
 ************************************************************************/

/****************************************************************************\
 * GREYED OUT BUTTON "GO BACK" PATCH
\****************************************************************************/

window.addEventListener( 'load',   pageLoaded,    false );
window.addEventListener( 'unload', pageUnloading, false );

/* Elements to watch (see below) */

var toWatch = [];

/* The page has loaded. Look for the kinds of buttons and input fields that
 * may be disabled later and remember information about them.
 */

function pageLoaded()
{
    var inputs = document.getElementsByTagName( 'input' ) || [];
    var length = inputs.length;

    /* For now, just scan 'input' elements for 'submit' element types. In
     * future, 'button' elements may need to be included.
     */

    for ( var i = 0; i < length; i ++ )
    {
        var input = inputs[ i ];

        if ( input && input.type == 'submit' )
        {
            toWatch.push
            (
                {
                    element:  input,
                    value:    input.value,
                    disabled: input.disabled
                }
            );
        }
    }
}

/* The page is being removed. Check through the buttons remembered in the
 * 'load' handler and restore previous state if there has been a change.
 */

function pageUnloading()
{
    var length = toWatch.length;

    for ( var i = 0; i < length; i ++ )
    {
        var watch  = toWatch[ i ];
        var element = watch.element;

        if ( element.disabled != watch.disabled )
        {
            element.disabled = watch.disabled;
            element.value    = watch.value;
        }
    }
}
