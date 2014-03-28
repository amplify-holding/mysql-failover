# coding: utf-8
Sequel.migration do
  up do
    alter_table :tracking do
      add_column :mtime_int, Bignum
    end

    self << 'UPDATE tracking SET mtime_int = UNIX_TIMESTAMP(mtime)'

    alter_table :tracking do
      drop_column :mtime
      rename_column :mtime_int, :mtime
    end
  end

  down do
    alter_table :tracking do
      set_column_type :mtime, DateTime
    end
  end
end
