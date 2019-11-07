require "test_helper"

class PgPartitionManagerTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::PgPartitionManager::VERSION
  end

  def test_it_bails_when_passed_an_invalid_period
    assert_raises ArgumentError do
      PgPartitionManager::Time.new({parent_table: "public.events", period: "hour"})
    end
  end

  def test_it_bails_when_passed_no_period
    assert_raises ArgumentError do
      PgPartitionManager::Time.new({parent_table: "public.events"})
    end
  end

  def test_it_creates_daily_tables_starting_today
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 11) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "day"})
        (11..15).each do |d|
          db.expect(:exec, true, ["create table if not exists public.events_p2019_10_#{d} partition of public.events for values from ('2019-10-#{d}') to ('2019-10-#{d + 1}')"])
        end
        pm.create_tables
      end
    end
    db.verify
  end

  def test_it_creates_weekly_tables_starting_this_week
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 7) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "week", premake: 2})
        [7, 14, 21].each do |d|
          db.expect(:exec, true, ["create table if not exists public.events_p2019_10_#{"%02d" % d} partition of public.events for values from ('2019-10-#{"%02d" % d}') to ('2019-10-#{d + 7}')"])
        end
        pm.create_tables
      end
    end
    db.verify
  end

  def test_it_creates_monthly_tables_starting_this_month
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 1) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "month", premake: 2})
        [10, 11, 12].each do |d|
          this_month = Date.new(2019, d, 1)
          db.expect(:exec, true, ["create table if not exists public.events_p2019_#{d}_01 partition of public.events for values from ('#{this_month}') to ('#{this_month.next_month}')"])
        end
        pm.create_tables
      end
    end
    db.verify
  end

  def test_it_drops_old_daily_tables
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 20) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "day", retain: 2})
        db.expect(:exec, [{"nspname" => "public", "relname" => "events_p2019_10_17"}], ["select nspname, relname from pg_class c inner join pg_namespace n on n.oid = c.relnamespace where nspname = 'public' and relname like 'events_p%' and relkind = 'r' and relname < 'events_p2019_10_18' order by 1, 2"])
        db.expect(:exec, true, ["drop table if exists public.events_p2019_10_17"])
        pm.drop_tables
      end
    end
    db.verify
  end

  def test_it_drops_old_weekly_tables
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 14) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "week", retain: 2})
        db.expect(:exec, [{"nspname" => "public", "relname" => "events_p2019_09_23"}], ["select nspname, relname from pg_class c inner join pg_namespace n on n.oid = c.relnamespace where nspname = 'public' and relname like 'events_p%' and relkind = 'r' and relname < 'events_p2019_09_30' order by 1, 2"])
        db.expect(:exec, true, ["drop table if exists public.events_p2019_09_23"])
        pm.drop_tables
      end
    end
    db.verify
  end

  def test_it_drops_old_monthly_tables
    PG.stub :connect, db do
      Date.stub :today, Date.new(2019, 10, 1) do
        pm = PgPartitionManager::Time.new({parent_table: "public.events", period: "month", retain: 2})
        db.expect(:exec, [{"nspname" => "public", "relname" => "events_p2019_07_01"}], ["select nspname, relname from pg_class c inner join pg_namespace n on n.oid = c.relnamespace where nspname = 'public' and relname like 'events_p%' and relkind = 'r' and relname < 'events_p2019_08_01' order by 1, 2"])
        db.expect(:exec, true, ["drop table if exists public.events_p2019_07_01"])
        pm.drop_tables
      end
    end
    db.verify
  end

  def test_it_processes_on_a_passed_db
    date = Date.new(2019, 11, 7)
    select_query = "select nspname, relname from pg_class c inner join pg_namespace n on n.oid = "\
      "c.relnamespace where nspname = 'public' and relname like 'events_p%' and relkind = 'r' and "\
      "relname < 'events_p2019_05_01' order by 1, 2"

    create_query = "create table if not exists public.events_p2019_11_01 partition of "\
      "public.events for values from ('2019-11-01') to ('2019-12-01')"

    Date.stub :today, date do
      side_db.expect(:exec, [], [select_query])
      side_db.expect(:exec, true, [create_query])
      PgPartitionManager::Time.process([
        {parent_table: "public.events", period: "month", premake: 0, db: side_db},
      ])
    end
    side_db.verify
  end

  def db
    @db ||= Minitest::Mock.new
  end

  def side_db
    @sid_db ||= Minitest::Mock.new
  end
end
