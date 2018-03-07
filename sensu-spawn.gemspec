# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "sensu-spawn"
  spec.version       = "2.2.1"
  spec.authors       = ["Sean Porter"]
  spec.email         = ["portertech@gmail.com", "engineering@sensu.io"]
  spec.summary       = "The Sensu spawn process library"
  spec.description   = "The Sensu spawn process library"
  spec.homepage      = "https://github.com/sensu/sensu-spawn"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*") + %w[sensu-spawn.gemspec README.md CHANGELOG.md LICENSE.txt]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "eventmachine"
  spec.add_dependency "em-worker", "0.0.2"
  spec.add_dependency "childprocess", "0.5.8"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "10.5.0"
  spec.add_development_dependency "rspec"

  spec.cert_chain    = ["certs/sensu.pem"]
  spec.signing_key   = File.expand_path("~/.ssh/gem-sensu-private_key.pem") if $0 =~ /gem\z/
end
