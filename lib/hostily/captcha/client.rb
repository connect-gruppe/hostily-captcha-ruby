require "json"
require "openssl"
require "net/http"
require "uri"

module Hostily
  module Captcha
    DEFAULT_ENDPOINT = "https://captcha.hostily.de".freeze
    TOKEN_FIELDS = %w[hostily-captcha-token g-recaptcha-response].freeze
    SENSITIVE = /pass(word|wort|wd|phrase|code)|(^|[_\-\[])pass($|[_\-\]])|pwd|secret|csrf|xsrf|token|cvc|cvv/i

    # The service could not be reached or answered unusably (network, timeout, HTTP 5xx/429, no JSON).
    # The caller decides: let the request pass (fail open) or block it (fail closed).
    class UnavailableError < StandardError; end

    Result = Struct.new(:success, :gruende, :punkte, :error_codes, :hostname, :challenge_ts, keyword_init: true) do
      def self.from_hash(h)
        new(success: h["success"] == true, gruende: Array(h["gruende"]).map(&:to_s), punkte: h["punkte"],
            error_codes: Array(h["error-codes"]).map(&:to_s), hostname: h["hostname"].to_s, challenge_ts: h["challenge_ts"])
      end

      def success? = success

      # Secret missing or wrong: a configuration problem, not a spam verdict.
      def configuration_error?
        !(error_codes & %w[missing-input-secret invalid-input-secret]).empty?
      end
    end

    # Token from a params-like object (Hash, ActionController::Parameters, ...).
    def self.token_from(form)
      TOKEN_FIELDS.each do |name|
        v = form[name]
        v = form[name.to_sym] if v.nil? && form.respond_to?(:key?) && form.key?(name.to_sym)
        return v.strip if v.is_a?(String) && !v.strip.empty?
      end
      nil
    end

    # Form content for rule/honeypot checks. Token fields and anything that looks like a password, secret,
    # CSRF token or card code are removed (also in nested hashes).
    def self.content(form, exclude = [])
      form = form.to_unsafe_h if form.respond_to?(:to_unsafe_h)
      out = {}
      form.each do |name, value|
        key = name.to_s
        next if TOKEN_FIELDS.include?(key) || exclude.include?(key) || SENSITIVE.match?(key)

        value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
        out[key] =
          case value
          when Hash then content(value, exclude)
          when Array then value.map { |v| v.is_a?(Hash) ? content(v, exclude) : v.to_s }
          when String, Numeric, true, false, nil then value.to_s
          else next
          end
      end
      out
    end

    class Client
      attr_reader :endpoint, :timeout

      def initialize(secret, endpoint: DEFAULT_ENDPOINT, timeout: 5.0)
        @secret = secret
        @endpoint = endpoint.to_s.sub(%r{/+\z}, "")
        @timeout = timeout
      end

      # Raises UnavailableError if the service cannot be reached.
      def verify(token, remoteip: nil, formular: nil)
        if token.nil? || token.to_s.strip.empty?
          return Result.new(success: false, gruende: ["token_fehlt"], punkte: nil, error_codes: ["missing-input-response"], hostname: "", challenge_ts: nil)
        end

        body = { "secret" => @secret, "response" => token.to_s.strip }
        body["remoteip"] = remoteip if remoteip && !remoteip.to_s.empty?
        body["formular"] = formular unless formular.nil?
        status, raw = post(JSON.generate(body))
        data = begin
          JSON.parse(raw)
        rescue JSON::ParserError, TypeError
          nil
        end
        if status >= 500 || status == 429 || !data.is_a?(Hash) || !data.key?("success")
          raise UnavailableError, "hostily Captcha answered unusably (HTTP #{status})"
        end

        Result.from_hash(data)
      end

      def verify_form(form, remoteip: nil, send_content: true)
        verify(Captcha.token_from(form), remoteip: remoteip, formular: send_content ? Captcha.content(form) : nil)
      end

      private

      def post(json)
        uri = URI.parse("#{@endpoint}/api/v1/pruefen")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = http.read_timeout = http.write_timeout = @timeout
        req = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json", "Accept" => "application/json",
                                                   "User-Agent" => "hostily-captcha-ruby/#{VERSION}")
        req.body = json
        res = http.request(req)
        [res.code.to_i, res.body.to_s]
      rescue SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, URI::InvalidURIError, EOFError, Net::ProtocolError => e
        raise UnavailableError, "hostily Captcha not reachable: #{e.message}"
      end
    end
  end
end
