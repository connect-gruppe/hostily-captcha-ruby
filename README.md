# hostily-captcha (Ruby)

**Deutsch**

Kleiner Client für [hostily Captcha](https://captcha.hostily.de) mit Rails-Helfern. Ruby ≥ 3.1, nur `Net::HTTP` (keine fremden Gems).

```ruby
gem "hostily-captcha"
```

**Ohne Rails**

```ruby
require "hostily/captcha"

captcha = Hostily::Captcha::Client.new(ENV.fetch("HOSTILY_CAPTCHA_SECRET")) # Secret nur auf dem Server!
begin
  result = captcha.verify_form(params, remoteip: request.ip)
rescue Hostily::Captcha::UnavailableError
  # Dienst nicht erreichbar: blockieren oder durchlassen - Ihre Entscheidung
end
puts result.gruende, result.punkte unless result.success?
```

**Rails** (`config/initializers/hostily_captcha.rb`)

```ruby
Hostily::Captcha.configure do |c|
  c.site_key = "…"                              # öffentlich
  c.secret   = ENV["HOSTILY_CAPTCHA_SECRET"]    # nur auf dem Server
  # c.endpoint = "https://captcha.hostily.de"   # Vorgabe
  # c.modus = "sichtbar" | "unsichtbar" | "halten" | "schieben" | "portal"; c.haltezeit = 1500 (ms, nur halten); c.sprache = "de" | "en" (Vorgabe: Seitensprache)
  # c.fail_open = true                          # Dienst down: durchlassen (Vorgabe); false = blockieren
end
```

```erb
<%= form_with url: contact_path do |f| %>
  …
  <%= hostily_captcha_tag %>     <%# Widget + Skript; Optionen: site_key:, modus:, haltezeit:, sprache:, api:, script: false %>
<% end %>
```

```ruby
def create
  return render(:new, status: :unprocessable_entity) unless verify_hostily_captcha
  …
end
```

`verify_hostily_captcha(fail_open: nil, send_content: true)` liefert `true` (weiter) oder `false`. Ohne Site-Key und Secret wird
nichts geprüft. Ist der Dienst nicht erreichbar oder das Secret falsch, gilt `fail_open` und die Meldung steht im Rails-Log (nie das
Secret). `hostily_captcha_result` gibt das letzte Ergebnis zurück. Hinter einem Proxy liefert `request.remote_ip` die echte Adresse.

* `token_from(form)` / `content(form)`: Letzteres entfernt Passwortfelder, Secrets, CSRF-Token, Kartencodes und die Token-Felder,
  auch in verschachtelten Hashes (`ActionController::Parameters` wird unterstützt). Passwörter werden nie mitgeschickt.
* `Result`: `success?`, `gruende`, `punkte`, `error_codes`, `hostname`, `configuration_error?`.
* `timeout:` in Sekunden (Vorgabe 5). Ohne Token wird der Dienst nicht gefragt (`token_fehlt`). Ein Token gilt nur für eine Prüfung.
* Getestet mit Ruby 3.1 und 3.4; Rails-Helfer mit actionpack (aktuell). Tests: `rake test`.

**English**

Small client for [hostily Captcha](https://captcha.hostily.de) with Rails helpers. Ruby ≥ 3.1, `Net::HTTP` only (no third-party gems).

* Without Rails: `Hostily::Captcha::Client.new(secret).verify_form(params, remoteip: ip)`; `UnavailableError` means the service is
  unreachable / timed out / HTTP 5xx or 429 / unreadable answer - you decide to block or let pass.
* Rails: configure in an initializer (see above), put `<%= hostily_captcha_tag %>` into the form, call `verify_hostily_captcha` in the
  controller (`true` = go on, `false` = reject). Nothing is checked without site key and secret; on an outage or a wrong secret
  `fail_open` decides (default: let pass) and a line goes to the Rails log (never the secret).
* `content(form)` drops password fields, secrets, CSRF tokens, card codes and the token fields (also nested). Passwords are never sent.
* `Result`: `success?`, `gruende`, `punkte`, `error_codes`, `hostname`, `configuration_error?`. Default timeout 5 s.
  A token is valid for one check only. Tests: `rake test`.

MIT License.
