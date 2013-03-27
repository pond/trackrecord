/************************************************************************
 * File:    timesheet_editor.js                                         *
 *          Hipposoft 2008                                              *
 *                                                                      *
 * Purpose: Navigation and calculation assistance for use during        *
 *          timesheet editing.                                          *
 *                                                                      *
 * History: 09-Mar-2008 (ADH): Created.                                 *
 ************************************************************************/

window.addEventListener( 'load', pageLoaded, false );

/* Configuration - if 'true', then moving into a field causes all of its
 * text to be selected. If 'false', then the caret simply moves into the
 * start or end position within that field depending on the direction
 * used to jump into it.
 */

var movingSelectsAll = true;

/* 2D array of references to INPUT fields. Their parent element is a
 * SPAN with an ID which parseId interprets to give row, column and
 * section numbers for the INPUT's location in the editing grid.
 * Populated in "pageLoaded".
 */

var grid = [];

/* Is this Opera? The check doesn't need to be rigorous because it's not
 * used for much of any importance, so no heavyweight user agent parser
 * libraries are included here.
 */

var isOpera = ( navigator.userAgent.indexOf( 'Opera' ) >= 0 ); /* Hideous */

/* Identifier class name for SPANs wraping INPUT elements of interest */

var spanClassSignature = 'ts_edit_wrapper';

/* Signature strings for IDs of SPAN elements in the timesheet editing
 * grid area.
 */

var rowSignature = 'row_';
var colSignature = '_col_';
var secSignature = '_section_';

/* Prefix used for row, column and section totals */

var rowPrefix = 'row_total_';
var colPrefix = 'col_total_';
var secPrefix = 'section_total_';

/* Overall total container ID */

var overallTotalSignature = 'overall_total';

/* Guard against multiple 'load' events running */

var alreadyInitialised = false;

/* Event handler run when the 'load' event is triggered */

function pageLoaded( event )
{
    if ( alreadyInitialised ) return;
    else alreadyInitialised = true;

    /* We want to create a 2D array of references to input elements,
     * with the first dimension referring to rows and the second to
     * columns. This is achievable because INPUT elements are wrapped
     * in SPANs of class "spanClassSignature" with IDs which can be
     * parsed by "parseId" to return the relevant numbers.
     */

    var spans  = document.getElementsByTagName( 'SPAN' );
    var length = spans.length;

    for ( var index = 0; index < length; index ++ )
    {
        var span = spans[ index ];
        var result, input;

        if ( span.className != spanClassSignature ) continue;

        result = parse_id( span.id );
        input  = span.getElementsByTagName( 'INPUT' )[ 0 ];

        if ( ! result || ! input ) return;

        /* Skip if it's not an interesting field */

        if ( ! result ) continue;

        /* Store the details of the input element */

        grid[ result.row ]               = grid[ result.row ] || [];
        grid[ result.row ][ result.col ] = input;
        grid[ result.row ].section       = result.sec;

        /* Add various listeners to the field in passing. Most of the work
         * is done on 'keydown', which only works *at all* in Safari 3 (it
         * sends bizarre key codes for 'keypress') and solves all sorts of
         * glitches with Opera and Firefox when input focus is moved.
         */

        input.addEventListener( 'change',  fieldChanged, false );
        input.addEventListener( 'keydown', fieldKeyDown, false );
    }

    /* Finally, make sure that totals are immediately up to date; this
     * isn't necessarily the case for page reloads where temporary data
     * edited by the user is persisted by the browser, but hasn't been
     * saved to the database by a form submission yet.
     */

    var rows = grid.length;
    var cols;

    for ( var row = 0; row < rows; row ++ )
    {
        cols = grid[ row ].length;
        for ( var col = 0; col < cols; col ++ ) calculate( row, col );
    }
}

/* Parse a grid input field ID and return the row, column and section
 * numbers as an object with properties 'row', 'col' and 'sec', or
 * 'undefined' if the ID can't be parsed.
 */

function parse_id( id )
{
    if ( ! id ) return undefined;

    var rowFound = id.indexOf( rowSignature );
    var colFound = id.indexOf( colSignature );
    var secFound = id.indexOf( secSignature );

    if ( rowFound < 0 || colFound < 0 || secFound < 0 ) return undefined;

    var rowStart = rowFound + rowSignature.length;
    var row      = parseInt( id.substring( rowStart, colFound ) )
    var colStart = colFound + colSignature.length;
    var col      = parseInt( id.substring( colStart, secFound ) )
    var secStart = secFound + secSignature.length;
    var sec      = parseInt( id.substring( secStart ) );

    if ( isNaN( row ) || isNaN( col ) || isNaN( sec ) ) return undefined;
    else return { row: row, col: col, sec: sec };
}

