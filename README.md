# minecaptcha

Simple captcha shown to players when they join the server, guarding privileges
behind the captcha resolution.

![screenshot](./screenshot.png)

## Configuration

After the mod installation, you need to enable the captcha in settings. You can
require the captcha only for a **new player**, or for **every player login**.

All options are described in the [settingtypes.txt](./settingtypes.txt) file, so
you can use the GUI to configure it. Here are some additional help about these
options:

When you activate the `minecaptcha.on_joinplayer` mode, the
`minecaptcha.managed_privs` are revoked before the player actually joins the
server. If the captcha is sucessfully solved, the player will be granted the
privileges in `minecaptcha.managed_privs`.

When you activate the `minecaptcha.on_newplayer` mode, the managed privs are
also revoked before the player actually joins the server. The player must also
solve the captcha if this setting is active and they never proved they are not
robots.

You can also choose to ban the players if they fail to resolve the captcha in
either join/new player mode using the `minecaptcha.enable_ban` option. When this
option is on, there is a callback to `on_leaveplayer` event that will ban the
player.

You can also choose to remove the player account if the player fails to resolve,
using the `minecaptcha.on_newplayer_remove_account`. Use this option with caution!

## License

The code is distributed under [Apache
2.0](https://www.apache.org/licenses/LICENSE-2.0).  The texture files are
distributed under [CC-BY-SA
4.0](https://creativecommons.org/licenses/by-sa/4.0).
