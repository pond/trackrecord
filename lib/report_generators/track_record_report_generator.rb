########################################################################
# File::    track_record_report_generator_base.rb
# (C)::     Hipposoft 2013
#
# Purpose:: Base class for a report generator. Generators take a
#           calculated TrackRecordReport instance and produce some user
#           visible output, e.g. a CSV file, perhaps processing the
#           numbers further as they do so.
# ----------------------------------------------------------------------
#           25-Jul-2013 (ADH): Created.
########################################################################

# Namespace and template for generators.
#
# Place generator implementations inside "lib/report_generators",
# alongside this file. See below for module and filename details.
#
#
# == Namespacing
#
# Albeit verbose, please use a module name prefix of
# <tt>TrackRecordReportGenerator::</tt> followed by a name of your choice.
# To avoid collision with other future generators, include some kind of
# unique-to-you string, such as capitalised reverse DNS string if you
# own a domain. For example, core TrackRecord generators use names of
# the form <tt>TrackRecordReportGenerator::UkOrgPond...</tt> as I maintain
# the domain "pond.org.uk". Your module's filename drops out from this;
# convert punctuation to single underscores and change everything to
# lower case (<tt>track_record_report_generator_<foo>.rb</tt>).
#
# If you are not planning on adding in any other third party generators,
# should any exist, then a globally unique name is unimportant - just
# never use +UkOrgPond+ as part of your prefix.
#
# Private methods you write in the module structure recommended for
# generators are indeed class-private, but risk namespace collision
# with other private methods in ReportsController (see "execution
# context" later). To avoid this, consider using a self-unique prefix
# for all of your private method names; again, reverse DNS approaches
# are good.
#
#
# == Implementation
#
# Base your implementation on the provided template in the form of
# the +TrackRecordReportGenerator+ module - this is a dummy example
# implementation of a kind of "nil generator" that doesn't do anything.
# The module's structure and each public method that you must implement
# are documented in-place. Please see the implementation file and read
# the comments for details. The comments describe the formal API that
# must be implemented. You must implement all documented methods unless
# explicitly described as optional by associated comments.
# 
#
# == Execution context
#
# Code in your module is run by an instance of ReportsController as part
# of +show+ request handling. The controller extends itself with your
# module's methods and calls them as if an integral part of itself.
#
# You must not call any part of ReportController's bespoke internal API
# unless you are prepared to track any changes to the implementation in
# future TrackRecord releases, as this is considered internal API, not
# part of the public interface for generators. You can however (and
# must) use standard Rails calls, in particular <tt>render(...)</tt>,
# <tt>send_data(...)</tt> or an equivalent at the end of generation to
# send the generator's result to the user's web browser.
#
# Modules +TrackRecordReport+ and +TrackRecordSections+, implemented in
# the +lib+ folder, are included by ReportsController. You will most
# definitely need to be familiar with the report and section mechanism
# therein in order to understand a raw report object and interpret its
# contents to generate something to send to the browser. These modules
# form part of the formal public API that your generator is able to call.
# This API will not change unless explicitly documented in a release's
# change log. Even then, any change will endeavour to be backwards
# compatible and require no alterations to existing generators, though
# you might want to make changes to take advantage of new features in the
# new API.
#
# Application helper code is considered part of the internal TrackRecord
# implementation, but should you wish to use it at your own risk, the
# following pattern is recommended:
#
#   helper = Object.new.extend( ApplicationHelper )
#   helper.helper_method( ...params... )
#
# Though there is a performance penalty from run-time extending a new
# object with helper methods and though there will be some context
# restrictions arising, this is the cleanest / most self-contained way
# to access that kind of functionality without risking name space
# collisions or other undesirable side effects.
#
#
# == Internationalisation
#
# If you want to look up bespoke message tokens you will have to add
# locale files into +config/locales+. Use a filename equal to your
# generator's Ruby filename, but with the +.en.yml+ extension.
#
# Since a Rails controller has unrestricted access to internationalisation
# functions such as the <tt>t(...)</tt> shortcut and since your code
# executes as if part of a ReportsController instance, you can use the
# Rails internationalisation API normally, without any restrictions.
#
#
# == View templates
#
# If you want to render using templates, create a directory that sits
# alongside your class's Ruby file, with the same name as the Ruby file
# excluding the +.rb+ extension. Place your templates inside there. Then
# render them with a relative path thus:
#
#   render :template => "../../lib/report_generators/<your_folder_name>/<foo>"
#
# Other render types can be achieved with similar approaches. If you do
# not defeat the use of a layout with <tt>:layout => false</tt> then your
# report will be rendered within the main content DIV of the application
# layout. For generation of data that's intended to be downloaded rather
# than displayed, using +send_data+ instead of +render+ is typically the
# most appropriate approach. The built-in CSV export generator does this.
#
# 
# == Troubleshooting
# === Double render errors
#
# Remember that, as per documentation for the method in the
# +TrackRecordReportGenerator+ module's comments, your +generate+
# implementation *must return +nil+* to indicate it was successful, else
# it returns a string that's shown to the user in the +flash+. Since showing
# an error means that ReportsController ends up doing its own render of the
# report view, accidentally failing to return +nil+ will lead to double
# render errors if your generator has already rendered or sent data. 
#
#
module TrackRecordReportGenerator

  # A generator must return 'true' if it understands how to generate
  # reports of the given type. At the time of writing, known types are:
  #
  #   :task  A standard task report without user details. In HTML,
  #          columns represent periods of time, rows represent tasks.
  #
  #   :user  A user summary report without time details. In HTML,
  #          columns represent users, rows represent tasks.
  #
  #   :comprehensive  A full report, like a task report but with the
  #          contributions of individual users provided on a per-task
  #          basis (three dimensions of data - time, tasks, users).
  #
  # Depending on your generator's behaviour, it might not make sense to
  # map your export capabilities to the three types offered by
  # TrackRecord. In that case, you'll have to map the types as best you
  # can, choosing appropriate button titles to convey the behaviour to
  # the user (see "invocation_button_title_for"). Bear in mind that a
  # TrackRecordReport::Report object may omit information not required
  # by the user for the HTML report they have initially viewed; for
  # example, a tasks-only report may omit user-specific information.
  #
  def understands?( type )
    false
  end

  # Return a human-readable title, used in a button which will cause your
  # report generator to be invoked for the given report type.
  #
  # Only called for types your generator understands (see "understands?").
  #
  def invocation_button_title_for( type )
    ""
  end

  # Return an indication of options available for a report of the given
  # type. If you have no options, return nil or an empty array; else an
  # array of hashes. Each hash key indicates the kind of option to show
  # in the form and each hash value describes the option's contents. The
  # values are themselves hashes providing that description, as per the
  # table below.
  #
  # When your "generate" method is called, an optional bit of the Rails
  # params hash is passed in. It's the bit containing the result of the
  # submitted form options that you specified, so when you give names
  # you want for form elements (again see table below), those names will
  # end up as the keys in the hash that yield the submitted form values.
  #
  #   Top-level key   Value
  #   ========================================================================
  #   :checkbox       A hash describing a checkbox:
  #                   --------------------------------------------------------
  #                   :label    User-visible label text
  #                   :checked  Initial on/off state (boolean)
  #                   :id       Form element ID, must be HTML-valid, appears
  #                             in the form result hash passed to "generate".
  #                             Only needs to be unique to your generator, as
  #                             steps are taken externally to make sure the
  #                             generated HTML uses a truly unique ID.
  #
  #                   A checked checkbox will appear in the options hash in
  #                   "generate" as a key of the given ID and a value of "1".
  #
  #   :radio          A hash describing a radio:
  #                   --------------------------------------------------------
  #                   :label    User-visible label text
  #                   :checked  Initial on/off state (boolean)
  #                   :name     Radio group name; any radio buttons with the
  #                             same name will belong to the same group. As
  #                             with ":id" for checkboxes, only needs to be
  #                             unique to your generator; must be HTML-valid.
  #                   :id       Form element ID, as for checkboxes.
  #
  #                   A selected radio button within a group will appear in
  #                   the options hash in "generate" as a key of the given
  #                   name and a value of the ID given for the selected item.
  #
  #   :gap            A gap that visually separates collections of options.
  #                   Use a value of "true".
  #
  # Options are displayed to the user in a vertical column in the same order
  # as in the array (first array entry shown topmost).
  #
  # Only called for types your generator understands (see "understands?").
  #
  def invocation_options_for( type )
    nil
  end

  # Generate a report of the given type using the given TrackRecordReport
  # instance as the basis. This is always called from within the view
  # context (via ERB, in practice) so you have access to helper methods,
  # though TrackRecord's bespoke helpers are technically an internal API.
  # If you use them, be prepared to have to update your code when they
  # change. To avoid such issues, use only core Rails helpers.
  #
  # The options hash is filled in with the form submission result of any
  # options you specified via the "invocation_options_for" method.
  #
  # Return either 'nil' to indicate success, else return a string. Such a
  # string is taken to be an error message and is shown to the user in the
  # page 'flash' area, without any prefix or suffix text added. In the
  # case of success, use "render" or "send_data" to present the report
  # to the user via their browser, or cause the browser to download report
  # data. If indicating failure, you MUST NOT perform rendering actions as
  # TrackRecord will need to render a page reporting the error, so a double
  # render exception would result if you'd already rendered something.
  #
  # Only called for types your generator understands (see "understands?").
  #
  def generate( type, report, options = {} )
    nil
  end

  # If you want any private methods you can achieve this by defining them
  # inside a "self.extended" implementation as shown below (see actual
  # implementation in <tt>lib/report_generators/track_record_report_generator.rb</tt>),
  # so that you can include your own private methods and really have them
  # private, despite writing module code. See for example:
  #
  # http://stackoverflow.com/questions/318850/private-module-methods-in-ruby
  #
  # Even if your initial implementation has no private methods you should
  # follow this pattern so that it's easy to add private code later.
  #
  def self.extended( base )
    class << base 
      private

      # Private methods go here...
      #
      #   def some_private_method
      #     ...
      #   end

    end # class << base
  end   # def self.extended( base )
end     # module TrackRecordReportGenerator
