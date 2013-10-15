require File.dirname(__FILE__) + '/../test_helper'

class SavedReportTest < ActiveSupport::TestCase

  # Pass reference value, new comparison value and on-error message.
  # Stores message if values differ.
  #
  def check( a, b, msg )
    @errors << [ msg, a, b ] unless a == b
  end

  # Pass value and on-error message. Stores message if value is nil.
  #
  def not_nil( a, msg )
    @errors << [ msg, a ] if a.nil?
  end

  # Pass reference value, new comparison value and on-error message.
  # Stores message if one value is nil but the other is not, does not
  # store message if both values are nil or neither value is nil.
  #
  # Returns 'true' if either value is nil, else 'false'.
  #
  def equal_nils( a, b, msg )
    @errors << [ msg, a, b ] unless a.nil? == b.nil?
    a.nil? || b.nil?
  end

  # Pass a saved report ID, a reference compiled internal report
  # generated from that saved report and a new comparison compiled
  # internal report generated from that saved report. Compares the
  # two and compiles a set of differences, if any, which are then
  # reported via an assertion.
  #
  def compare_reports( id, ref, com )

    @errors = []

    # Start with the large scale stuff - overall report data, main
    # counts and so-on.

    check ref.column_count(),  com.column_count(),  "Report #{ id }: Differing column counts"
    check ref.user_count(),    com.user_count(),    "Report #{ id }: Differing user counts"

    check ref.committed(),     com.committed(),     "Report #{ id }: Report committed total differs"
    check ref.not_committed(), com.not_committed(), "Report #{ id }: Report not committed total differs"
    check ref.total(),         com.total(),         "Report #{ id }: Report overall total differs"

    # Per-column data.

    ref_crngs = []
    com_crngs = []

    ref.each_column_range { | r | ref_crngs << r }
    com.each_column_range { | r | com_crngs << r }

    ref_crngs.each_index do | index |
      ref_crng = ref_crngs[ index ]
      com_crng = com_crngs[ index ]

      check ref_crng, com_crng, "Report #{ id }, linear column index #{ index }: Differing column ranges"
    end

    ref_cttls = []
    com_cttls = []

    ref.each_column_total { | t | ref_cttls << t }
    com.each_column_total { | t | com_cttls << t }

    ref_cttls.each_index do | index |
      ref_cttl = ref_cttls[ index ]
      com_cttl = com_cttls[ index ]

      next if equal_nils ref_cttl, com_cttl, "Report #{ id }, linear column index #{ index }: Differing nil/not-nil column total"

      check ref_cttl.committed(),     com_cttl.committed(),     "Report #{ id }, linear column index #{ index }: Committed total differs"
      check ref_cttl.not_committed(), com_cttl.not_committed(), "Report #{ id }, linear column index #{ index }: Not committed total differs"
      check ref_cttl.total(),         com_cttl.total(),         "Report #{ id }, linear column index #{ index }: Overall total differs"
    end

    # Per-user data for the report and columns.

    ref_users = []
    com_users = []

    ref.each_user { | u | ref_users << u }
    com.each_user { | u | com_users << u }

    ref_users.each_index do | uindex |
      ref_user = ref_users[ uindex ]
      com_user = com_users[ uindex ]

      next if equal_nils ref_user, com_user, "Report #{ id }, linear user index #{ uindex }: Differing nil/not-nil users in main user list"
      check ref_user.id.to_s, com_user.id.to_s, "Report #{ id }, linear user index #{ uindex }: Differing users in main user list"

      ref_user_total = ref.user_total( ref_user.id.to_s )
      com_user_total = com.user_total( ref_user.id.to_s )

      next if equal_nils ref_user_total, com_user_total, "Report #{ id }, user #{ com_user.id }, linear user index #{ uindex }: Unexpected nil/not-nil user total"

      check ref_user_total.committed(),     com_user_total.committed(),     "Report #{ id }, user #{ com_user.id }, linear user index #{ uindex }: User report committed total differs"
      check ref_user_total.not_committed(), com_user_total.not_committed(), "Report #{ id }, user #{ com_user.id }, linear user index #{ uindex }: User report not committed total differs"
      check ref_user_total.total(),         com_user_total.total(),         "Report #{ id }, user #{ com_user.id }, linear user index #{ uindex }: User report overall total differs"

      ref_cttls.each_index do | cindex |
        ref_ucttl = ref_cttls[ cindex ].try( :user_total, ref_user.id.to_s )
        com_ucttl = com_cttls[ cindex ].try( :user_total, com_user.id.to_s )

        next if equal_nils ref_ucttl, com_ucttl, "Report #{ id }, linear column index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: Unexpected nil/not-nil cell user total"

        check ref_ucttl.committed(),     com_ucttl.committed(),     "Report #{ id }, linear column index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User column committed total differs"
        check ref_ucttl.not_committed(), com_ucttl.not_committed(), "Report #{ id }, linear column index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User column not committed total differs"
        check ref_ucttl.total(),         com_ucttl.total(),         "Report #{ id }, linear column index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User column overall total differs"
      end
    end

    # Finally, check all of the rows, cells and per-user data therein.

    ref.each_row do | ref_row, ref_task |
      com_row = com.row( ref_task.id.to_s )

      next if equal_nils ref_row, com_row, "Report #{ id }, task #{ ref_task.id }: Differing nil/not-nil row data"

      ref_section, ref_is_new_section, ref_group, ref_is_new_group = ref.retrieve( ref_task.id.to_s )
      com_section, com_is_new_section, com_group, com_is_new_group = com.retrieve( ref_task.id.to_s ) # (sic.)

      check ref_section.title( nil, true ), com_section.title( nil, true ), "Report #{ id }, task #{ ref_task.id }: Section title differs"
      check ref_group.title(),              com_group.title(),              "Report #{ id }, task #{ ref_task.id }: Group title differs"
      check ref_is_new_section,             com_is_new_section,             "Report #{ id }, task #{ ref_task.id }: Section flag differs"
      check ref_is_new_group,               com_is_new_group,               "Report #{ id }, task #{ ref_task.id }: Group flag differs"

      check ref_row.committed(),     com_row.committed(),     "Report #{ id }, task #{ ref_task.id }: Row committed total differs"
      check ref_row.not_committed(), com_row.not_committed(), "Report #{ id }, task #{ ref_task.id }: Row not committed total differs"
      check ref_row.total(),         com_row.total(),         "Report #{ id }, task #{ ref_task.id }: Row overall total differs"

      ref_users = []
      ref_utfrs = []
      com_users = []
      com_utfrs = []

      ref.each_user_on_row( ref_row ) { | u, ut | ref_users << u; ref_utfrs << ut }
      com.each_user_on_row( com_row ) { | u, ut | com_users << u; com_utfrs << ut }

      ref_users.each_index do | uindex |
        ref_user = ref_users[ uindex ];
        ref_utfr = ref_utfrs[ uindex ];
        com_user = com_users[ uindex ];
        com_utfr = com_utfrs[ uindex ];

        next if equal_nils ref_user, com_user, "Report #{ id }, task #{ ref_task.id }, linear user index #{ uindex }: Differing nil/not-nil users"
        check ref_user.id.to_s, com_user.id.to_s, "Report #{ id }, task #{ ref_task.id }, linear user index #{ uindex }: Differing user IDs"

        next if equal_nils ref_utfr, com_utfr, "Report #{ id }, task #{ ref_task.id }, user #{ com_user.id }, linear user index #{ uindex }: Differing nil/not-nil user row totals"

        check ref_utfr.committed(),     com_utfr.committed(),     "Report #{ id }, task #{ ref_task.id }, user #{ com_user.id }, linear user index #{ uindex }: User row committed total differs"
        check ref_utfr.not_committed(), com_utfr.not_committed(), "Report #{ id }, task #{ ref_task.id }, user #{ com_user.id }, linear user index #{ uindex }: User row not committed total differs"
        check ref_utfr.total(),         com_utfr.total(),         "Report #{ id }, task #{ ref_task.id }, user #{ com_user.id }, linear user index #{ uindex }: User row overall total differs"
      end

      ref_cells = []
      com_cells = []

      ref.each_cell_for( ref_row ) { | c | ref_cells << c }
      com.each_cell_for( com_row ) { | c | com_cells << c }

      ref_cells.each_index do | cindex |
        ref_cell = ref_cells[ cindex ]
        com_cell = com_cells[ cindex ]

        next if equal_nils ref_cell, com_cell, "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }: Differing nil/not-nil cell data"

        check ref_cell.committed(),     com_cell.committed(),     "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }: Cell committed value differs"
        check ref_cell.not_committed(), com_cell.not_committed(), "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }: Cell not committed value differs"
        check ref_cell.total(),         com_cell.total(),         "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }: Cell overall total differs"

        ref_ucells = []
        com_ucells = []

        ref_users.each_index do | uindex |
          ref_user = ref_users[ uindex ];
          com_user = com_users[ uindex ];

          ref_ucells[ uindex ] = []
          com_ucells[ uindex ] = []

          ref.each_cell_for_user_on_row( ref_user, ref_row ) { | c | ref_ucells[ uindex ] << c }
          com.each_cell_for_user_on_row( com_user, com_row ) { | c | com_ucells[ uindex ] << c }
        end

        ref_users.each_index do | uindex |
          ref_user = ref_users[ uindex ];
          com_user = com_users[ uindex ];

          ref_uucells = ref_ucells[ uindex ]
          com_uucells = com_ucells[ uindex ]

          ref_uucells.each_index do | cindex |
            ref_uucell = ref_uucells[ cindex ]
            com_uucell = com_uucells[ cindex ]

            next if equal_nils ref_uucell, com_uucell, "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: Differing nil/not-nil user cell data"

            check ref_uucell.committed(),     com_uucell.committed(),     "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User cell committed value differs"
            check ref_uucell.not_committed(), com_uucell.not_committed(), "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User cell not committed value differs"
            check ref_uucell.total(),         com_uucell.total(),         "Report #{ id }, task #{ ref_task.id }, linear cell index #{ cindex }, user #{ com_user.id }, linear user index #{ uindex }: User cell overall total differs"
          end
        end
      end
    end

    # Make sure there were no errors, else report the details

    assert @errors.empty?, @errors.map() { | e | e.join( "\n" ) }.join( "\n\n" )
  end

  # =========================================================================
  # Start by checking basic data metrics. If these are off, the fixture
  # data has been changed or didn't load; either way, other tests may not
  # work correctly so we need this file to be checked and updated.
  # =========================================================================

  test "01 make sure fixtures loaded OK" do
    assert_equal 54, SavedReport.count, "Wrong saved report count"
  end

  # =========================================================================
  # Basic model paranoia. If this stuff isn't working then TrackRecord
  # should be totally broken, but with non-PostgreSQL datbases you never
  # quite know what you're going to get; or someone might have a version
  # of Rails with a fault, a faulty local patch or a conflicting gem.
  # =========================================================================

  test "02 basic model paranoia" do
    r = SavedReport.new
    refute r.save, "A report was saved without a user"

    r.user = User.admins.first
    assert r.save, "A valid report could not be saved (A)"

    r.frequency = TrackRecordReport::Report::FREQUENCY.length + 1
    refute r.save, "An invalid report was saved (A)"

    r.frequency = 0
    r.task_filter = "foo"
    refute r.save, "An invalid report was saved (B)"

    r.task_filter = SavedReport::TASK_FILTER_VALUES[ 0 ]
    r.customer_sort_field = "foo"
    refute r.save, "An invalid report was saved (C)"

    r.customer_sort_field = SavedReport::CUSTOMER_SORT_FIELD_VALUES[ 0 ]
    r.project_sort_field = "foo"
    refute r.save, "An invalid report was saved (D)"

    r.project_sort_field = SavedReport::PROJECT_SORT_FIELD_VALUES[ 0 ]
    r.task_sort_field = "foo"
    refute r.save, "An invalid report was saved (E)"

    r.task_sort_field = SavedReport::TASK_SORT_FIELD_VALUES[ 0 ]
    r.task_grouping = "foo"
    refute r.save, "An invalid report was saved (F)"

    r.task_grouping = SavedReport::TASK_GROUPING_VALUES[ 0 ]
    assert r.save, "A valid report could not be saved (B)"

    r.generate_report

    assert_equal :all, r.range_start_cache, "Unexpected range start value (A)"
    assert_equal :all, r.range_end_cache,   "Unexpected range end value (A)"

    r.range_one_month = "this"
    r.save
    r.generate_report( true )

    assert_equal :this_month, r.range_start_cache, "Unexpected range start value (B)"
    assert_equal :this_month, r.range_end_cache,   "Unexpected range end value (B)"

    r.range_one_month = nil
    r.range_one_week = "last"
    r.save
    r.generate_report( true )

    assert_equal :last_week, r.range_start_cache, "Unexpected range start value (C)"
    assert_equal :last_week, r.range_end_cache,   "Unexpected range end value (C)"
  end

  # =========================================================================
  # Test access permission methods.
  # =========================================================================

  test "03 permissions" do

    admin    = User.admins.first
    oadmin   = ( User.admins - [ admin ] ).first
    manager  = User.managers.first
    omanager = ( User.managers - [ manager ] ).first
    user     = User.restricted.first
    ouser    = ( User.restricted - [ user ] ).first

    r = SavedReport.new
    r.user = admin
    r.shared = false
    r.save!

    refute r.is_permitted_for?( user    ), "Non-shared report should not be permitted for non-owning normal user"
    assert r.is_permitted_for?( manager ), "Non-shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( admin   ), "Non-shared report should be permitted for owning admin"
    assert r.is_permitted_for?( oadmin  ), "Non-shared report should be permitted for non-owning admin"

    refute r.can_be_modified_by?( user    ), "Non-shared report should not be mutable by non-owning normal user"
    refute r.can_be_modified_by?( manager ), "Non-shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( admin   ), "Non-shared report should be mutable by owning admin"
    assert r.can_be_modified_by?( oadmin  ), "Non-shared report should be mutable by non-owning admin"

    r.destroy # I know test-wrapping transactions take care of this, but it tests "#destroy".
    r = SavedReport.new
    r.user = admin
    r.shared = true
    r.save!

    assert r.is_permitted_for?( user    ), "Shared report should be permitted for non-owning normal user"
    assert r.is_permitted_for?( manager ), "Shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( admin   ), "Shared report should be permitted for owning admin"
    assert r.is_permitted_for?( oadmin  ), "Shared report should be permitted for non-owning admin"

    refute r.can_be_modified_by?( user    ), "Shared report should not be mutable by non-owning normal user"
    refute r.can_be_modified_by?( manager ), "Shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( admin   ), "Shared report should be mutable by non-owning admin"
    assert r.can_be_modified_by?( oadmin  ), "Shared report should be mutable by non-owning admin"

    r.destroy
    r = SavedReport.new
    r.user = manager
    r.shared = false
    r.save!

    refute r.is_permitted_for?( user     ), "Non-shared report should not be permitted for non-owning normal user"
    assert r.is_permitted_for?( manager  ), "Non-shared report should be permitted for owning manager"
    assert r.is_permitted_for?( omanager ), "Non-shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( oadmin   ), "Non-shared report should be permitted for non-owning admin"

    refute r.can_be_modified_by?( user     ), "Non-shared report should not be mutable by non-owning normal user"
    assert r.can_be_modified_by?( manager  ), "Non-shared report should be mutable by owning manager"
    refute r.can_be_modified_by?( omanager ), "Non-shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( oadmin   ), "Non-shared report should be mutable by non-owning admin"

    r.destroy
    r = SavedReport.new
    r.user = manager
    r.shared = true
    r.save!

    assert r.is_permitted_for?( user     ), "Shared report should be permitted for non-owning normal user"
    assert r.is_permitted_for?( manager  ), "Shared report should be permitted for owning manager"
    assert r.is_permitted_for?( omanager ), "Shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( oadmin   ), "Shared report should be permitted for non-owning admin"

    refute r.can_be_modified_by?( user     ), "Shared report should not be mutable by non-owning normal user"
    assert r.can_be_modified_by?( manager  ), "Shared report should be mutable by owning manager"
    refute r.can_be_modified_by?( omanager ), "Shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( oadmin   ), "Shared report should be mutable by non-owning admin"

    r.destroy
    r = SavedReport.new
    r.user = user
    r.shared = false
    r.save!

    assert r.is_permitted_for?( user     ), "Non-shared report should be permitted for owning normal user"
    refute r.is_permitted_for?( ouser    ), "Non-shared report should not be permitted for non-owning normal user"
    assert r.is_permitted_for?( omanager ), "Non-shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( oadmin   ), "Non-shared report should be permitted for non-owning admin"

    assert r.can_be_modified_by?( user     ), "Non-shared report should be mutable by owning normal user"
    refute r.can_be_modified_by?( ouser    ), "Non-shared report should not be mutable by non-owning normal user"
    refute r.can_be_modified_by?( omanager ), "Non-shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( oadmin   ), "Non-shared report should be mutable by non-owning admin"

    r.destroy
    r = SavedReport.new
    r.user = user
    r.shared = true
    r.save!

    assert r.is_permitted_for?( user     ), "Shared report should be permitted for owning normal user"
    assert r.is_permitted_for?( ouser    ), "Shared report should be permitted for non-owning normal user"
    assert r.is_permitted_for?( omanager ), "Shared report should be permitted for non-owning manager"
    assert r.is_permitted_for?( oadmin   ), "Shared report should be permitted for non-owning admin"

    assert r.can_be_modified_by?( user     ), "Shared report should be mutable by owning normal user"
    refute r.can_be_modified_by?( ouser    ), "Shared report should not be mutable by non-owning normal user"
    refute r.can_be_modified_by?( omanager ), "Shared report should not be mutable by non-owning manager"
    assert r.can_be_modified_by?( oadmin   ), "Shared report should be mutable by non-owning admin"

    r.destroy

  end

  # =========================================================================
  # The final test stage compares all test database reports against prior
  # built versions which are assumed-good. Although steps have been taken
  # to verify these, they span a large data set by design and hand-checking
  # every work packet is wholly unfeasible. Writing a secondary report
  # generator that iterated over them individually in Ruby, say, would also
  # be hopelessly slow (been there, tried that). As a result, we just do some
  # basic sanity checks on the reports before proceeding further. If both
  # this set of tests pass and the compare-to-reference tests later pass, we
  # know that the reference reports implicitly pass these tests too.
  #
  # These are broken up into smaller chunks so that a bit of feedback is
  # seen during testing and failures for one 'group' don't stop checks for
  # another 'group' which might otherwise have passed/failed meaningfully.
  # =========================================================================

  test "04A simple preset report checks" do

    # Reports with titles starting with numbers are used for comparisons.
    # 08... is all time committed, 09... not committed, 10... is everything.
    # So the totals in 8 + 9 should match 10; all should calculate all hours
    # though, since the "include committed" etc. flags are display-time not
    # compile-time options.

    sr8 = SavedReport.where("\"title\" LIKE '08%'").first.generate_report().compile()
    sr9 = SavedReport.where("\"title\" LIKE '09%'").first.generate_report().compile()
    srT = SavedReport.where("\"title\" LIKE '10%'").first.generate_report().compile()

    assert_equal sr8.total(), sr9.total(), "Report 8 and 9 overal totals should match"
    assert_equal sr8.total(), srT.total(), "Report 8 and 10 overal totals should match"

    sr8.each_row do | sr8_row, sr8_task |
      sr9_row = sr9.row( sr8_task.id.to_s )
      srT_row = srT.row( sr8_task.id.to_s )

      assert_equal sr8_row.try( :total ), sr9_row.try( :total ), "Report 8 and 9 row totals differ for task #{ sr8_task.id }"
      assert_equal sr8_row.try( :total ), srT_row.try( :total ), "Report 8 and 10 row totals differ for task #{ sr8_task.id }"
    end
  end

  # =========================================================================
  # =========================================================================

  test "04B simple preset report checks" do

    # Reports 40... to 43... have the same numeric totals but different column
    # spans, so totals should be the same with different column data.

    sr40 = SavedReport.where("\"title\" LIKE '40%'").first.generate_report().compile()
    sr41 = SavedReport.where("\"title\" LIKE '41%'").first.generate_report().compile()
    sr42 = SavedReport.where("\"title\" LIKE '42%'").first.generate_report().compile()
    sr43 = SavedReport.where("\"title\" LIKE '43%'").first.generate_report().compile()

    refute_equal sr40.column_count(), sr41.column_count(), "Report 40 and 41 column counts should differ"
    refute_equal sr40.column_count(), sr42.column_count(), "Report 40 and 42 column counts should differ"
    refute_equal sr40.column_count(), sr43.column_count(), "Report 40 and 43 column counts should differ"
    refute_equal sr41.column_count(), sr42.column_count(), "Report 41 and 42 column counts should differ"
    refute_equal sr42.column_count(), sr43.column_count(), "Report 42 and 43 column counts should differ"

    assert_equal sr40.total(), sr41.total(), "Report 40 and 41 overal totals should match"
    assert_equal sr40.total(), sr42.total(), "Report 40 and 42 overal totals should match"
    assert_equal sr40.total(), sr43.total(), "Report 40 and 43 overal totals should match"
    assert_equal sr41.total(), sr42.total(), "Report 41 and 42 overal totals should match"
    assert_equal sr42.total(), sr43.total(), "Report 42 and 43 overal totals should match"

    sr40.each_row do | sr40_row, sr40_task |
      sr41_row = sr41.row( sr40_task.id.to_s )
      sr42_row = sr42.row( sr40_task.id.to_s )
      sr43_row = sr43.row( sr40_task.id.to_s )

      assert_equal sr40_row.total(), sr41_row.total(), "Report 40 and 41 row totals should match for task #{ sr40_task.id }"
      assert_equal sr40_row.total(), sr42_row.total(), "Report 40 and 42 row totals should match for task #{ sr40_task.id }"
      assert_equal sr40_row.total(), sr43_row.total(), "Report 40 and 43 row totals should match for task #{ sr40_task.id }"
      assert_equal sr41_row.total(), sr42_row.total(), "Report 41 and 42 row totals should match for task #{ sr40_task.id }"
      assert_equal sr42_row.total(), sr43_row.total(), "Report 42 and 43 row totals should match for task #{ sr40_task.id }"
    end
  end

  # =========================================================================
  # =========================================================================

  test "04C simple preset report checks" do

    # Similar for reports 35..., 36... and 37..., which use a single day with
    # different column "widths" and should all end up with one column giving
    # the same totals.

    sr35 = SavedReport.where("\"title\" LIKE '35%'").first.generate_report().compile()
    sr36 = SavedReport.where("\"title\" LIKE '36%'").first.generate_report().compile()
    sr37 = SavedReport.where("\"title\" LIKE '37%'").first.generate_report().compile()

    assert_equal sr35.column_count(), sr36.column_count(), "Report 35 and 36 column counts should differ"
    assert_equal sr35.column_count(), sr37.column_count(), "Report 35 and 37 column counts should differ"
    assert_equal sr36.column_count(), sr37.column_count(), "Report 36 and 37 column counts should differ"

    assert_equal sr35.total(), sr36.total(), "Report 35 and 36 overal totals should match"
    assert_equal sr35.total(), sr37.total(), "Report 35 and 37 overal totals should match"
    assert_equal sr36.total(), sr37.total(), "Report 36 and 37 overal totals should match"

    sr35.each_row do | sr35_row, sr35_task |
      sr36_row = sr36.row( sr35_task.id.to_s )
      sr37_row = sr37.row( sr35_task.id.to_s )

      assert_equal sr35_row.total(), sr36_row.total(), "Report 35 and 36 row totals should match for task #{ sr35_task.id }"
      assert_equal sr35_row.total(), sr37_row.total(), "Report 35 and 37 row totals should match for task #{ sr35_task.id }"
      assert_equal sr36_row.total(), sr37_row.total(), "Report 36 and 37 row totals should match for task #{ sr35_task.id }"
    end
  end

  # =========================================================================
  # =========================================================================

  test "04D simple preset report checks" do

    # Report 14... is a base against which differing sorting options in reports
    # 17... through 22... inclusive can be compared. Totals should be the same,
    # but the actual row ordering should differ.

    sr14 = SavedReport.where("\"title\" LIKE '14%'").first.generate_report().compile()
    sr14_rows = []
    sr14.each_row { | sr14_row, sr14_task | sr14_rows << sr14_task.id.to_s }

    cmp = {}
    17.upto( 22 ) do | i |
      cmp[ i ] = {
        :report => SavedReport.where("\"title\" LIKE '#{ i }%'").first.generate_report().compile(),
        :rows => []
      }

      report = cmp[ i ][ :report ]

      assert_equal sr14.column_count(), report.column_count(), "Report 14 and #{ i } column counts should match"
      assert_equal sr14.total(),        report.total(),        "Report 14 and #{ i } overall totals should match"

      sr14.each_row do | sr14_row, sr14_task |
        report_row = report.row( sr14_task.id.to_s )
        assert_equal sr14_row.total(), report_row.total(), "Report 14 and #{ i } row totals should match for task #{ sr14_task.id }"
      end

      report.each_row { | row, task | cmp[ i ][ :rows ] << task.id.to_s }
    end

    17.upto( 22 ) do | i |
      refute_equal sr14_rows,      cmp[ i ][ :rows ],      "Report 14 and #{ i } have unexpected same-order rows"
      assert_equal sr14_rows.sort, cmp[ i ][ :rows ].sort, "Report 14 and { i } have unexpected differing sorted task lists"
    end
  end

  # =========================================================================
  # Compare internal report structures against reference test data.
  # =========================================================================

  reps = YAML::load_file( File.join( Rails.root, "test", "fixtures", "saved_reports.yml" ) )
  ids  = reps.values.map { | h | h[ "id" ] }

  ids.each do | id |
    class_eval %|
      test "99 compare report ID #{ id } with reference" do

        base = File.join( Rails.root, "test", "comparison_data", "saved_reports" )
        sr   = SavedReport.find( id )

        comparison = sr.generate_report().compile()

        # See "lib/tasks/db_dump_reports_for_tests.rake" for rationale.

        path      = File.join( base, "#{ id }.yaml.gz" )
        reference = Zlib::GzipReader.open( path ) { \| r_gz \| r_gz.read }
        reference = YAML::load( reference )

        compare_reports( id, reference, comparison )
      end
    |
  end
end
