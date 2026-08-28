# TeachBoard Architecture

## Overview

TeachBoard is a native macOS whiteboard for teaching. It uses SwiftUI for app lifecycle and UI chrome, with an AppKit NSView for the high-performance drawing canvas.

```
SwiftUI App (DocumentGroup)
  └─ MainWindowContent (SwiftUI)
       ├─ CanvasRepresentable (NSViewRepresentable)
       │    └─ CanvasView (NSView, Core Graphics)
       └─ BoardNavigator (SwiftUI)
```

## Coordinate System

All element positions are stored in **world coordinates** — an infinite 2D plane with Double precision. The origin (0,0) is the default center of a new board.

The **Camera** maps between world and screen space:

```
screen.x = (world.x - camera.center.x) * camera.scale + viewWidth / 2
screen.y = (world.y - camera.center.y) * camera.scale + viewHeight / 2
```

- `camera.center` — the world point at the viewport center
- `camera.scale` — zoom level (1.0 = 100%, 2.0 = 200%)
- The view is flipped (`isFlipped = true`): origin at top-left, Y increases downward

Coordinate conversion is centralized in `Camera.swift`. Never duplicate this math.

## Document Model

### Package Format

```
MyClass.teachboard/
  document.json          — DocumentModel (metadata, board list, schema version)
  boards/
    {uuid}.json          — BoardData (elements for one board)
  assets/
    {filename}.{ext}     — Embedded images
```

### Type Hierarchy

```
DocumentModel
  ├─ schemaVersion: Int
  ├─ activeBoardIndex: Int
  ├─ boards: [BoardReference]
  │    ├─ id: UUID
  │    ├─ name: String?
  │    ├─ camera: CameraState
  │    └─ background: BoardBackground
  ├─ createdAt: Date
  └─ modifiedAt: Date

BoardData (separate file per board)
  ├─ id: UUID
  └─ elements: [Element]
       ├─ id: UUID
       ├─ type: ElementType (.stroke, .shape, .text, .image)
       └─ zIndex: Int
```

### Schema Versioning

`schemaVersion` is checked on load. If the document has a newer version than the app supports, loading fails with a clear error. If older, migrations are applied sequentially (`V1→V2→V3→...`). Unknown JSON keys are preserved during round-trip.

## Rendering Pipeline

`CanvasView.draw(_:)` renders in this order:

1. **Background** — Solid color, grid, dotted grid, or lines (via `BoardBackgroundRenderer`)
2. **Content** — All elements sorted by zIndex (via `Renderer`)
3. **Instruments** — Ruler, protractor, etc. (future)
4. **Selection** — Handles and bounding boxes (future)
5. **In-progress** — Currently-being-drawn stroke/shape (future)
6. **Presentation** — Laser trail, spotlight dimming (future)

The renderer operates in world space by applying the camera's affine transform to the CG context before drawing elements. Element-level properties (stroke width) are adjusted by `1/scale` so they appear constant on screen regardless of zoom.

## Tool System (Phase 2)

```
protocol Tool {
    func pointerDown(at: WorldPoint, context: ToolContext)
    func pointerDragged(to: WorldPoint, context: ToolContext)
    func pointerUp(at: WorldPoint, context: ToolContext)
    func cancel()
}
```

- **One active tool at a time**, managed by `ToolManager`
- Tools receive events in world coordinates (converted from screen by CanvasView)
- Tools produce mutations via `ToolContext`, which wraps the board data and undo manager
- Tools do not reference UI — the UI observes tool state reactively

## Instrument System (Phase 5)

```
protocol Instrument {
    func constrain(point: WorldPoint, tool: ToolType) -> WorldPoint?
    func hitTest(point: WorldPoint) -> InstrumentHitResult?
    func render(in context: CGContext, camera: Camera)
}
```

- Instruments are **not tools** — they're persistent overlays
- They coexist with any active tool
- The active tool queries instruments for constraints through ToolContext
- Example: pen near ruler edge → ruler.constrain() snaps the point to the edge

## Undo / Redo

Uses `NSUndoManager` (provided by the SwiftUI document environment). All persistent mutations register undo actions:

- A freehand stroke = one undo action (AddElement)
- Moving an object = one undo action (MoveElement with before/after positions)
- Presentation effects (laser, spotlight) never touch undo

## Build

```bash
# Generate/regenerate Xcode project (after changing project.yml)
xcodegen generate

# Build
xcodebuild -project TeachBoard.xcodeproj -scheme TeachBoard build

# Test
xcodebuild -project TeachBoard.xcodeproj -scheme TeachBoard test
```
