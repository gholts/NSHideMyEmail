# NSHideMyEmail

`hme` creates iCloud Hide My Email addresses from the command line, using Apple's own Hide My Email sheet. No web tokens, cookies, passwords, or entitlements.

[![Download the Alfred Workflow](.github/alfred-workflow.svg)](https://github.com/gholts/NSHideMyEmail/releases/latest/download/Hide-My-Email.alfredworkflow)

## Install

```sh
brew install gholts/tap/nshidemyemail
```

Or build it yourself with `make && make install`.

## Usage

```sh
hme newsletter.example      # opens Apple's sheet, prints the new address
hme -c newsletter.example   # also copies it to the clipboard
hme                         # asks for a label first
```

Click "Use" in Apple's sheet to create the address. `hme` exits with 0 on success, 1 on cancel or failure, and 2 for invalid usage. Set `HME_ALT_DSID` to pick an iCloud account.

In Alfred, type `hme <label>` and the new address is copied to the clipboard.

## How it works

Apple's private-email service in `akd` rejects apps without Apple's entitlements. AuthKitUI's sheet doesn't have that restriction: `AKPrivateEmailUIProviderImp` runs inside any app, given only a window, and hands the work to Apple's entitled `AKAuthorizationRemoteViewService`. When you click "Use", it returns the new address.

## Limits

- Requires macOS with an iCloud+ account and a logged-in GUI session. Tested on macOS 15.8.
- Only creates addresses. Manage existing ones in System Settings → Apple Account → iCloud → Hide My Email.
- Uses private API, so a macOS update can break it. `hme` reports an error instead of crashing.

## License

[GPL-3.0-or-later](LICENSE)
