require "cgi"

module Hostily
  module Captcha
    # View helper: <%= hostily_captcha_tag %> inside the <form>. Settings come from Hostily::Captcha.configuration.
    module ViewHelper
      # Widget element (and, unless script: false, the widget script). Options: site_key, modus, sprache, api.
      def hostily_captcha_tag(site_key: nil, modus: nil, sprache: nil, api: nil, script: true)
        c = Hostily::Captcha.configuration
        key = site_key || c.site_key
        return hostily_captcha_html("") if key.to_s.empty? # not configured: nothing to show

        base = (api || c.endpoint).to_s.sub(%r{/+\z}, "")
        attrs = { "data-site-key" => key, "data-api" => "#{base}/api/", "data-modus" => modus || c.modus }
        sp = sprache || c.sprache
        attrs["data-sprache"] = sp if sp
        html = +""
        html << %(<script src="#{CGI.escapeHTML(base)}/widget/hostily-captcha.js" defer></script>\n) if script
        html << "<hostily-captcha" + attrs.map { |k, v| %( #{k}="#{CGI.escapeHTML(v.to_s)}") }.join + "></hostily-captcha>"
        hostily_captcha_html(html)
      end

      private

      def hostily_captcha_html(str)
        str.respond_to?(:html_safe) ? str.html_safe : str
      end
    end

    # Controller method: verify_hostily_captcha -> true (pass) / false (reject). Rejections are logged.
    module ControllerMethods
      # fail_open: nil takes Hostily::Captcha.configuration.fail_open. Without secret + site key nothing is checked.
      def verify_hostily_captcha(fail_open: nil, send_content: true)
        c = Hostily::Captcha.configuration
        return true if c.secret.to_s.empty? || c.site_key.to_s.empty?

        fail_open = c.fail_open if fail_open.nil?
        result = Hostily::Captcha.client.verify_form(params, remoteip: request.remote_ip, send_content: send_content)
        if result.configuration_error?
          hostily_captcha_log(:error, "secret missing or wrong (#{result.error_codes.join(',')})")
          return fail_open
        end
        @hostily_captcha_result = result
        result.success?
      rescue Hostily::Captcha::UnavailableError => e
        hostily_captcha_log(:warn, e.message)
        fail_open
      end

      # Result of the last check (nil if the service was down, not configured or the secret was wrong).
      def hostily_captcha_result
        @hostily_captcha_result
      end

      private

      def hostily_captcha_log(level, message)
        l = respond_to?(:logger, true) ? logger : nil
        l&.public_send(level, "[hostily-captcha] #{message}") # never the secret
      end
    end

    if defined?(::Rails::Railtie)
      class Railtie < ::Rails::Railtie
        initializer "hostily_captcha.helpers" do
          ActiveSupport.on_load(:action_view) { include Hostily::Captcha::ViewHelper }
          ActiveSupport.on_load(:action_controller) { include Hostily::Captcha::ControllerMethods }
        end
      end
    end
  end
end
