import SwiftUI

struct ToolbarView: View {
    @ObservedObject var toolManager: ToolManager
    @Environment(\.undoManager) private var undoManager
    @Namespace private var glassNS
    @Namespace private var selectionNS
    @State private var hoverX: CGFloat?
    @State private var showTextPresets = false
    @State private var showShapePicker = false
    @State private var showInsertPicker = false
    @State private var textButtonFrame: CGRect = .zero
    @State private var shapeButtonFrame: CGRect = .zero
    @State private var insertButtonFrame: CGRect = .zero

    private let buttonSize: CGFloat = 32
    private let buttonSpacing: CGFloat = 2

    private var toolItems: [ToolItem] {
        var items: [ToolItem] = ToolType.primaryTools.map { .single($0) }
        items.append(.shapeGroup)
        items.append(.insertGroup)
        return items
    }

    var body: some View {
        HStack(spacing: 0) {
            undoRedoSection
            separator
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
            if showShapePicker {
                shapePicker
                    .position(x: shapeButtonFrame.midX,
                              y: shapeButtonFrame.minY - 28)
            }
            if showInsertPicker {
                insertPicker
                    .position(x: insertButtonFrame.midX,
                              y: insertButtonFrame.minY - 28)
            }
        }
    }

    // MARK: - Tool Section

