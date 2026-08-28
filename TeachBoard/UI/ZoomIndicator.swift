import SwiftUI

struct ZoomIndicator: View {
    @ObservedObject var document: TeachBoardDocument
    @State private var isHovering = false

    private var zoomPercent: Int {
        guard let ref = document.activeBoardReference else { return 100 }
        return Int(round(ref.camera.scale * 100))
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                NotificationCenter.default.post(name: .zoomOut, object: nil)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom out")

            Button {
                NotificationCenter.default.post(name: .zoomFit, object: nil)
            } label: {
                Text("\(zoomPercent)%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom level \(zoomPercent) percent")
            .accessibilityHint("Fit content")
            .help("Fit Content (⌘0)")

            Button {
                NotificationCenter.default.post(name: .zoomIn, object: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom in")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(isHovering ? 1.0 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom controls")
    }
}
