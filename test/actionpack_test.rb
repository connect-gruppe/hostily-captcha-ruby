require "test_helper"
begin
  require "action_view"
  require "action_controller"
rescue LoadError
  puts "actionpack not installed - skipping Rails integration test"
end

if defined?(ActionView::Base) && defined?(ActionController::Parameters)
  class ActionPackTest < Minitest::Test
    def test_view_helper_is_html_safe_in_action_view
      ActionView::Base.include(Hostily::Captcha::ViewHelper)
      Hostily::Captcha.configure { |c| c.site_key = "KEY" }
      view = ActionView::Base.empty
      out = view.hostily_captcha_tag
      assert out.html_safe?
      assert_includes out, "<hostily-captcha"
    end

    def test_content_and_token_from_strong_parameters
      params = ActionController::Parameters.new("hostily-captcha-token" => "tok", "user" => { "email" => "a@b.de", "password" => "x" })
      assert_equal "tok", Hostily::Captcha.token_from(params)
      assert_equal({ "user" => { "email" => "a@b.de" } }, Hostily::Captcha.content(params))
    end
  end
end
