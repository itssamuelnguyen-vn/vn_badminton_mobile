# VN Badminton – customer app

Flutter app (Android first) for the customers of one badminton venue in Vietnam. It talks to the Rails JSON API
`/api/v1` of the [vn_badminton](https://github.com/itssamuelnguyen-vn/vn_badminton) repository (`docs/api.md` there).
Customer features only: every owner and staff action stays on the web.

## Business rules

`docs/business-rules.md` lists what the app itself does (checks, display, storage) with an ID and the server rule it
follows. The server decides every rule; when the app and the server disagree, the server is right.
When a change adds, removes or changes app behaviour, update that file in the same PR (and its "Cập nhật" line).

## Conventions

- Every user-facing text is in `lib/strings.dart`, in Vietnamese and English.
- Colours, gradients and the theme are in `lib/theme.dart`; shared widgets in `lib/widgets.dart`.
- Times are shown in the venue's time (UTC+7) with the helpers of `lib/format.dart`.
- Add an entry to `releases` in `lib/screens/whats_new_screen.dart` with every version sent to customers.
- Before committing: `flutter analyze` (no issues).
- `config/dev.json` (the server URL) is not committed.

## GitHub usage

Same rules as the Rails repository's `CLAUDE.md` ("GitHub usage rules"): no polling or watching CI, few larger PRs,
stop at once on a rate-limit or abuse-detection error.
