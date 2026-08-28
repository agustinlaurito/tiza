# TeachBoard — Agent Rules

These invariants must be respected by any AI agent modifying this codebase.

## Architecture

- **Canvas is an NSView** (`CanvasView`), not a SwiftUI view. All drawing, gesture handling, and rendering happens in AppKit. The SwiftUI shell wraps it via `CanvasRepresentable` (NSViewRepresentable).
- **SwiftUI is for UI chrome only**: toolbars, palettes, settings, board navigator, dialogs. Never put drawing logic in SwiftUI views.
- **All element coordinates are world coordinates** (Double). Never store screen-space coordinates in the document model. Coordinate conversion happens in `Camera` — do not duplicate conversion logic elsewhere.
- **One Camera struct** handles all coordinate math. Use `Camera.worldToScreen` and `Camera.screenToWorld`. Do not write ad-hoc transform calculations.
- **Tools produce Commands, not direct mutations**. Every persistent change to board data must go through the undo system (NSUndoManager). A tool's job is to interpret input events and produce undoable operations.
- **Instruments are not tools**. Instruments are overlay objects that provide geometric constraints. They coexist with the active tool. A tool queries instruments for constraint via `ToolContext`, never by directly referencing an instrument.
- **Presentation effects (laser, spotlight, big cursor) are ephemeral**. They never modify board data, never enter undo history, and are never serialized.

## Document Model

- **Schema version** must be incremented when the serialized format changes. Add a migration in `SchemaVersion.swift`.
- **Unknown keys must be preserved** during round-trip. Use `Codable` with care — do not use `CodingKeys` that exclude unknown fields without a preservation strategy.
- **The document is a package** (`.teachboard` directory bundle). `document.json` holds metadata and board ordering. Each board's elements live in `boards/{uuid}.json`. Images go in `assets/`.
- **Board element data is per-board**, stored in separate files. This enables lazy loading.
- **`CodableColor`** is the only color representation in the data model. Convert to/from `NSColor`/`CGColor` at the boundary.

## Rendering

- The rendering pipeline has six layers, drawn bottom-to-top: background, content, instruments, selection, in-progress, presentation. Keep this order.
- Use dirty-rect invalidation (`needsDisplay = true` or `setNeedsDisplay(_:)`) — do not redraw the entire canvas on every event.
- `Renderer` is a pure function module. It takes elements + context and draws. It does not hold state.
- `BoardBackgroundRenderer` handles grid/dot/line patterns. It works in screen space using the camera transform.

## File Organization

```
TeachBoard/
  App/          — SwiftUI app entry, AppDelegate
  Document/     — Data model, NSDocument/ReferenceFileDocument, schema
  Canvas/       — NSView canvas, camera, renderer, hit-testing
  Tools/        — Tool protocol, tool implementations
  Instruments/  — Instrument protocol, ruler/protractor/etc.
  Presentation/ — Laser, spotlight, big cursor
  Commands/     — Undo/redo command types
  UI/           — SwiftUI views (toolbars, palettes, settings)
  Export/       — PNG/PDF export
  Geometry/     — WorldPoint, math utilities
  Resources/    — Assets, entitlements
```

Put new files in the correct directory. Do not create new top-level directories without discussion.

## Code Style

- No god objects. No business logic in views.
- No comments explaining what — use clear names. Comment only non-obvious why.
- No premature abstractions. Three similar lines beat a premature protocol.
- No feature flags or backwards-compat shims — just change the code.
- Prefer Apple-native frameworks. No third-party dependencies unless discussed first.

## Testing

- Serialization, coordinate math, hit-testing, geometry, instrument constraints, and undo/redo must have tests.
- Build after every change. Fix compilation errors before moving on.
- Run `xcodebuild test` to verify tests pass.

## What NOT to Do

- Do not add cloud/network features, accounts, or collaboration.
- Do not add a web view or embedded browser.
- Do not use Electron, React, or web technologies.
- Do not introduce third-party dependencies without explicit approval.
- Do not refactor unrelated code while implementing a feature.
- Do not leave placeholder/TODO implementations for required functionality.
