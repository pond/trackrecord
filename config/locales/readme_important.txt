Translating TrackRecord
=======================

In addition to the master locale files here:

  config/locales/en.yml
  config/locales/will_paginate.en.yml

...you also need to translate help page text. This is kept in a separate file
because of the amount of text and often extensive HTML markup required. See:

  app/views/help/_translations.en.html.erb

Note the leading underscore in "_translations.en.html.erb". This approach to
translating large chunks of text was taken from here:

  http://stackoverflow.com/questions/9172590/rails-strategies-for-internationalization-of-large-amounts-of-text-and-some-htm

To create a new translation, copy the master English files under names with
the relevant new two-letter country code, for example:

  config/locales/fr.yml
  config/locales/will_paginate.fr.yml
  app/views/help/_translations.fr.html.erb

...then update the strings therein. For more information on country codes,
see ISO 3166 and/or, at the time of writing:

  http://www.iso.org/iso/country_codes.htm
  http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
