# VN Badminton – customer app

Flutter app (Android first) for the customers of the VN Badminton court booking web app
([vn_badminton](https://github.com/itssamuelnguyen-vn/vn_badminton)). It talks to the Rails JSON API `/api/v1`
(documented in that repository's `docs/api.md`). Customer features only: every owner and staff action stays on the web.

## Run

New computer (Flutter, Android Studio, files to bring from the old one): see
[`docs/dev-setup.md`](https://github.com/itssamuelnguyen-vn/vn_badminton/blob/main/docs/dev-setup.md) in the Rails repository.


1. Copy `config/dev.example.json` to `config/dev.json` and set `API_URL` to the server (the tunnel URL in
   development; `start-tunnel` in the Rails repository rewrites it).
2. `flutter run --dart-define-from-file=config/dev.json` (`.vscode/launch.json` passes it).

`config/dev.json` is not committed.

## Build an APK

`Ctrl+Shift+B` in VS Code (or `tool/build_apk.ps1`) builds `build\apk\vnbadminton-<version>-<yyyyMMdd-HHmm>.apk`.
Steps, timings and troubleshooting: [`docs/build-apk.md`](docs/build-apk.md).
