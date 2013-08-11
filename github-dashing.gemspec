lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.authors = ["Ingo Schommer"]
  spec.description = 'Github Contributions Dashboard'
  spec.email = ['me@chillu.com']
  spec.files = %w(README.md Rakefile octokit.gemspec)
  spec.files += Dir.glob("lib/**/*.rb")
  spec.files += Dir.glob("spec/**/*")
  spec.homepage = 'https://github.com/chillu/github-dashing'
  spec.licenses = ['MIT']
  spec.name = 'github-dashing'
  spec.require_paths = ['lib']
  spec.required_rubygems_version = '>= 1.3.5'
  spec.summary = "Github Contributions Dashboard"
  spec.test_files = Dir.glob("spec/**/*")
end