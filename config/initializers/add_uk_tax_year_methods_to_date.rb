########################################################################
# File::    add_uk_tax_year_methods_to_date.rb
# (C)::     Hipposoft 2008
#
# Purpose:: Add methods to return the beginning date, end date and date
#           of next UK tax year to the Date object. Comparable to the
#           existing start of year, end of year and next year methods
#           provided by Rails.
# ----------------------------------------------------------------------
#           27-Jun-2008 (ADH): Created.
########################################################################

# The UK tax year starts on the 6th of April and runs through to the 5th of
# April in the next calendar year, inclusive. For example, the inclusive date
# range 06-Apr-2007 to 05-Apr-2008 would be referred to as the 2007/2008 tax
# year.
#
# http://en.wikipedia.org/wiki/Taxation_in_the_United_Kingdom#The_tax_year

class Date

  # Return the beginning of the UK tax year containing the date represented
  # by the object on which the method is invoked. For dates on or after April
  # 6th in a particular year, the returned value is 06-Apr for that year. For
  # dates before April 6th in a particular year, the returned value is 06-Apr
  # for the previous year.

  def beginning_of_uk_tax_year
    if ( self.month < 4 or ( self.month == 4 and self.day <= 5 ) )
      Date.new( self.year - 1, 4, 6 )
    else
      Date.new( self.year,     4, 6 )
    end
  end

  # Counterpart to beginning_of_uk_tax_year. For dates on or after April 6th
  # in a particular year, the returned value is 05-Apr for the next year. For
  # dates before April 6th in a particular year, the returned value is 05-Apr
  # for that year.

  def end_of_uk_tax_year
    if ( self.month < 4 or ( self.month == 4 and self.day <= 5 ) )
      Date.new( self.year,     4, 5 )
    else
      Date.new( self.year + 1, 4, 5 )
    end
  end

  # Counterpart to beginning_of_uk_tax_year and end_of_uk_tax_year - alias
  # next_uk_tax_year to next_year. Returns a date with a year number 1 higher
  # that the date represented by the object on which the method is invoked,
  # with no other field values changed.

  alias :next_uk_tax_year :next_year
end
