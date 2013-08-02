/************************************************************************
 * File:    saved_report_editor.js                                      *
 *          Hipposoft 2013                                              *
 *                                                                      *
 * Purpose: Navigation and calculation assistance for use during        *
 *          report editing.                                             *
 *                                                                      *
 * History: 16-Jul-2013 (ADH): Created to get rid of as much inline     *
 *                             JavaScript in the edit view as possible. *
 ************************************************************************/

/* (Complex name chosen in an attempt to avoid namespace collisions)
 *
 * Once the saved report's name and "is shared" checkbox option fields
 * have been rendered, call here with inline script to set up an observer
 * that looks for changes in the "shared" flag and auto-generates a name,
 * should one not have already been set by the user.
 */

function ukOrgPondTrackRecordSavedReportEditorObserveShareFlag()
{
  var inputFieldAutoValue;

  var inputField = $( 'saved_report_title'  );
  var checkBox   = $( 'saved_report_shared' );

  checkBox.observe
  (
    'click',
    function()
    {
      var inputFieldCurrentValue = inputField.getValue();

      if ( checkBox.getValue() )
      {
        /* Check box set. If the input field is empty, set it
         * to the automatically determined value, which will
         * need to be fetched from the server the first time.
         */

        if ( inputFieldCurrentValue == '' )
        {
          if ( inputFieldAutoValue )
          {
            inputField.setValue( inputFieldAutoValue );
          }
          else
          {
            inputField.disable();
            inputField.setValue( "…" );

            new Ajax.Request
            (
              '<%= j( saved_report_auto_title_path() ) =%>',
              {
                method:    'get',
                onSuccess: function( response )
                {
                  inputFieldAutoValue = response.responseText;
                  inputField.enable();
                  inputField.setValue( inputFieldAutoValue );
                }
              }
            );
          }
        }
      }
      else if ( inputFieldCurrentValue == inputFieldAutoValue )
      {
        /* Check box unset. If the input field value seems to
         * have been set automatically, clear the value.
         */

        inputField.setValue( '' );
      }
    }
  );
};

/* (Complex name chosen in an attempt to avoid namespace collisions)
 *
 * Once the saved report's date range related fields have been rendered,
 * including any radio buttons of name "when_radio" with an inline style
 * that sets 'display: none' so that non-JavaScript browsers do not show
 * them, call here to associate event listeners that show/hide related
 * table rows associated with those radios. The radio must have a CSS
 * class name that matches a CSS class name on the table rows of
 * interest; these are shown/hidden and values of 'input' and 'select'
 * fields within those rows are restored/cleared as radios are chosen.
 */

function ukOrgPondTrackRecordSavedReportEditorObserveSectionRadios()
{
  /* Since this code only refers to form elements higher up in the
   * page, it can only run when things it wants are already present
   * in the DOM. Thus it can run immediately, not needing to wait
   * until the 'load' event.
   */

  var radios = $$( 'input[name~=when_radio]' );

  /* As radios are selected, hidden ones need related field values
   * cleared so the user doesn't unwittingly submit form fields
   * they can't see on JS-capable browsers; yet for the "edit saved
   * report" case, we do need to remember related field values and
   * restore them for the selected radio button. Use the following
   * as a data store. Name chosen to avoid namespace collision.
   */

  this.ukOrgPondTrackRecordTimesheetEditorRadioStore = {};

  /* This is called to establish initial state and also whenever a
   * radio changes state. It runs through all radios, restoring the
   * values for the fields related to the selected radio, while
   * hiding other fields and clearing their values.
   */

  function showOrHide()
  {
    radios.each
    (
      function( radio, index )
      {
        var rows = $$( "tr." + radio.className );
        var display;

        if ( radio.getValue() ) display = null;
        else                    display = "none";

        rows.each
        (
          function( row, index )
          {
            row.style.display = display;
            row.select( 'input, select' ).each
            (
              function( field, index )
              {
                if ( display == null )
                {
                  field.setValue( this.ukOrgPondTrackRecordTimesheetEditorRadioStore[ field.id ] || "" );
                }
                else
                {
                  field.setValue( "" );
                }
              }
            );
          }
        );
      }
    );
  }

  /* Now establish initial state, selecting an appropriate radio and
   * add an appropriate event listener to them all.
   */

  var fieldsHadValues = false;

  radios.each
  (
    function( radio, index )
    {
      radio.style.display = "inline";
      radio.observe
      (
        'change',
        function() { showOrHide(); }
      );

      var rows = $$( "tr." + radio.className );

      rows.each
      (
        function( row, index )
        {
          row.select( 'input, select' ).each
          (
            function( field, index )
            {
              this.ukOrgPondTrackRecordTimesheetEditorRadioStore[ field.id ] = field.getValue();

              if ( field.getValue() )
              {
                fieldsHadValues = true;
                radio.setValue( true )
              }
            }
          );
        }
      );
    }
  );

  if ( ! fieldsHadValues ) radios[ radios.length - 1 ].setValue( true );

  showOrHide();
};

/* (Complex name chosen in an attempt to avoid namespace collisions)
 *
 * Once the saved report's "calculate for these users only" multiple
 * selection list and "Per-user breakdown" checkbox flags have been
 * rendered, call here to associate event listeners that enable or
 * disable the "breakdown" checkbox according to whether or not any
 * users are selected in the selection list.
 *
 * This is because if no users are selected the report engine saves
 * (a lot of) time by not doing user calculations, but leaving the
 * "per-user breakdown" flag enabled could cause confusion.
 *
 * (I did consider having the "breakdown" flag implicitly enable
 * analysis across all users, but I don't want to accidentally have
 * the report engine and thus the server heavily loaded in this way
 * unless the user *really* means it! Someone must explicitly
 * select some or all users. This also means that if user accounts
 * are added to TrackRecord later, a user-based report's output
 * won't change unless it is edited and those new users are added -
 * the desirable outcome in the majority of use cases).
 */

function ukOrgPondTrackRecordSavedReportEditorObserveUserList()
{
    var selectionList = $( 'saved_report_reportable_user_ids' );

    function setCheckboxState()
    {
        var someSelected = ( selectionList.getValue().length ) !== 0;
        var checkbox     = $( 'saved_report_user_details'       );
        var label        = $( 'saved_report_user_details_label' );

        if ( someSelected )
        {
            checkbox.enable();
            label.style.opacity = null;
        }
        else
        {
            checkbox.disable();
            label.style.opacity = 0.3;
        }
    }

    selectionList.observe( 'change', function() { setCheckboxState(); } );
    setCheckboxState();
}
