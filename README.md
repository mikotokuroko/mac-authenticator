# Mac Authenticator

A native menu bar app for viewing the same time-based verification codes as Google Authenticator on your iPhone.

## Use

1. Open `dist/Mac Authenticator.app` and click the key icon in the menu bar.
2. Unlock with Touch ID or your Mac login password.
3. In Google Authenticator on your iPhone, choose **Transfer accounts → Export accounts** and select the entries to copy.
4. Import a QR image with **Import QR image**, or copy an image and choose **Paste QR**. If using iPhone Mirroring for this initial step, Control–Shift–Command–4 copies a selected region to the Mac clipboard without saving a screenshot file.
5. If Google shows several QR codes, import each one. Existing identical entries are skipped.
6. Click an account's code to copy it. Search by service or account name. Right-click an account to remove its Mac copy.

The iPhone entries remain available. Imported accounts generate matching codes locally; the phone does not need to be nearby. New or reset accounts need importing again. Keep the Mac's date and time set automatically.

The export QR contains the account secrets. Import it directly into this app; do not send it to chat or upload it to a QR-decoding website.

## Simplified view

Simplified view is enabled by default. After unlocking, the popup shows account labels, codes and countdowns. Click a code to copy. Right-click an account and turn off **Simplified View** to restore search and import controls. The same context menu provides import, lock and quit actions. Empty accounts still show import controls.

The interface uses native SwiftUI Liquid Glass on macOS 26 and later, with a standard material fallback on older versions. It respects Reduce Motion, Reduce Transparency and increased contrast.

## Behaviour

- Menu bar popup with code countdowns and account search.
- Google export QR images and standard `otpauth://totp` QR images; PNG, JPEG, TIFF and HEIC.
- SHA-1, SHA-256 and SHA-512 time-based codes, with six or eight digits.
- Secrets saved in the local macOS login Keychain using its native access controls.
- Touch ID or password gates the app session. Loaded accounts are cleared when the app locks, the screen locks/sleeps, the Mac sleeps, the active user changes or the app quits.
- Copied codes are removed from the clipboard after 30 seconds or when the app locks, only if the clipboard has not since changed.
- No network service, Google login or continuous cloud account sync.
- Counter-based HOTP accounts are not supported.

The app starts manually. To launch it at login, add the built app in macOS System Settings → General → Login Items.

## Build and test

Requires macOS 14 or later and Xcode with Swift 6. The supplied build targets Apple Silicon.

```sh
./test.sh
./build.sh
open 'dist/Mac Authenticator.app'
```

No third-party runtime packages are required. The build is locally ad-hoc signed, not App Store distributed or notarized. Rebuilding may cause macOS to ask again for access to the app's Keychain item.

```sh
# Sample UI only; never loads real accounts.
open -n 'dist/Mac Authenticator.app' --args --demo

# Dummy Keychain integration check; uses a unique temporary service and removes it.
'dist/Mac Authenticator.app/Contents/MacOS/MacAuthenticator' --keychain-self-test
cat /tmp/mac-authenticator-keychain-check.txt
```

The QR image integration test needs a macOS environment where Core Image can render; it reports a skip when that facility is unavailable.

## Sources

- [RFC 6238 and its test vectors](https://www.rfc-editor.org/rfc/rfc6238)
- [Google's OTP URI format](https://github.com/google/google-authenticator/wiki/Key-Uri-Format)
- [Documented Google export protobuf schema](https://github.com/qistoph/otp_export/blob/master/OtpMigration.proto) — unofficial reverse-engineered schema.