/* Event handler run when an input field changes value */

function fieldChanged( event )
{
    var input  = event.currentTarget;
    var result = parse_id( input.parentNode.id );

    if ( ! result ) return;

    /* Run the calculation for this row and column */

    calculate( result.row, result.col );
}

/* Calculate totals on the given row and column */

function calculate( calcRow, calcCol )
{
    /* Add up hours in the changed column */

    var rows      = grid.length;
    var colTotal  = 0.0;
    var colWarn   = false;

    for ( var row = 0; row < rows; row ++ )
    {
        var input = grid[ row ][ calcCol ];

        if ( input )
        {
            var text  = input.value;
            var value = ( text == '' ) ? 0.0 : parseFloat( text );

            if ( isNaN( value ) || value < 0 )
            {
                colWarn = true;
                break;
            }
            else
            {
                colTotal += value;
            }
        }
    }

    /* Similarly, add up hours in the changed row */

    var cols     = grid[ calcRow ].length;
    var rowTotal = 0.0;
    var rowWarn  = false;

    for ( var col = 0; col < cols; col ++ )
    {
        var input = grid[ calcRow ][ col ];

        if ( input )
        {
            var text  = input.value;
            var value = ( text == '' ) ? 0.0 : parseFloat( text );

            if ( isNaN( value ) || value < 0 )
            {
                rowWarn = true;
                break;
            }
            else
            {
                rowTotal += value;
            }
        }
    }

    /* Fill in the values */

    var rowElement = document.getElementById( rowPrefix + calcRow );
    var colElement = document.getElementById( colPrefix + calcCol );
    var rowStr     = trim( rowTotal.toFixed( 2 ) );
    var colStr     = trim( colTotal.toFixed( 2 ) );

    if ( rowTotal > 24 * 7 ) rowStr = rowStr.italics();
    if ( colTotal > 24     ) colStr = colStr.italics();

    if ( rowElement ) rowElement.innerHTML = rowWarn ? 'BAD'.bold() : rowStr;
    if ( colElement ) colElement.innerHTML = colWarn ? 'BAD'.bold() : colStr;

    /* Add up the row totals to get the grand total without having
     * to recalculate every row from its individual input fields. In
     * passing, update section totals too.
     */

    var allTotal  = 0.0;
    var allWarn   = false;
    var secTotals = [];

    for ( var row = 0; row < rows; row ++ )
    {
        var section = grid[ row ].section;
        var input   = document.getElementById( rowPrefix + row );

        if ( input )
        {
            var text  = input.innerHTML.replace( /<.*?>/, '' );
            var value = ( text == '' ) ? 0.0 : parseFloat( text );

            if ( isNaN( value ) || value < 0 )
            {
                allWarn              = true;
                secTotals[ section ] = allTotal = NaN;
            }
            else
            {
                if   ( secTotals[ section ] == undefined ) secTotals[ section ]  = value;
                else                                       secTotals[ section ] += value;

                allTotal += value;
            }
        }
    }

    /* Fill in the section totals */

    var sections = secTotals.length;

    for ( var section = 0; section < sections; section ++ )
    {
        var sectionElement = document.getElementById( secPrefix + section );
        var sectionTotal   = secTotals[ section ];

        if ( ! sectionElement ) continue;

        if ( isNaN( sectionTotal ) )
        {
            sectionElement.innerHTML = 'BAD'.bold();
        }
        else
        {
            var sectionStr = trim( sectionTotal.toFixed( 2 ) );
	    if ( sectionTotal > 24 * 7 ) sectionStr = sectionStr.italics();

            sectionElement.innerHTML = sectionStr;
        }
    }

    /* Fill in the overall total */

    var allElement = document.getElementById( overallTotalSignature );
    var allStr     = trim( allTotal.toFixed( 2 ) );

    if ( allTotal > 24 * 7 ) allStr = allStr.italics();

    if ( allElement ) allElement.innerHTML = allWarn ? 'BAD'.bold() : allStr;

    /* Inner function which trims a given string, removing one or
     * two trailing "0" characters and a trailing ".". Intended to
     * remove trailing "0"s in output from Float.toFixed( 2 ).
     */

    function trim( str )
    {
        str =  str.replace(/0$/,  '')
        str =  str.replace(/0$/,  '')
        return str.replace(/\.$/, '')
    }
}

