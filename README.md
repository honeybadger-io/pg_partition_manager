# PgPartitionManager

Inspired by [pg_partman][1], this gem helps you manage [partitioned tables][2] in PostgreSQL >= 10.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_partition_manager'
```

And then execute:

```shell
bundle
```

Or install it yourself as:

```shell
gem install pg_partition_manager
```

## Usage

This is meant to be used via a daily cron job, to ensure that new tables are created before they are needed, and old tables are dropped when they aren't needed anymore.

Imagine a cron job like this:

```shell
@daily cd /app && ./bin/bundle exec ./script/make_partitions.rb
```

And a Ruby script like this:

```ruby
#!/usr/bin/env/ruby

require "pg_partition_manager"

PgPartitionManager::Time.process([
  {parent_table: "public.events", period: "month", premake: 1, retain: 3},
  {parent_table: "public.stats", period: "week", premake: 4, retain: 4},
  {parent_table: "public.observations", period: "day", retain: 7},
]
```

If the cron job runs on Monday, September 30th, 2019, and you had created the `events`, `stats`, and `observations` tables in your public schema, the following tables would be created:
* `public.events_p2019_09_01`
* `public.events_p2019_10_01`
* `public.stats_p2019_09_30`
* `public.stats_p2019_10_07`
* `public.stats_p2019_10_14`
* `public.stats_p2019_10_21`
* `public.observations_p2019_09_30`
* `public.observations_p2019_10_01`
* `public.observations_p2019_10_02`
* `public.observations_p2019_10_03`
* `public.observations_p2019_10_04`

The `premake` option specifies how many tables to create for dates after the current period, and the `retain` option specifies how many tables to keep for dates before the current period.

This gem uses the [pg gem][3] to connect to your database, and it assumes the DATABASE\_URL environment variable is populated with connection info. If this environment variable isn't defined, a connection to the server running on localhost will be attempted.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/honeybadger-io/pg_partition_manager.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[1]: https://github.com/pgpartman/pg_partman
[2]: https://www.postgresql.org/docs/current/ddl-partitioning.html
[3]: https://rubygems.org/gems/pg