class AddPasswordFieldsToUser < ActiveRecord::Migration
  def change
    add_column :users, :password_digest,     :text
    add_column :users, :must_reset_password, :boolean
  end
end
