require "pg_partition_manager/version"
require "date"
require "pg"

module PgPartitionManager
  class Error < StandardError; end

  class Time
    def initialize(parent_table:, period:, premake: 4, retain: nil, start: Date.today, db: nil)
      raise ArgumentError, "Period must be 'month', 'week', or 'day'" unless ["month", "week", "day"].include?(period)

      @parent_table = parent_table
      @period = period
      @premake = premake
      @retain = retain ||
        case @period
        when "month"
          6 # Default to 6 months
        when "week"
          4 # Default to 4 weeks
        when "day"
          7 # Default to 7 days
        end
      @start =
        case @period
         when "month"
           start - start.day + 1 # First day of the current month
         when "week"
           start - (start.cwday - 1) # First calendar day of the current week
         when "day"
           start
        end
      @db = db || PG.connect(ENV["DATABASE_URL"])
    end

    # Drop the tables that contain data that should be expired based on the
    # retention period
    def drop_tables
      schema, table = @parent_table.split(".")
      table_suffix = retention.to_s.tr("-", "_")

      result = @db.exec("select nspname, relname from pg_class c inner join pg_namespace n on n.oid = c.relnamespace where nspname = '#{schema}' and relname like '#{table}_p%' and relkind = 'r' and relname < '#{table}_p#{table_suffix}' order by 1, 2")
      result.map do |row|
        child_table = "#{row["nspname"]}.#{row["relname"]}"
        @db.exec("drop table if exists #{child_table}")
        child_table
      end
    end

    # Create tables to hold future data
    def create_tables
      schema, table = @parent_table.split(".")
      start = @start
      stop = period_end(start)

      # Note that this starts in the *current* period, so we start at 0 rather
      # than 1 for the range, to be sure the current period gets a table *and*
      # we make the number of desired future tables
      (0..@premake).map do |month|
        child_table = "#{schema}.#{table}_p#{start.to_s.tr("-", "_")}"
        @db.exec("create table if not exists #{child_table} partition of #{schema}.#{table} for values from ('#{start}') to ('#{stop}')")
        start = stop
        stop = period_end(start)
        child_table
      end
    end

    # Return the date for the oldest table to keep, based on the retention setting
    def retention
      case @period
      when "month"
        @start << @retain
      when "week"
        @start - (@retain * 7)
      when "day"
        @start - @retain
      end
    end

    # Return the begin and end dates for the next partition range
    def period_end(start)
      case @period
      when "month"
        start >> 1
      when "week"
        start + 7
      when "day"
        start + 1
      end
    end

    # A convenience method for doing all the maintenance for a list of partitions
    def self.process(partitions)
      partitions.each do |part|
        pm = new(part)
        pm.drop_tables
        pm.create_tables
      end
    end
  end
end
