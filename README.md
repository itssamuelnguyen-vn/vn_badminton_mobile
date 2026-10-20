# VN Badminton – customer app

Flutter app (Android first) for the customers of the VN Badminton court booking web app
([vn_badminton](https://github.com/itssamuelnguyen-vn/vn_badminton)). It talks to the Rails JSON API `/api/v1`
(documented in that repository's `docs/api.md`). Customer features only: every owner and staff action stays on the web.

## Run

1. Copy `config/dev.example.json` to `config/dev.json` and set `API_URL` to the server (the tunnel URL in
   development; `start-tunnel` in the Rails repository rewrites it).
2. `flutter run --dart-define-from-file=config/dev.json` (`.vscode/launch.json` passes it).

`config/dev.json` is not committed.
