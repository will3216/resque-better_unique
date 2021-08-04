# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/plugins/better_unique/version'

Gem::Specification.new do |spec|
  spec.name          = 'resque-better_unique'
  spec.version       = Resque::Plugins::BetterUnique::VERSION
  spec.authors       = ['Will Bryant']
  spec.email         = ['will.t.bryant@gmail.com']

  spec.summary       = %q{A resque plugin for better control over unique jobs}
  spec.description   = %q{There are a number of plugins which allow you define unique jobs, but each only handle on use-case. This allows you have full control over how uniqueness is defined}
  spec.homepage      = 'http://github.com/will3216/resque-better_unique'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 2.2.10'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'resque'
  spec.add_development_dependency 'redis'
  spec.add_development_dependency 'simplecov'
end
