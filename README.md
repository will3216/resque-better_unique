# Resque::BetterUnique

There are currently a number of resque plugins that provide this functionality in some form or another, but one thing they all lack is the ability to control how the unique constraint is defined. Sometimes, a job should only be unique until a worker begins processing it, in other cases you will want the job to remain unique until the job completes, or maybe even long after the job has completed. This allows you to do all of the above and more with a single gem.

The functionality of this gem is based on the sidekiq equivalent [sidekiq-unique-jobs](https://github.com/mhenrixon/sidekiq-unique-jobs).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resque-better_unique'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install resque-better_unique

## Usage
Include this plugin into your job class and call the `unique` method
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :while_executing, timeout: 5.minutes
end
```

The unique_job method takes up to two arguments:
- mode: (default=:until_executed)
  * while_executing: only one distinct job can be processed at a time
  * until_executing: only one job can be queued at a time
  * until_executed: only one job can be queued or processed at a time
  * until_timeout: only one job can be queued or processed in a given time period
- options: Hash of options
  * timeout - integer or object that responds to to_i - How long should a lock live
  * unique_args - a proc or a symbol which takes the arguments of perform and returns the arguments that should be used to determine uniqueness

### Examples:
Specify method to define unique args:
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :while_executing, timeout: 5.minutes, unique_args: unique_job_arguments

  def self.unique_job_arguments(*args)
    [args[0], args[3]]
  end
end
```

Specify Proc to define unique args:
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :while_executing, timeout: 5.minutes, unique_args: ->(*args) { [args[0], args[3]] }
end
```

Override lock_key method:
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :while_executing, timeout: 5.minutes

  def self.lock_key(*args)
    "lock:my_lock:#{args.to_s}"
  end
end
```

Clear lock for a single job:
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :until_executed, timeout: 5.minutes
end

Resque.enqueue(MyWorker, {some: :args})
MyWorker.release_lock({some: :args})
```

Clear all locks for a worker class:
```ruby
class MyWorker
  include Resque::Plugins::BetterUnique
  unique_job :while_executing, timeout: 5.minutes
end
100.times { Resque.enqueue(MyWorker, rand(1000))}
MyWorker.release_all_locks
```
NOTE: requires redis-server >= 2.8

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/resque-better_unique.