    private var toolSection: some View {
        HStack(spacing: buttonSpacing) {
            ForEach(Array(toolItems.enumerated()), id: \.element.id) { index, item in
                let mag = magnification(for: index)

                switch item {
                case .single(let tool):
                    if tool == .text {
                        textToolButton(tool: tool, index: index, mag: mag)
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

                case .shapeGroup:
                    shapeGroupButton(index: index, mag: mag)

                case .insertGroup:
                    insertGroupButton(index: index, mag: mag)
                }
            }
        }
        .onContinuousHover { phase in
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.7)) {
                switch phase {
                case .active(let loc): hoverX = loc.x
                case .ended: hoverX = nil
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if let index = toolIndex(at: value.location.x), index < toolItems.count {
                        let item = toolItems[index]
                        let targetTool: ToolType? = switch item {
                        case .single(let t): t
                        case .shapeGroup: toolManager.lastShapeTool
                        case .insertGroup: toolManager.lastInsertTool
                        }
                        if let target = targetTool, toolManager.activeToolType != target {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                toolManager.switchTool(target)
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

    // MARK: - Text Tool Button

    private func textToolButton(tool: ToolType, index: Int, mag: CGFloat) -> some View {
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
                        showShapePicker = false
                        showInsertPicker = false
                    }
                }
        )
    }

    // MARK: - Shape Group Button

    private func shapeGroupButton(index: Int, mag: CGFloat) -> some View {
        let isActive = toolManager.activeToolType.isShapeTool
        return ToolGroupButton(
            tool: toolManager.lastShapeTool,
            isActive: isActive,
            glassNS: glassNS,
            selectionNS: selectionNS,
            selectionId: "shapeSelection"
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                toolManager.switchTool(toolManager.lastShapeTool)
            }
        } onLongPress: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showShapePicker = true
                showTextPresets = false
                showInsertPicker = false
            }
        }
        .scaleEffect(mag)
        .zIndex(mag > 1.01 ? Double(mag * 10) : 0)
        .background(GeometryReader { geo in
            Color.clear.onAppear { shapeButtonFrame = geo.frame(in: .named("toolbar")) }
                .onChange(of: geo.frame(in: .named("toolbar"))) { _, f in shapeButtonFrame = f }
        })
    }

    // MARK: - Insert Group Button

    private func insertGroupButton(index: Int, mag: CGFloat) -> some View {
        let isActive = toolManager.activeToolType.isInsertTool
        return ToolGroupButton(
            tool: toolManager.lastInsertTool,
            isActive: isActive,
            glassNS: glassNS,
            selectionNS: selectionNS,
            selectionId: "insertSelection"
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                toolManager.switchTool(toolManager.lastInsertTool)
            }
        } onLongPress: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showInsertPicker = true
                showTextPresets = false
                showShapePicker = false
            }
        }
        .scaleEffect(mag)
        .zIndex(mag > 1.01 ? Double(mag * 10) : 0)
        .background(GeometryReader { geo in
            Color.clear.onAppear { insertButtonFrame = geo.frame(in: .named("toolbar")) }
                .onChange(of: geo.frame(in: .named("toolbar"))) { _, f in insertButtonFrame = f }
        })
    }

    // MARK: - Flyout Pickers

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
                .quickTooltip(preset.displayName)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .onHover { hovering in
            if !hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.15)) { showTextPresets = false }
                }
            }
        }
    }

    private var shapePicker: some View {
        HStack(spacing: 2) {
            ForEach(ToolType.shapeTools, id: \.self) { tool in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showShapePicker = false
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        toolManager.switchTool(tool)
                    }
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 13, weight: toolManager.activeToolType == tool ? .semibold : .regular))
                        .foregroundStyle(toolManager.activeToolType == tool ? .primary : .secondary)
                        .frame(width: 32, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .quickTooltip("\(tool.displayName) (\(String(tool.shortcutKey).uppercased()))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .onHover { hovering in
            if !hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.15)) { showShapePicker = false }
                }
            }
        }
    }

    private var insertPicker: some View {
        HStack(spacing: 2) {
            ForEach(ToolType.insertTools, id: \.self) { tool in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showInsertPicker = false
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        toolManager.switchTool(tool)
                    }
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 13, weight: toolManager.activeToolType == tool ? .semibold : .regular))
                        .foregroundStyle(toolManager.activeToolType == tool ? .primary : .secondary)
                        .frame(width: 32, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .quickTooltip("\(tool.displayName) (\(String(tool.shortcutKey).uppercased()))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .onHover { hovering in
            if !hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.15)) { showInsertPicker = false }
                }
            }
        }
    }

    // MARK: - Magnification

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
        guard index >= 0, index < toolItems.count else { return nil }
        return index
    }

    // MARK: - Undo/Redo

    private var undoRedoSection: some View {
        HStack(spacing: 4) {
            Button {
                undoManager?.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(undoManager?.canUndo == true ? .primary : .quaternary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(undoManager?.canUndo != true)
            .quickTooltip("Undo (\u{2318}Z)")

            Button {
                undoManager?.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(undoManager?.canRedo == true ? .primary : .quaternary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(undoManager?.canRedo != true)
            .quickTooltip("Redo (\u{21E7}\u{2318}Z)")
        }
    }

    // MARK: - Color & Thickness

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

// MARK: - Tool Item Model

private enum ToolItem: Identifiable {
    case single(ToolType)
    case shapeGroup
    case insertGroup

    var id: String {
        switch self {
        case .single(let t): t.rawValue
        case .shapeGroup: "_shapes"
        case .insertGroup: "_insert"
        }
    }
}

// MARK: - Quick Tooltip

private struct QuickTooltipModifier: ViewModifier {
    let text: String
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeIn(duration: 0.12)) {
                            showTooltip = true
                        }
                    }
                } else {
                    hoverTask = nil
                    withAnimation(.easeOut(duration: 0.1)) {
                        showTooltip = false
                    }
                }
            }
            .overlay(alignment: .top) {
                if showTooltip {
                    Text(text)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: .capsule)
                        .fixedSize()
                        .offset(y: -28)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
    }
}

extension View {
    func quickTooltip(_ text: String) -> some View {
        modifier(QuickTooltipModifier(text: text))
    }
}

// MARK: - Tool Button

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
        .quickTooltip("\(type.displayName) (\(String(type.shortcutKey).uppercased()))")
    }
}

// MARK: - Tool Group Button

private struct ToolGroupButton: View {
    let tool: ToolType
    let isActive: Bool
    var glassNS: Namespace.ID
    var selectionNS: Namespace.ID
    let selectionId: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .frame(width: 32, height: 32)

                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .offset(x: -4, y: -3)
            }
            .contentShape(Rectangle())
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                        .glassEffectUnion(id: "toolbar", namespace: glassNS)
                        .matchedGeometryEffect(id: selectionId, in: selectionNS)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.displayName)
        .accessibilityHint("Hold for more options")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .quickTooltip("\(tool.displayName) (\(String(tool.shortcutKey).uppercased()))")
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in onLongPress() }
        )
    }
}