/* Event handler run when an input field receives a "keydown" event.
 * The idea is to trap cursor keys and move the focused element in
 * the grid, so the user can perform what feels like natural 2D
 * navigation while editing a timesheet.
 *
 * Stops propagation and returns 'false' if the input focus is moved
 * successfully, else returns 'undefined' to allow event delivery to
 * continue normally.
 */

function fieldKeyDown( event )
{
    var rowChange = 0;
    var colChange = 0;
    var home      = false;
    var end       = false;

    /* 37 = left, 38 = up, 39 = right, 40 = down, 36 = Home, 35 = End */

    switch( event.keyCode )
    {
        case 37: colChange =   -1; break;
        case 38: rowChange =   -1; break;
        case 39: colChange =    1; break;
        case 40: rowChange =    1; break;
        case 36: home      = true; break;
        case 35: end       = true; break;
        default: return;
    }

    /* Now work out the input field details and bail out if there
     * seems to be anything wrong there either - do this after the
     * key check as it involves running much more code.
     */

    var from   = event.currentTarget;
    var result = parse_id( from.parentNode.id );

    if ( ! result ) return;

    /* Before proceeding, see if left/right movement should be only
     * within the current item's value. Uses the undocumented DOM
     * properties "selectionStart" and "selectionEnd", which are
     * Firefox extensions that have been implemented in some other
     * browsers. Fails gracefully if they are missing.
     */

    if ( colChange != 0 && from.selectionStart != undefined && from.selectionEnd != undefined )
    {
        var passOn;

        /* If moving left but the cursor or selection start is not yet
         * at the start of the value, pass on the event so that the
         * caret position can be moved by the browser - vice versa for
         * moving right. If any text is selected, detected by the start
         * and end of the selection having different values, then again
         * pass on the key press to allow OS/browser-defined behaviour.
         *
         * Annoyingly, Opera seems to update the values based on the
         * key code *before* raising the event in the interpreter, so
         * this doesn't quite work there; but there's no way to tell
         * if the value has only just changed or was already that way
         * from a previous key movement, so we have to live with it.
         */

        if ( from.selectionStart != from.selectionEnd )
        {
            passOn = true;
        }
        else
        {
            if ( colChange < 0 ) passOn = ( from.selectionStart > 0 );
            else                 passOn = ( from.selectionEnd   < from.value.length );
        }

        if ( passOn ) return;
    }

    /* Work out the new row and column */

    var row = result.row;
    var col = result.col;

    if ( home )
    {
        if ( col != 0 ) col = 0;
        else row = 0;
    }
    else if ( end )
    {
        if ( col < grid[ row ].length - 1 ) col = grid[ row ].length - 1;
        else row = grid.length - 1;
    }
    else
    {
        row += rowChange;
        col += colChange;
    }

    if ( row < 0 || row >= grid.length        ) return;
    if ( col < 0 || col >= grid[ row ].length ) return;

    /* Now we know which element to highlight */

    moveTo = grid[ row ][ col ];

    if ( moveTo )
    {
        /* Success - focus element */

        moveTo.focus();

        /* Make sure the caret position is sensible. In Opera, this needs
         * to be set immediately else caret redraw problems occur (it has
         * to blink at least once before showing in the right place, which
         * is very confusing). Firefox and Safari do better with it on a
         * timeout, else they sometimes move the caret after we have. On
         * Firefox this causes a bit of flicker but at least it works. On
         * Safari, no such troubles. Assume only Opera has the redraw bug
         * so use a timeout for everyone else.
         */

        var fn = colChange > 0 ? moveCaretToStart : moveCaretToEnd;

        if ( isOpera ) fn( moveTo );
        else setTimeout( fn, 0, moveTo )

        /* Consume the event */

        event.stopPropagation();
        return false;
    }
    else
    {
        /* Failure - pass the event on */

        return;
    }

    /* Inner function which moves the caret position to the start of
     * the given input field's value (requires the 'setSelectionRange'
     * extension).
     */

    function moveCaretToStart( field )
    {
        if ( field.setSelectionRange )
        {
            if ( movingSelectsAll ) field.setSelectionRange( 0, field.value.length );
            else                    field.setSelectionRange( 0, 0                  );
        }
    }

    /* Inner function which moves the caret position to the end of
     * the given input field's value (requires the 'setSelectionRange'
     * extension).
     */

    function moveCaretToEnd( field )
    {
        if ( field.setSelectionRange )
        {
            if ( movingSelectsAll ) field.setSelectionRange( 0,                  field.value.length );
            else                    field.setSelectionRange( field.value.length, field.value.length );
        }
    }
}
