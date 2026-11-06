require "hostily/captcha/version"
require "hostily/captcha/client"
require "hostily/captcha/rails"

module Hostily
  module Captcha
    class Configuration
      attr_accessor :secret, :site_key, :endpoint, :timeout, :modus, :haltezeit, :sprache, :fail_open

      def initialize
        @endpoint = DEFAULT_ENDPOINT
        @timeout = 5.0
        @modus = "sichtbar"
        @haltezeit = nil # ms (800-3000), only for modus "halten"; nil: the widget default (1500)
        @sprache = nil # nil: the widget decides (page language)
        @fail_open = true # service down: let the request pass (false: block)
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
      end

      # Client from the global configuration.
      def client
        c = configuration
        Client.new(c.secret.to_s, endpoint: c.endpoint, timeout: c.timeout)
      end
    end
  end
end
