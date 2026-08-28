# Contributing to Tiza

Thanks for your interest in contributing to Tiza!

## Getting Started

1. Fork the repository
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
3. Generate the project: `xcodegen generate`
4. Open `Tiza.xcodeproj` in Xcode 26+

## Development

- **Target**: macOS 26 (Tahoe)
- **Language**: Swift 6 with strict concurrency
- **UI**: SwiftUI + AppKit hybrid — the canvas is a custom `NSView`, UI overlays are SwiftUI
- **Project generation**: XcodeGen — run `xcodegen generate` after adding or removing source files

### Running Tests

```bash
xcodebuild test -scheme Tiza -destination 'platform=macOS,arch=arm64'
```

## Submitting Changes

1. Create a branch from `main`
2. Make your changes
3. Run the test suite and verify it passes
4. Open a pull request with a clear description of the change

## Reporting Bugs

Open an issue with:
- Steps to reproduce
- Expected vs actual behavior
- macOS version

## Code Style

- Follow existing patterns in the codebase
- No comments unless the *why* is non-obvious
- Prefer editing existing files over creating new ones
