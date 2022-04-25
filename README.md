# minecaptcha

Simple captcha to show to players when they first join the server.

![screenshot](./screenshot.png)

## Configuration

After mod installation, you need to enable the captcha in settings.  You can
require the captcha only for a new player, or for every login.

When you activate the `on_joinplayer` mode, the `managed_privs` are revoked
before the player actually joins the server. If the captcha is sucessfull, then
it will be able to interact.

When you activate the `on_newplayer` mode, the managed_privs are revoked before
the player actually joins the server. The player must also solve the captcha
after login if this setting is active and they never proved they are not robots.
You can also choose to remove the player account if the player fails to resolve
the captcha and leaves/timeout. Be careful with this option as it will remove
the player account; take special care when enabling this to existing servers.

You can also choose to ban the players if they fail to resolve the captcha in
either join/new player mode.

## License

The code is distributed under [Apache
2.0](https://www.apache.org/licenses/LICENSE-2.0).  The texture files are
distributed under [CC-BY-SA
4.0](https://creativecommons.org/licenses/by-sa/4.0).
