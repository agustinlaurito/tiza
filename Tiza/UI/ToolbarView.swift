import SwiftUI

struct ToolbarView: View {
    @ObservedObject var toolManager: ToolManager
    @Namespace private var glassNS
    @Namespace private var selectionNS
    @State private var hoverX: CGFloat?
    @State private var showTextPresets = false
    @State private var textButtonFrame: CGRect = .zero

    private let tools = ToolType.drawingTools
    private let buttonSize: CGFloat = 32
    private let buttonSpacing: CGFloat = 2

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
        .glassEffect(.regular, in: .capsule)
        .glassEffectUnion(id: "toolbar", namespace: glassNS)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drawing toolbar")
        .coordinateSpace(name: "toolbar")
        .overlay {
            if showTextPresets {
                textPresetMenu
                    .position(x: textButtonFrame.midX,
                              y: textButtonFrame.minY - 28)
            }
        }
    }

    private var toolSection: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                let mag = magnification(for: index)
                if tool == .text {
                    ToolButton(
                        type: tool,
                        isActive: toolManager.activeToolType == tool,
                        glassNS: glassNS,
                        selectionNS: selectionNS
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            toolManager.switchTool(tool)
                        }
                    }
                    .scaleEffect(mag)
                    .zIndex(mag > 1.01 ? Double(mag * 10) : 0)
                    .background(GeometryReader { geo in
                        Color.clear.onAppear { textButtonFrame = geo.frame(in: .named("toolbar")) }
                            .onChange(of: geo.frame(in: .named("toolbar"))) { _, f in textButtonFrame = f }
                    })
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4)
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    showTextPresets = true
                                }
                            }
                    )
                } else {
                    ToolButton(
                        type: tool,
                        isActive: toolManager.activeToolType == tool,
                        glassNS: glassNS,
                        selectionNS: selectionNS
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            toolManager.switchTool(tool)
                        }
                    }
                    .scaleEffect(mag)
                    .zIndex(mag > 1.01 ? Double(mag * 10) : 0)
                }
            }
        }
        .onContinuousHover { phase in
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) {
                switch phase {
                case .active(let loc):
                    hoverX = loc.x
                case .ended:
                    hoverX = nil
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if let index = toolIndex(at: value.location.x) {
                        let tool = tools[index]
                        if toolManager.activeToolType != tool {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                toolManager.switchTool(tool)
                            }
                        }
                    }
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) {
                        hoverX = value.location.x
                    }
                }
                .onEnded { _ in
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) {
                        hoverX = nil
                    }
                }
        )
    }

    private var textPresetMenu: some View {
        HStack(spacing: 4) {
            ForEach(TextPreset.allCases, id: \.self) { preset in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showTextPresets = false
                    }
                    toolManager.textPreset = preset
                    toolManager.switchTool(.text)
                } label: {
                    Text(preset.shortName)
                        .font(.system(size: preset == .body ? 12 : 14,
                                      weight: preset.isBold ? .bold : .regular))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(preset.displayName)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .onHover { hovering in
            if !hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showTextPresets = false
                    }
                }
            }
        }
    }

    private func magnification(for index: Int) -> CGFloat {
        guard let hx = hoverX else { return 1.0 }
        let center = CGFloat(index) * (buttonSize + buttonSpacing) + buttonSize / 2
        let distance = abs(center - hx)
        let range: CGFloat = 55
        let maxMag: CGFloat = 0.3
        let t = max(0, 1 - distance / range)
        return 1.0 + maxMag * t * t
    }

    private func toolIndex(at x: CGFloat) -> Int? {
        let stride = buttonSize + buttonSpacing
        let index = Int(x / stride)
        guard index >= 0, index < tools.count else { return nil }
        return index
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
        ), glassNS: glassNS, selectionNS: selectionNS)
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
    var glassNS: Namespace.ID
    var selectionNS: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: type.systemImage)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                            .glassEffectUnion(id: "toolbar", namespace: glassNS)
                            .matchedGeometryEffect(id: "toolSelection", in: selectionNS)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint("Shortcut: \(String(type.shortcutKey).uppercased())")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .help("\(type.displayName) (\(String(type.shortcutKey).uppercased()))")
    }
}
