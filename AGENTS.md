# Repository Guidelines

## Project Structure & Modules
- Source: `Leader Key/` — macOS app in Swift (e.g., `Views/`, `Settings/`, `Support/`, `Assets.xcassets`).
- Tests: `Leader KeyTests/` — XCTest suites (e.g., `UserConfigTests.swift`, `ConfigValidatorTests.swift`).
- Project: `Leader Key.xcodeproj` — Xcode project and scheme `Leader Key`.
- Scripts: `bin/` — release utilities (`bump`, `release`, Sparkle helpers).
- Updates: `Updates/` — archive/appcast artifacts used by Sparkle.

## Build, Test, and Dev Commands
- Open in Xcode: `open "Leader Key.xcodeproj"`
- Build (CLI): `xcodebuild -project "Leader Key.xcodeproj" -scheme "Leader Key" -configuration Debug -destination "platform=macOS" build`
- Test (CLI):
  `xcodebuild test -project "Leader Key.xcodeproj" -scheme "Leader Key" -destination "platform=macOS" -testPlan "TestPlan" -skipPackagePluginValidation -skipMacroValidation CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
- Lint: `brew install swift-format && swift-format lint --recursive .`
- Format: `swift-format format -i -r .`
- Bump build number: `bin/bump`
- Release flow: Archive in Xcode, ensure `Updates/Leader Key.app` exists, then run `bin/release` (zips, updates appcast, uploads).

## Coding Style & Naming
- Language: Swift 5; use 2-space indentation and early-return patterns.
- Names: Types `UpperCamelCase`; methods/properties `lowerCamelCase`; files match primary type.
- Tools: `swift-format` for lint/format; avoid trailing whitespace and keep focused diffs.

## Testing Guidelines
- Framework: XCTest with Test Plan `TestPlan`.
- Conventions: Test files end with `Tests.swift`; functions start with `test…` and remain deterministic.
- Scope: Prioritize validation, config I/O, and user defaults (see `UserConfigTests.swift`). Prefer `NSTemporaryDirectory()` for file ops.
- Run: From Xcode or the `xcodebuild test` command above.

## Commit & Pull Request Guidelines
- Commits: Short, present tense, scoped (e.g., “Add arrow key support”). Tag releases as `vX.Y.Z`.
- PRs: Clear description, linked issues, repro/verification steps; include screenshots/GIFs for UI changes.
- Quality gate: Run `swift-format lint` and all tests locally; CI must pass.
- Artifacts: Don’t commit built apps/zips. `Updates/` content is managed during release.

## Security & Configuration Tips
- Shell actions run in non-interactive shells; ensure `PATH` is exported (e.g., in `~/.zshenv`).
- Config lives at `~/Library/Application Support/Leader Key/config.json` by default.
