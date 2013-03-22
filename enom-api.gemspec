# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'enom-api/version'

Gem::Specification.new do |spec|
  spec.name          = "enom-api"
  spec.version       = EnomAPI::VERSION
  spec.authors       = ["Geoff Garside"]
  spec.email         = ["geoff@geoffgarside.co.uk"]
  spec.description   = %q{Client for communicating with the eNom API}
  spec.summary       = %q{eNom API Client}
  spec.homepage      = "https://github.com/m247/enom-api"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = %w(LICENSE.txt README.md)

  spec.add_dependency "demolisher", ">= 0.6.0"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "shoulda"
  spec.add_development_dependency "redcarpet"
end
