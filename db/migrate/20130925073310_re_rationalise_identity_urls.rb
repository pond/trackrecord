# This is unavoidably one-way.

class ReRationaliseIdentityUrls < ActiveRecord::Migration
  def up
    User.find_each do | user |
      user.identity_url = User.rationalise_id( user.identity_url )
      user.save!
    end
  end
end
