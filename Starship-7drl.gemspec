Gem::Specification.new do |s|
  s.name    = 'Starship-7drl'
  s.version = '0.0.1'
  s.summary = 'Written for 7DRL contest 2011'

  s.author   = 'Justin Reardon'
  s.email    = 'me@jmreardon.com'
  #s.homepage = 'https://github.com/matschaffer/my_awesome_gem'

  # Include everything in the lib folder
  s.files = Dir['lib/**/*']
  s.executables  = ['Starship-7drl']
  s.require_paths      = ["lib"]

  # Supress the warning about no rubyforge project
  s.rubyforge_project = 'nowarning'
end