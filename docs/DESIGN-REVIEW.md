# Authenticator design review

Thesis: open the menu bar item, recognize the account, read or copy its code. A quiet native utility with stable, grouped digits as its visual focus.

## Findings and changes

- Critical: 9 pt countdown and tagline were below the macOS 10 pt minimum (`accessibility.md › Vision`). Countdown is now 11 pt; the tagline is removed.
- High: an extra glassEffect wrapped all content inside an existing native popover. `liquid-glass.md › Review checklist` warns against stacked glass; removed the custom layer and retained NSPopover's system presentation.
- Medium: custom rows lacked interaction feedback. `buttons.md › Best practices` requires a press state; added hover and press fills.
- Medium, design judgment: branding and storage status competed with verification codes. Removed both; import lives in the header/menu, with visible import buttons for first use.

## Design choices

Semantic primary/secondary text, system accent for primary action/expiry, windowBackgroundColor for reduced transparency or increased contrast. No fixed hex replacements: material colors depend on appearance and the backdrop (`color.md › System colors`). Contrast ratios were not measured from this dynamic presentation.

System typography: 13 pt account label, 11 pt secondary text and countdown, 28/30 pt monospaced digits. The regular view adds search and an account subtitle; the compact view keeps identity, digits, expiry and options. Native popover width is 340/300 pt. Row spacing groups each code with its owner; no card backgrounds. Existing reduced-motion preference disables the mode transition.

Keep: local account import, authentication, readable grouped codes, click-to-copy, saved simplified preference, context-menu recovery to the full interface.

Limits: code review and partial native UI inspection; no measured contrast audit or complete keyboard/appearance verification.
