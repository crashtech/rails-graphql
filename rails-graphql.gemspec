# frozen_string_literal: true
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'rails/graphql/version'
require 'date'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'rails-graphql'
  s.version     = Rails::GraphQL::VERSION
  s.date        = Date.today.to_s
  s.authors     = ['Carlos Silva']
  s.email       = ['carlos.silva@virtualshield.com']
  s.homepage    = 'https://github.com/virtualshield/rails-graphql'
  s.license     = 'MIT'
  s.summary     = 'A GraphQL server for Rails applications'
  s.description = 'A GraphQL server implementaion for Rails applications that focus on performance and simpler integration with Rails DSL'
  s.metadata    = {
    'homepage_uri'    => 'https://virtualshield.com/rails-graphql',
    "source_code_uri" => 'https://github.com/virtualshield/rails-graphql',
    'bug_tracker_uri' => 'https://github.com/virtualshield/rails-graphql/issues',
    'changelog_uri'   => 'https://github.com/virtualshield/rails-graphql/blob/master/CHANGELOG.md',
  }

  s.require_paths = ['lib']

  s.files        = Dir['MIT-LICENSE', 'README.rdoc', 'lib/**/*', 'ext/**/*', 'Rakefile']
  s.executables  = Dir['bin/**/*']
  s.test_files   = Dir['test/**/*']
  s.rdoc_options = ['--title', 'GraphQL server for Rails']

  s.add_dependency 'rails', '>= 5.0'
  s.add_dependency 'ffi', '~> 1.12'

  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'benchmark-ips'
  s.add_development_dependency 'minitest', '~> 5.14.0'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'rake-compiler-dock'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'rubocop'
end
