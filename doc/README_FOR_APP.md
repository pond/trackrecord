# TrackRecord API documentation

This file is part of a set of automatically built documentation in HTML
format. If you are reading it in a text editor, you should instead look at
'doc/app/index.html' in your preferred web browser.

If you want to learn more about the TrackRecord internal structure, consider
getting an idea of the methods defined in the ApplicationController and
ApplicationHelper components first. I recommend then looking at the models,
so you become familiar with the application's underlying data structures.


## Database requirements

TrackRecord uses reasonably complex database queries from time to time but
does so through Rails as far as possible, so ActiveRecord should take care
of it - just choose your preferred adapter gem instead of e.g. `pg` in the
Gemfile, run `bundle install` and set up `config/database.yml`.

_**However, the strong exception is for reports.**_ See the documentation
on `TrackRecordReport::FREQUENCY` for details. _**This is essential
reading**_ if changing databases, since on non-PostgreSQL databases, by
default TrackRecord automatically enters a 'database safe mode' and report
generation is likely to run very slowly!


## Extensions

Aside from the usual mechanisms offered by Ruby and the Rails framework,
TrackRecord supports plug-in report generators. These take a raw report
object and render it in some format, perhaps (re)processing the report's
numerical data along the way. The CSV export function is implemented as
such a generator.

For more information, please see the `TrackRecordReportGenerator` module.


## Regenerating the documentation

Run `rake doc:reapp` to regenerate all files. See also the main application
`README.md` file at the top level.


## Charts controller

A Gruff-based charts controller is included to make pie charts (or if extended,
other charts) which you might like. It isn't used "in anger" at present since
the charts aren't really very useful in practice. See partial "shared/_hours"
for an example of how to introduce chart images into your views if you want
them.

You will need to uncomment the `gruff` and `rmagic` gems in `Gemfile` then
run `bundle install` to make any charts. There may be other dependencies too,
the most obvious being ImageMagick. Font `PetitaBold.ttf` is kept in the root
of the application for graph text; change this by editing the value of
`GRAPH_FONT` in file `config/initializers/general_config.rb`.

With the above steps completed, fetch an example stand-alone image as a test
by visiting your site with the following path:

```
/charts/0?committed=128&duration=168&not_committed=4&width=128
```
