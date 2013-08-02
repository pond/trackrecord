/************************************************************************
 * File:    section_revealer.js                                         *
 *          Hipposoft 2008                                              *
 *                                                                      *
 * Purpose: Hide lengthy subsections behind a hide/show title link. A   *
 *          title element with ID 'item_breakdown_heading' is looked    *
 *          for and, if found, has "..." added to the end of its text.  *
 *          A dummy link ("<A>") is built around it for styling         *
 *          reasons. A container with ID 'item_breakdown_contents' is   *
 *          hidden with CSS 'display: none'. When the heading link is   *
 *          later clicked on, its visibility is toggled. Since the DOM  *
 *          changes happen only if the browser gets through quite a lot *
 *          of the script, it degrades well in less capable browsers.   *
 *                                                                      *
 *          At the time of writing only one toggle section per page is  *
 *          supported due to the hard-coded IDs used.                   *
 *                                                                      *
 * History: 12-May-2008 (ADH): Created.                                 *
 ************************************************************************/

window.addEventListener( 'load', pageLoaded, false );

/* Keep track of element IDs and state */

var titleElement;
var titleDefault;
var contentsElement;
var contentsVisible;

/* 'load' event listener - set everything up */

function pageLoaded()
{
    /* Are both required elements present? Bail out if not. */

    titleElement    = document.getElementById( 'item_breakdown_heading'  );
    contentsElement = document.getElementById( 'item_breakdown_contents' );

    if ( ! titleElement || ! contentsElement ) return;

    /* Set up the click handler and establish initial styles */

    titleElement.addEventListener( 'click', toggleVisibility, false );

    titleDefault    = titleElement.innerHTML;
    contentsVisible = true;

    toggleVisibility();
}

/* 'click' event listener for the title element - toggle the contents region
 * visibility and the "..." in the title. Called directly from the 'load' event
 * listener too.
 */

function toggleVisibility()
{
    contentsVisible               = ! contentsVisible;
    contentsElement.style.display = contentsVisible ? 'block' : 'none';
    titleElement.innerHTML        = '<a href="#">'
                                  + titleDefault
                                  + ( contentsVisible ? '' : '...' )
                                  + '</a>';
}
