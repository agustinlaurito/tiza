# Tiza

A free, native macOS whiteboard app built for teaching.

Microsoft Whiteboard is being retired, so I built Tiza as a replacement — a fast, lightweight alternative that runs natively on macOS with no account, no subscription, and no cloud dependency. It's designed for screen sharing during live classes, but works just as well for sketching ideas or taking visual notes.

> **Tiza** means *chalk* in Spanish.

## Features

### Drawing
- **Pen & highlighter** with pressure-sensitive smoothing
- **Eraser** for quick corrections
- **Shape recognition** — draw a rough circle, rectangle, or triangle and it snaps to a perfect shape
- **Shape tools** — rectangle, ellipse, triangle, diamond, star, line, arrow
- **Text** with presets (H1, H2, H3, body), bold, underline, and font styles (default, serif, rounded)
- **Stroke styles** — solid, dashed, and dotted lines
- **Fill color** for shapes
- **Opacity control** per element
- **Image support** — drag and drop images onto the canvas

### Selection & Editing
- **Smart selection** — left-to-right selects enclosed elements, right-to-left selects touched elements (AutoCAD-style)
- **Shift+click/drag** to add to selection
- **Smart guides** — alignment guides appear when moving elements near others
- **Element grouping** (Cmd+G / Cmd+Shift+G)
- **Lock elements** to prevent accidental moves (Cmd+L)
- **Alignment tools** — left, center, right, top, middle, bottom, distribute
- **Resize handles** on selected elements
- **Copy/paste** across boards (Cmd+C / Cmd+V)
- **Duplicate** elements from context menu
- **Animated delete** — elements implode when removed
- **Animated alignment** — elements slide smoothly into place

### Canvas
- **Infinite canvas** — pan and zoom freely
- **Multiple boards** per document with PageDown/PageUp navigation
- **Board backgrounds** — white, dark, grid, dotted grid, lined
- **Export** boards as PNG or PDF

### Teaching Tools
- **Ruler & protractor** — on-screen instruments for geometry and navigation classes
- **Laser pointer** (hold Space) with trailing effect
- **Presentation mode** with toolbar auto-hide

### Design
- Built with macOS 26 Liquid Glass for a native, polished look
- Dock-style toolbar with magnification on hover
- Dark mode support
- Keyboard shortcuts for every tool

## Keyboard Shortcuts

| Key | Tool |
|-----|------|
| V | Select |
| P | Pen |
| M | Highlighter |
| E | Eraser |
| T | Text |
| L | Line |
| A | Arrow |
| R | Rectangle |
| O | Ellipse |
| G | Triangle |
| D | Diamond |
| S | Star |

| Shortcut | Action |
|----------|--------|
| Cmd+G | Group |
| Cmd+Shift+G | Ungroup |
| Cmd+L | Lock/Unlock |
| Cmd+C | Copy |
| Cmd+V | Paste |
| Cmd+Shift+N | New board |
| Cmd+Shift+D | Duplicate board |
| PageDown | Next board |
| PageUp | Previous board |
| Delete | Delete selection |
| Esc | Cancel / deselect |
| Space (hold) | Laser pointer |
| Shift (hold) | Constrain shapes |

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Building

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Build and run
open Tiza.xcodeproj
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project Tiza.xcodeproj -scheme Tiza -configuration Debug build
```

## Architecture

Tiza is a SwiftUI + AppKit hybrid. The document layer and UI overlays use SwiftUI, while the canvas itself is a custom `NSView` rendered with Core Graphics for maximum performance during freehand drawing.

```
Tiza/
├── App/              # App entry point
├── Canvas/           # NSView canvas, renderer, camera, hit testing
├── Document/         # Data model, document persistence, element types
├── Export/           # PNG and PDF export
├── Geometry/         # Coordinate type aliases
├── Instruments/      # Ruler and protractor
├── Presentation/     # Laser pointer, presentation mode
├── Tools/            # Drawing tools, selection, shape recognition
├── UI/               # SwiftUI toolbar, context menus, overlays
└── Resources/        # Entitlements, assets, Info.plist
```

## Contributing

Contributions are welcome. If you find a bug or want to add a feature, open an issue or submit a pull request.

## License

MIT
