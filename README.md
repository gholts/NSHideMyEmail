# NSHideMyEmail

A small command-line tool for making iCloud Hide My Email addresses. `hme` opens the same Hide My Email sheet that Safari and System Settings use, so no web tokens, cookies or passwords are involved.

[![Download the Alfred Workflow](.github/alfred-workflow.svg)](https://github.com/gholts/NSHideMyEmail/releases/latest/download/Hide-My-Email.alfredworkflow)

## Install

```sh
brew install gholts/tap/nshidemyemail
```

Or clone the repo and run `make install`.

## Usage

```sh
hme newsletter      # opens Apple's sheet and prints the new address
hme -c newsletter   # same, and copies it to the clipboard
hme 'Book Club'     # spaces become dashes, so the label is book-club
hme                 # asks you for a label first
```

Click "Use" in the sheet and `hme` prints the address. It exits with 0 when you get one, 1 if you cancel or something goes wrong, and 2 for bad arguments.

With the Alfred workflow, type `hme <label>` and the address ends up on your clipboard.

## How it works

Apple guards its Hide My Email service with entitlements that third-party apps can't get. The sheet is the exception: AuthKitUI's `AKPrivateEmailUIProviderImp` runs in any app that gives it a window, and hands the real work to Apple's own `AKAuthorizationRemoteViewService`. Once you click "Use", it passes back the new address.

The sheet also needs your account ID (altDSID). `hme` asks AuthKit first, then reads `~/Library/Preferences/MobileMeAccounts.plist`, and finally falls back to `otctl status --json`, since newer versions of macOS stopped writing that plist. To pick a specific account, set `HME_ALT_DSID`.

## Limits

- Needs an iCloud+ account and a logged-in desktop session. Tested on macOS 15.8 and 27.2.1.
- Only makes new addresses. To manage existing ones, go to System Settings → Apple Account → iCloud → Hide My Email.
- Built on private API, so a macOS update could break it. If that happens, `hme` shows an error instead of crashing.

## License

[GPL-3.0-or-later](LICENSE)
