# First version

Approved: menu bar popup; one-time Google Authenticator import with re-import for newly added accounts; unlock once after Mac lock or app restart.

Build a local native Mac app. Import Google export QR images and ordinary otpauth QR images, with a paste-from-clipboard option. Generate time-based codes, show expiry countdowns, search accounts and click to copy. Store secrets in Keychain; do not log or write imports to ordinary files. Clear loaded accounts on lock, sleep or user switch. Authenticate with Touch ID or the Mac login password. No Google login, backend, automatic cloud syncing or desktop widget.

Validation: RFC 6238 known-answer vectors and time boundaries; import fixtures including unsupported/malformed input, duplicates and split exports; native build; dummy Keychain round trip; UI smoke check. Real account import and physical Touch ID/lock behaviour require user interaction.
