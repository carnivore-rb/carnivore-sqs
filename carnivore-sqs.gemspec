$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'carnivore-sqs/version'
Gem::Specification.new do |s|
  s.name = 'carnivore-sqs'
  s.version = Carnivore::Sqs::VERSION.version
  s.summary = 'Message processing helper'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'https://github.com/carnivore-rb/carnivore-sqs'
  s.description = 'Carnivore SQS source'
  s.license = 'Apache 2.0'
  s.require_path = 'lib'
  s.add_dependency 'carnivore', '>= 0.1.8'
  s.add_dependency 'fog'
  s.files = Dir['**/*']
end
