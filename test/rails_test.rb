require "test_helper"

# Helper and controller method without Rails: a fake controller / view carries the modules.
class RailsHelpersTest < Minitest::Test
  class Logger
    attr_reader :lines
    def initialize = @lines = []
    %i[warn error].each { |l| define_method(l) { |m| @lines << [l, m] } }
  end

  class Req
    def remote_ip = "203.0.113.9"
  end

  class FakeController
    include Hostily::Captcha::ControllerMethods
    attr_reader :params, :request, :logger
    def initialize(params) = (@params = params; @request = Req.new; @logger = Logger.new)
  end

  class FakeView
    include Hostily::Captcha::ViewHelper
  end

  def setup
    @old = Hostily::Captcha.instance_variable_get(:@configuration)
    Hostily::Captcha.instance_variable_set(:@configuration, nil)
  end

  def teardown
    Hostily::Captcha.instance_variable_set(:@configuration, @old)
  end

  def configure(**kw)
    Hostily::Captcha.configure { |c| kw.each { |k, v| c.public_send("#{k}=", v) } }
  end

  def test_view_helper
    configure(site_key: "KEY", endpoint: "https://c.example/", sprache: "de")
    html = FakeView.new.hostily_captcha_tag
    assert_includes html, '<script src="https://c.example/widget/hostily-captcha.js" defer></script>'
    assert_includes html, '<hostily-captcha data-site-key="KEY" data-api="https://c.example/api/" data-modus="sichtbar" data-sprache="de"></hostily-captcha>'
    refute_includes FakeView.new.hostily_captcha_tag(script: false), "<script"
    assert_includes FakeView.new.hostily_captcha_tag(site_key: '"><x', modus: "unsichtbar"), 'data-site-key="&quot;&gt;&lt;x" data-api="https://c.example/api/" data-modus="unsichtbar"'
  end

  def test_view_helper_modes
    configure(site_key: "KEY", endpoint: "https://c.example/")
    assert_includes FakeView.new.hostily_captcha_tag(modus: "schieben"), 'data-modus="schieben"></hostily-captcha>'
    html = FakeView.new.hostily_captcha_tag(modus: "halten", haltezeit: 2200)
    assert_includes html, 'data-modus="halten" data-haltezeit="2200"'
    assert_includes FakeView.new.hostily_captcha_tag(modus: "halten", haltezeit: 50), 'data-haltezeit="800"'
    refute_includes FakeView.new.hostily_captcha_tag(modus: "sichtbar", haltezeit: 2200), "data-haltezeit"
    portal = FakeView.new.hostily_captcha_tag(modus: "portal")
    refute_includes portal, "data-modus"
    assert_includes portal, 'data-api="https://c.example/api/"></hostily-captcha>'
    configure(modus: "halten", haltezeit: 1800)
    assert_includes FakeView.new.hostily_captcha_tag, 'data-modus="halten" data-haltezeit="1800"'
  end

  def test_view_helper_without_key_shows_nothing
    assert_equal "", FakeView.new.hostily_captcha_tag
  end

  def test_not_configured_checks_nothing
    s = StubServer.new
    configure(endpoint: s.url)
    assert FakeController.new({}).verify_hostily_captcha
    assert_equal 0, s.calls
  ensure
    s&.close
  end

  def test_controller_pass_and_reject
    s = StubServer.new
    configure(site_key: "K", secret: "sec", endpoint: s.url)
    c = FakeController.new("hostily-captcha-token" => "tok", "name" => "Ann", "password" => "hunter2")
    assert c.verify_hostily_captcha
    assert c.hostily_captcha_result.success?
    assert_equal "203.0.113.9", s.last[:body]["remoteip"]
    refute_includes s.last[:body].to_s, "hunter2"
    refute FakeController.new("name" => "Ann").verify_hostily_captcha # no token
  ensure
    s&.close
  end

  def test_rejection_and_fail_open_closed
    s = StubServer.new(200, '{"success":false,"gruende":["token_bereits_verwendet"]}')
    configure(site_key: "K", secret: "sec", endpoint: s.url)
    refute FakeController.new("hostily-captcha-token" => "t").verify_hostily_captcha
    s.close
    configure(endpoint: "http://127.0.0.1:1", timeout: 1)
    c = FakeController.new("hostily-captcha-token" => "t")
    assert c.verify_hostily_captcha # default: let pass
    assert_equal :warn, c.logger.lines.first[0]
    refute_includes c.logger.lines.to_s, "sec"
    refute c.verify_hostily_captcha(fail_open: false)
    configure(fail_open: false)
    refute FakeController.new("hostily-captcha-token" => "t").verify_hostily_captcha
  end

  def test_wrong_secret_acts_like_outage_and_is_logged
    s = StubServer.new(200, '{"success":false,"error-codes":["invalid-input-secret"]}')
    configure(site_key: "K", secret: "sec", endpoint: s.url)
    c = FakeController.new("hostily-captcha-token" => "t")
    assert c.verify_hostily_captcha
    assert_equal :error, c.logger.lines.first[0]
    configure(fail_open: false)
    refute FakeController.new("hostily-captcha-token" => "t").verify_hostily_captcha
  ensure
    s&.close
  end
end
