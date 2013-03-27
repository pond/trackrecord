/************************************************************************
 * File:    check_for_javascript.js                                     *
 *          Hipposoft 2009                                              *
 *                                                                      *
 * Purpose: Determine the level of JS support in the client by adding a *
 *          hidden input field to the first form found on the current   *
 *          page once it has loaded. Typically this is used with a 'log *
 *          in' form so that Rails can detect the "javscript = yes"     *
 *          parameter in the form submission and set a relevant key in  *
 *          the client's session cookie for future reference.           *
 *                                                                      *
 *          Requires Prototype and script.aculo.us (by using a small    *
 *          part of the API of both, the success of the script should   *
 *          be enough to give reasonable confidence in the client's     *
 *          level of JavaScript support for similar scripts elsewhere). *
 *          Only the Builder module of script.aculo.us is needed.       *
 *                                                                      *
 * History: 20-Nov-2009 (ADH): Created.                                 *
 ************************************************************************/

Event.observe
(
  window,
  'load',
  function()
  { 
    var                      forms = document.getElementsByTagName( 'form' );
    if ( forms.length == 0 ) forms = document.getElementsByTagName( 'FORM' );
    if ( forms.length != 0 )
    {
      var form  = forms[ 0 ];
      var input = Builder.node
      (
        'input',
        {
          type:  'hidden',
          name:  'javascript',
          value: 'yes'
        }
      );

      form.appendChild( input );
    }
  }
);  
