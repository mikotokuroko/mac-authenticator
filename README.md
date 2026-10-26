# Mac Authenticator

[简体中文](README.zh-CN.md)

A native SwiftUI menu bar app for your verification codes. Import accounts from Google Authenticator once, then view and copy matching codes directly on your Mac.

![Mac Authenticator in simplified view, with usernames obscured](docs/images/preview.png)

*Simplified view shown above. New installations open in full view, with search and import controls.*

## Install

Requires an Apple Silicon Mac running macOS 14 or later.

1. Download **MacAuthenticator-arm64.zip** from [Releases](https://github.com/mikotokuroko/mac-authenticator/releases/latest).
2. Unzip it and move **Mac Authenticator.app** to **Applications**.
3. Open the app and click the **key icon** in the menu bar.

The app is ad-hoc signed. If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway**, then open it again.

## Add accounts

1. Unlock the app with Touch ID or your Mac password.
2. On your iPhone, open Google Authenticator and choose **Transfer accounts → Export accounts**.
3. On your Mac, click **+ → Import QR Image…** and select the QR image, or choose **Paste QR** for an image copied to the clipboard.
4. If the export contains several QR codes, import each one.

Your iPhone keeps its accounts. The Mac generates codes locally from the imported accounts; adding or resetting an account on your phone requires importing it again.

## Use and settings

Click an account to copy its code. The countdown shows how long the code remains valid. Full view includes account search and the **+** import menu.

**Right-click inside the popup** to access settings and actions:

| Option | Action |
| --- | --- |
| Simplified View | Show only account labels, codes and countdowns. Turn it off to restore full view. Your choice is saved. |
| Lock Codes | Lock the app immediately. |
| Import QR Image… / Paste QR | Add accounts while unlocked. |
| Quit Authenticator | Lock and quit the app. |

Right-click an account and choose **Remove from Mac…** to remove its local copy.

To launch automatically, add **Mac Authenticator.app** under **System Settings → General → Login Items**.

## Features

- Native SwiftUI interface with the macOS popover material.
- Google Authenticator export QR codes and standard TOTP QR codes.
- SHA-1, SHA-256 and SHA-512; six- and eight-digit codes.
- Accounts stored in the local macOS Keychain.
- Touch ID or Mac password unlock; automatic locking on screen lock, sleep, user switching and quit.
- Copied codes clear after 30 seconds or on locking, if the clipboard still contains the app's copy.
- Supports Reduce Motion, Reduce Transparency and increased contrast.

## Build

Requires Xcode with Swift 6 or later.

```sh
./test.sh
./build.sh
open 'dist/Mac Authenticator.app'
```

To preview with sample accounts:

```sh
open -n 'dist/Mac Authenticator.app' --args --demo
```
