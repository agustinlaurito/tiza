import SwiftUI

struct ZoomIndicator: View {
    @ObservedObject var document: TizaDocument
    @FocusedValue(\.commandHandler) private var commandHandler
    @Namespace private var zoomNamespace

    private var zoomPercent: Int {
        guard let ref = document.activeBoardReference else { return 100 }
        return Int(round(ref.camera.scale * 100))
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                commandHandler?(.zoomOut)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: .circle)
                    .glassEffectUnion(id: "zoom", namespace: zoomNamespace)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom out")
            .help("Zoom Out (⌘-)")

            Button {
                commandHandler?(.zoomFit)
            } label: {
                Text("\(zoomPercent)%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: zoomPercent)
                    .frame(minWidth: 36, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom level \(zoomPercent) percent")
            .accessibilityHint("Fit content")
            .help("Fit Content (⌘0)")

            Button {
                commandHandler?(.zoomIn)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: .circle)
                    .glassEffectUnion(id: "zoom", namespace: zoomNamespace)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom in")
            .help("Zoom In (⌘+)")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .glassEffectUnion(id: "zoom", namespace: zoomNamespace)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom controls")
    }
}
