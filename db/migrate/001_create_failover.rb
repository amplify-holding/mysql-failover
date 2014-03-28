# coding: utf-8
Sequel.migration do
  up do
    create_table :tracking do
      primary_key :id
      column      :created_at, 'TIMESTAMP', null: false
      Bignum      :version, null: false
      DateTime    :mtime,   null: false
    end
  end

  down { drop_table :tracking }
end
