Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'patm'
  s.version     = '3.1.0'
  s.summary     = 'PATtern Matching library'
  s.description = 'Pattern matching library for plain data structure'
  s.required_ruby_version = '>= 1.9.0'
  s.license     = 'MIT'

  s.author            = 'todesking'
  s.email             = 'discommucative@gmail.com'
  s.homepage          = 'https://github.com/todesking/patm'

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency('simplecov', '~> 0.7.1')
  s.add_development_dependency('simplecov-vim')
  s.add_development_dependency('rspec', '~>2.14')
  s.add_development_dependency('pry', '~>0.9')
  s.add_development_dependency('pattern-match', '=0.5.1') # for benchmarking
end
