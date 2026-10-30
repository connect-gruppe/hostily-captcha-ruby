require_relative "lib/hostily/captcha/version"

Gem::Specification.new do |s|
  s.name = "hostily-captcha"
  s.version = Hostily::Captcha::VERSION
  s.summary = "Server-side client for hostily Captcha (captcha.hostily.de), with Rails helpers"
  s.description = "Verify the token of a submitted form against hostily Captcha. Net::HTTP only; optional Rails view helper and controller method."
  s.authors = ["connect - Media & Teledienst"]
  s.license = "MIT"
  s.homepage = "https://captcha.hostily.de"
  s.metadata = { "source_code_uri" => "https://github.com/connect-gruppe/hostily-captcha-ruby" }
  s.required_ruby_version = ">= 3.1"
  s.files = Dir["lib/**/*.rb"] + %w[LICENSE README.md]
  s.require_paths = ["lib"]
end
