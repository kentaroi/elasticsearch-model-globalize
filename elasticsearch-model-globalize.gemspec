# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elasticsearch/model/globalize/version'

Gem::Specification.new do |spec|
  spec.name          = "elasticsearch-model-globalize"
  spec.version       = Elasticsearch::Model::Globalize::VERSION
  spec.authors       = ["Kentaro Imai"]
  spec.email         = ["kentaroi@gmail.com"]
  spec.summary       = %q{A library for using elasticsearch-model with globalize}
  spec.description   = %q{A library for using elasticsearch-model with globalize}
  spec.homepage      = "https://github.com/kentaroi/elasticsearch-model-globalize"
  spec.license       = "Apache License, Version 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'elasticsearch-model'
  spec.add_dependency 'globalize'
  spec.add_dependency 'activerecord'
  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "minitest", "~> 4.0"
  spec.add_development_dependency "shoulda-context"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "pry-alias"
  spec.add_development_dependency "elasticsearch-extensions"
end
