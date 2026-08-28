import SwiftUI

struct ToolbarView: View {
    @ObservedObject var toolManager: ToolManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            toolSection
            separator
            colorSection
            separator
            thicknessSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(isHovering ? 1.0 : 0.85)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drawing toolbar")
    }

    private var toolSection: some View {
        HStack(spacing: 2) {
            ForEach(ToolType.drawingTools) { tool in
                ToolButton(
                    type: tool,
                    isActive: toolManager.activeToolType == tool
                ) {
                    toolManager.switchTool(tool)
                }
            }
        }
    }

    private var colorSection: some View {
        ColorPalette(selectedColor: Binding(
            get: { toolManager.currentColor },
            set: { toolManager.currentColor = $0 }
        ))
    }

    private var thicknessSection: some View {
        ThicknessControl(thickness: Binding(
            get: { toolManager.currentThickness },
            set: { toolManager.currentThickness = $0 }
        ))
    }

    private var separator: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 6)
    }
}

private struct ToolButton: View {
    let type: ToolType
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: type.systemImage)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    isActive
                        ? RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                        : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint("Shortcut: \(String(type.shortcutKey).uppercased())")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .help("\(type.displayName) (\(String(type.shortcutKey).uppercased()))")
    }
}
