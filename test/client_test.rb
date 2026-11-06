require "test_helper"

class ClientTest < Minitest::Test
  def with_stub(*args, **kw)
    s = StubServer.new(*args, **kw)
    yield s
  ensure
    s&.close
  end

  def test_success
    with_stub do |s|
      r = Hostily::Captcha::Client.new("s3cret", endpoint: s.url).verify(" tok ", remoteip: "1.2.3.4", formular: { "name" => "Ann" })
      assert r.success? && r.punkte == 0 && r.hostname == "example.de"
      assert_equal "POST /api/v1/pruefen HTTP/1.1\r\n", s.last[:line]
      assert_equal({ "secret" => "s3cret", "response" => "tok", "remoteip" => "1.2.3.4", "formular" => { "name" => "Ann" } }, s.last[:body])
      assert_equal "application/json", s.last[:headers]["content-type"]
      assert_equal "hostily-captcha-ruby/0.2.0", s.last[:headers]["user-agent"]
    end
  end

  def test_rejected_and_configuration_error
    with_stub(200, '{"success":false,"error-codes":["timeout-or-duplicate"],"gruende":["token_bereits_verwendet"]}') do |s|
      r = Hostily::Captcha::Client.new("s", endpoint: s.url).verify("t")
      refute r.success?
      assert_equal ["token_bereits_verwendet"], r.gruende
      refute r.configuration_error?
    end
    with_stub(200, '{"success":false,"error-codes":["invalid-input-secret"]}') do |s|
      assert Hostily::Captcha::Client.new("s", endpoint: s.url).verify("t").configuration_error?
    end
  end

  def test_missing_token_makes_no_call
    with_stub do |s|
      r = Hostily::Captcha::Client.new("s", endpoint: s.url).verify(nil)
      refute r.success?
      assert_equal ["token_fehlt"], r.gruende
      assert_equal 0, s.calls
    end
  end

  def test_unusable_answers_raise
    [[502, "Bad Gateway"], [200, "nope"], [200, '{"a":1}'], [429, '{"success":false}'], [302, ""]].each do |st, body|
      with_stub(st, body) do |s|
        assert_raises(Hostily::Captcha::UnavailableError, "#{st} #{body}") { Hostily::Captcha::Client.new("s", endpoint: s.url).verify("t") }
      end
    end
  end

  def test_unreachable_and_timeout
    assert_raises(Hostily::Captcha::UnavailableError) { Hostily::Captcha::Client.new("s", endpoint: "http://127.0.0.1:1", timeout: 2).verify("t") }
    with_stub(200, "{}", delay: 1.5) do |s|
      assert_raises(Hostily::Captcha::UnavailableError) { Hostily::Captcha::Client.new("s", endpoint: s.url, timeout: 0.3).verify("t") }
    end
  end

  def test_token_from
    assert_equal "a", Hostily::Captcha.token_from("hostily-captcha-token" => "a", "g-recaptcha-response" => "b")
    assert_equal "b", Hostily::Captcha.token_from("g-recaptcha-response" => "b")
    assert_nil Hostily::Captcha.token_from("x" => "1")
    assert_nil Hostily::Captcha.token_from("hostily-captcha-token" => " ")
  end

  def test_content_drops_passwords_and_tokens
    post = {
      "name" => "Ann", "password" => "x", "Passwort" => "x", "pass" => "x", "user_pass" => "x", "pwd" => "x", "password_confirmation" => "x",
      "_csrf" => "x", "authenticity_token" => "x", "api_secret" => "x", "hostily-captcha-token" => "t", "g-recaptcha-response" => "t",
      "passenger" => "Bob", "nested" => { "ok" => "v", "new_password" => "x" }, "n" => 5, "nothing" => nil
    }
    assert_equal({ "name" => "Ann", "passenger" => "Bob", "nested" => { "ok" => "v" }, "n" => "5", "nothing" => "" }, Hostily::Captcha.content(post))
  end

  def test_verify_form_never_sends_password
    with_stub do |s|
      Hostily::Captcha::Client.new("s", endpoint: s.url).verify_form({ "hostily-captcha-token" => "tok", "email" => "a@b.de", "password" => "hunter2" }, remoteip: "9.9.9.9")
      refute_includes s.last[:body].to_s, "hunter2"
      assert_equal({ "email" => "a@b.de" }, s.last[:body]["formular"])
    end
  end

  def test_e2e_real_service
    skip "no E2E service" unless ENV["HOSTILY_E2E_API"]
    api, secret, tokens = ENV["HOSTILY_E2E_API"], ENV["HOSTILY_E2E_SECRET"], ENV["HOSTILY_E2E_TOKENS"].split
    c = Hostily::Captcha::Client.new(secret, endpoint: api, timeout: 10)
    ok = c.verify_form({ "hostily-captcha-token" => tokens[0], "name" => "Ann", "message" => "Hello there", "password" => "hunter2" }, remoteip: "203.0.113.5")
    assert ok.success?, ok.inspect
    again = c.verify(tokens[0])
    refute again.success?
    assert_includes again.gruende, "token_bereits_verwendet"
    bad = Hostily::Captcha::Client.new("wrong-secret", endpoint: api, timeout: 10).verify(tokens[1])
    refute bad.success?
    assert bad.configuration_error?
  end
end
