/************************************************************************
 * File:    timesheet_viewer.js                                         *
 *          Hipposoft 2009                                              *
 *                                                                      *
 * Purpose: Calculation assistance for use during timesheet viewing.    *
 *                                                                      *
 * History: 25-Nov-2009 (ADH): Created.                                 *
 ************************************************************************/

window.addEventListener( 'load', pageLoaded, false );

/* Fill in section totals */

function pageLoaded( event )
{
  var row_total_elements = document.getElementsByClassName( 'ts_show_total' );
  var sec_total_elements = document.getElementsByClassName( 'ts_show_section_total' );
  var sections           = [];
  var totals             = [];
  var index, length; element;

  /* Create an array of section total container elements indexed by section
   * number. Annoyingly, "for..in" loops are unreliable on the arrays obtained
   * by the DOM calls above, browsers (and for that matter, irresponsible JS
   * frameworks) apparently extending arrays with extra enumerable values of
   * an unexpected type. Thus, the more cumbersome "for" syntax must be used.
   */

  length = sec_total_elements.length;
  for ( index = 0; index < length; index ++ )
  {
    var element = sec_total_elements[ index ];
    var sec     = parseInt( element.id.substring( 14 ) ); /* "section_total_<secnum>" */

    sections[ sec ] = element;
  }

  /* Add up row totals, putting the result in an array also indexed by section
   * number.
   */

  length = row_total_elements.length;
  for ( index = 0; index < length; index ++ )
  {
    var element = row_total_elements[ index ];
    var nums    = element.id.substring( 10 ).split( '_' ); /* "row_total_<secnum>_<rowidx>" */
    var sec     = parseInt( nums[ 0 ] );

    if ( sec > sections ) sections = sec;
    totals[ sec ] = ( totals[ sec ] || 0 ) + parseFloat( element.innerHTML );
  }

  /* Run through the totals, updating the contents of corresponding section
   * total container elements.
   */

  length = totals.length;
  for ( index = 0; index < length; index ++ )
  {
    if ( sections[ index ] ) sections[ index ].innerHTML = '' + totals[ index ];
  }
}
