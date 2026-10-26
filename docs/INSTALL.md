# Installing Margin on your iPhone (from Windows)

This guide uses a free Apple ID and [Sideloadly](https://sideloadly.io/). You don't need a paid Apple Developer account.

## 0. One-time setup on Windows

1. **iTunes and iCloud for Windows.** Sideloadly needs Apple's device drivers. Use the versions from apple.com, **not** the Microsoft Store versions. Sideloadly's site links to the right downloads.
   - iTunes: https://www.apple.com/itunes/download/win64
   - iCloud: https://support.apple.com/en-us/103232
2. **Sideloadly**: download it from https://sideloadly.io/ and install it.
3. Connect the iPhone by USB, unlock it, and tap **Trust This Computer**. Open iTunes once to confirm the phone appears there.

> Sideloadly sends your Apple ID credentials to Apple to create a free signing certificate. If you'd rather not use your main account, create a separate free Apple ID for sideloading.

## 1. Download the IPA from GitHub Actions

1. Open your repository on GitHub → **Actions** → **iOS build (unsigned IPA)**.
2. Open the latest run with a green check (or click **Run workflow** to start one).
3. Scroll to **Artifacts** → download **Margin-unsigned-ipa**. You need to be signed in to GitHub.
4. GitHub delivers artifacts as a `.zip`. Unzip it to get **`Margin-unsigned.ipa`**.

About the "unsigned" name: the IPA has no Apple signature. It carries only an ad-hoc placeholder that records the App Group entitlement. It can't be installed as-is, and Sideloadly signs it with your Apple ID during install.

## 2. Sign and install with Sideloadly

1. Open Sideloadly. Your iPhone should appear under **iDevice**.
2. Drag `Margin-unsigned.ipa` onto the IPA box.
3. Enter your **Apple ID** email.
4. Open **Advanced options** and check:
   - **Signing mode**: *Apple ID Sideload* (the default)
   - Leave **"Remove app extensions"** (or any similar "remove plugins" option) **unchecked**. Otherwise the widget is removed.
   - Leave the bundle ID unchanged if Sideloadly allows it. If it has to change it (for example "bundle ID not available"), Margin still runs, but the App Group may not connect (see below).
5. Click **Start** and enter your Apple ID password and the 2FA code when asked.
6. Wait for **Done**.

## 3. First launch on the iPhone

1. **Developer Mode** (iOS 16 and later). After the first sideload, go to Settings → Privacy & Security → **Developer Mode** → on → restart → confirm. This option appears only after a sideloaded app is on the phone.
2. **Trust your Apple ID**: Settings → General → **VPN & Device Management** → under *Developer App*, tap your Apple ID → **Trust**.
3. Open **Margin** once. This registers the widget extension with iOS.

## 4. Verify the widget

1. Long-press an empty area of the home screen → **Edit** (top left) → **Add Widget**.
2. Search for or scroll to **Margin**. Pick small, medium or large → **Add Widget**.
3. Long-press the widget → **Edit Widget** to choose a theme or type shortcuts.

If Margin isn't in the widget gallery:

- Open the Margin app once, then check again.
- Restart the iPhone. The widget list is sometimes cached.
- Re-install, and make sure Sideloadly's *remove app extensions* option was off.
- In Sideloadly's log, check that `MarginWidget.appex` was signed. Free accounts need **one extra App ID** for it. If you hit the limit of 10 App IDs per 7 days, wait for it to reset.

## App Groups and the widget

The app and the widget are separate processes. They share settings through an **App Group** (`group.dev.margin.app`), which must be part of the signature. Re-signing tools differ in how they handle App Groups for free accounts, and **this project hasn't confirmed Sideloadly's behaviour with a free Apple ID.**

Margin checks at runtime and tells you which case you're in:

- **Margin → widget tab / settings → Data says "App Group connected"**: the widget mirrors everything you change in the app within a few seconds.
- **It says "App Group unavailable"**: the app still works fully as a launcher, but the widget can't read the app's settings and shows the defaults. **Workaround**: long-press the widget → **Edit Widget**:
  - **Theme**: pick one
  - **Shortcuts**: type a list, e.g. `Messages; Music; Notes; Maps; Work=shortcuts://run-shortcut?name=Work`

  Bare names use the built-in presets, and `Name=url` sets any URL. This is stored by iOS per widget, so it works with no App Group at all.

If Sideloadly renamed your bundle ID and you want to try to restore the App Group, Margin also looks for `group.<your app's bundle ID>` automatically. You can also edit `MarginAppGroup` in `project.yml` and the two `.entitlements` files to match a group your account has registered, then rebuild.

## 5. Refreshing every 7 days

Apps signed with a free Apple ID **stop opening after 7 days**. The widget then shows nothing or a placeholder.

- **Manual**: re-run Sideloadly with the same IPA and Apple ID. Installing over the existing app **keeps your settings**. Don't delete the app first.
- **Automatic**: in Sideloadly, enable **Automatic refresh** (in the app list or the advanced options, depending on version). Your PC must be on, Sideloadly running in the tray, and the iPhone reachable (USB, or Wi-Fi sync enabled in iTunes on the same network).
- A newer build from GitHub Actions installs the same way and also keeps your settings.

Free account limits: at most **3 sideloaded apps** active at once and **10 App IDs per rolling 7 days**. Margin uses 2 (app + widget).

## Moving a design from the browser to the phone

1. In the browser preview, use **Data → Copy JSON**. Get the text onto the phone, for example through Notes or a message to yourself, and copy it there.
2. On the iPhone: Margin → **settings** → Data → **paste settings from clipboard**.
