# Validation

## Passed

- Release compilation and ad-hoc code signing on Apple Silicon.
- Twelve core tests: all 18 RFC 6238 SHA-1/SHA-256/SHA-512 vectors; time boundaries; six-digit truncation; standard URI and Google export parsing; split exports; version 2 envelopes; explicit zero-sized single-QR batches; duplicate account recognition; malformed and unsupported input rejection.
- Native UI launch: menu bar popup, locked view and unlocked empty import view observed.
- QR decoding reached the export parser in the live app during the user's import attempt. A subsequent user screenshot identified version 2 as the rejected metadata. Version 2 envelopes are now accepted while all required account fields are still validated. Zero-sized unbatched exports are also supported. Both cases have regression tests; no real account secrets were inspected.

## Environment limits / remaining manual checks

- Core Image could not create a CGImage in the shell test environment, so the image-generation integration test reports a skip.
- The dummy Keychain write check returned OSStatus -50 in the shell environment. Live-app account persistence has not yet been confirmed. This is not recorded as a pass.
- The updated app has been reopened for the user's import retry.
- Compare a real imported code with the phone, quit/reopen and unlock to check persistence, then lock/unlock the Mac and confirm the app requests authentication again.

## Review

Reviewed the new source against docs/FIRST-VERSION.md: imports remain local; no secret logging; validation before atomic Keychain save; identical re-imports skipped; unsupported HOTP rejected; stale unlock attempts discarded using a session identifier; user clipboard changes preserved during expiry cleanup. Fixed empty Settings-window launch, truncated import instructions, and unsupported accessibility attributes on the traditional macOS Keychain.

No independent subagent review was run: the global instructions require gpt-5.6-luna, which is not an available subagent model in this session.


## Liquid Glass and simplified view update

- Release build passed with native SwiftUI glassEffect and glassProminent APIs, availability-gated for macOS 26.
- Simplified view persists in AppStorage, hides secondary UI, ignores hidden search filters, and retains account names, codes, expiry and click-to-copy.
- Full interface remains reachable from the options menu and an account context menu. Empty and locked states keep onboarding and authentication available.
- Native app launch and the View options menu button were observed. The UI automation connection timed out while opening the menu, so the compact layout was not visually verified in this session.
- Before this update's restart, the live app showed a successful import of two accounts. No credentials were read from Keychain by the agent.

## Apple Design Skill review — 2026-10-21

Read dickwu/apple-design-skill SKILL.md and the macOS, accessibility, layout, typography, color, materials, Liquid Glass, popover, button and code-audit references. Downloaded the skill and selected references into .design-rules (not a complete repository mirror).

- Removed the extra custom glass surface inside NSPopover; native presentation owns its material and system accessibility adaptations.
- Removed decorative logo, uppercase tagline and persistent status footer. Moved account import actions into the header and options menu; empty-state import buttons remain.
- Raised countdown text from 9 to 11 pt, account labels to 13 pt and options hit area to 28 pt. Added row hover/press feedback and retained accessible account identification.
- Simplified mode keeps account identity, code, expiry, copy feedback and the options menu.
- Release build and ad-hoc signing pass. Updated compact account rows were observed in the accessibility tree. The locked view was inspected visually; its glassProminent button label was unclear, so replaced that custom style with the standard borderedProminent button. The final screenshot connection lost the window; final button rendering and full/compact visual checks remain unverified.
- Core generation/import logic unchanged; no extra core tests added for this presentation-only change.

## Minimal default follow-up

- Simplified mode is now the default, with a one-time migration for existing preferences.
- Removed all ellipsis buttons and the compact header strip. Options remain on right-click, including lock/import/full view.
- Compact horizontal inset reduced from 22 to 12 pt; vertical padding reduced and rows shortened. No custom outer border is drawn.
- Release build passes. User's reference image could not be downloaded in this environment, so exact visual matching is not claimed.
