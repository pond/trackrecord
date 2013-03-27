########################################################################
# File::    extend_numeric_class_with_precision_method.rb
# (C)::     Hipposoft 2008, 2009
#
# Purpose:: Extend Numeric to provide a 'precision' method which rounds
#           numbers to the required number of decimal places. Adapted
#           on 2008-05-17 from:
#
#           http://rubyglasses.blogspot.com/2007/09/float-precision.html
# ----------------------------------------------------------------------
#           24-Jun-2008 (ADH): Separated from application.rb.
########################################################################

class Numeric
  def precision( dp )
    return self.round if ( dp == 0 )
    mul = 10.0 ** dp
    ( self * mul ).round / mul
  end
end
