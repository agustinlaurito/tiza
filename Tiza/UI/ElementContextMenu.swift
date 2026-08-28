import SwiftUI

struct ElementContextMenu: View {
    @ObservedObject var document: TizaDocument
    @ObservedObject var toolManager: ToolManager
    var undoManager: UndoManager?
    let position: CGPoint
    @Binding var isPresented: Bool

    @State private var appeared = false

    private var selectedElements: [Element] {
        guard let board = document.activeBoardData else { return [] }
        return board.elements.filter { toolManager.selectedElementIds.contains($0.id) }
    }

    private var singleElement: Element? {
        selectedElements.count == 1 ? selectedElements.first : nil
    }

    var body: some View {
        Group {
            if selectedElements.count > 1 {
                multiSelectMenu
            } else if let element = singleElement {
                singleElementMenu(for: element)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .scaleEffect(appeared ? 1.0 : 0.7)
        .opacity(appeared ? 1.0 : 0)
        .position(x: position.x, y: max(position.y - 48, 40))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: position.x)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: position.y)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        .onChange(of: toolManager.selectedElementIds) {
            if toolManager.selectedElementIds.isEmpty {
                withAnimation(.easeOut(duration: 0.15)) {
                    appeared = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Multi-Select Menu (Alignment)

    private var multiSelectMenu: some View {
        HStack(spacing: 4) {
            ForEach(AlignmentMode.allCases, id: \.self) { mode in
                Button {
                    toolManager.alignElementsAnimated(
                        ids: toolManager.selectedElementIds,
                        alignment: mode, document: document, undoManager: undoManager)
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(mode.displayName)
            }

            menuDivider
            deleteAllButton
        }
    }

    // MARK: - Single Element Menu

    @ViewBuilder
    private func singleElementMenu(for element: Element) -> some View {
        switch element.type {
        case .stroke(let data):
            strokeMenu(elementId: element.id, data: data)
        case .shape(let data):
            shapeMenu(elementId: element.id, data: data)
        case .text(let data):
            textMenu(elementId: element.id, data: data)
        case .image:
            imageMenu(elementId: element.id)
        }
    }

    private func strokeMenu(elementId: UUID, data: StrokeData) -> some View {
        HStack(spacing: 4) {
            colorDots(current: data.color) { newColor in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .stroke(var d) = el.type {
                            d.color = newColor
                            el.type = .stroke(d)
                        }
                    }
                }
            }
            menuDivider
            thicknessButtons(current: data.thickness) { newThickness in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .stroke(var d) = el.type {
                            d.thickness = newThickness
                            el.type = .stroke(d)
                        }
                    }
                }
            }
            menuDivider
            scaleButtons(elementId: elementId)
            menuDivider
            copyButton(elementId: elementId)
            deleteButton(elementId: elementId)
        }
    }

    private func shapeMenu(elementId: UUID, data: ShapeData) -> some View {
        HStack(spacing: 4) {
            colorDots(current: data.strokeColor) { newColor in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .shape(var d) = el.type {
                            d.strokeColor = newColor
                            el.type = .shape(d)
                        }
                    }
                }
            }
            menuDivider
            thicknessButtons(current: data.strokeWidth) { newThickness in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .shape(var d) = el.type {
                            d.strokeWidth = newThickness
                            el.type = .shape(d)
                        }
                    }
                }
            }
            menuDivider
            scaleButtons(elementId: elementId)
            menuDivider
            copyButton(elementId: elementId)
            deleteButton(elementId: elementId)
        }
    }

    private func textMenu(elementId: UUID, data: TextData) -> some View {
        HStack(spacing: 4) {
            colorDots(current: data.color) { newColor in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .text(var d) = el.type {
                            d.color = newColor
                            el.type = .text(d)
                        }
                    }
                }
            }

            menuDivider

            textStyleButtons(elementId: elementId, data: data)

            menuDivider

            fontSizeButtons(current: data.fontSize) { newSize in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .text(var d) = el.type {
                            d.fontSize = newSize
                            el.type = .text(d)
                        }
                    }
                }
            }

            menuDivider

            textPresetButtons(elementId: elementId, data: data)

            menuDivider

            fontStylePicker(current: data.fontStyle) { newStyle in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .text(var d) = el.type {
                            d.fontStyle = newStyle
                            el.type = .text(d)
                        }
                    }
                }
            }

            menuDivider
            copyButton(elementId: elementId)
            deleteButton(elementId: elementId)
        }
    }

    private func imageMenu(elementId: UUID) -> some View {
        HStack(spacing: 4) {
            scaleButtons(elementId: elementId)
            menuDivider
            copyButton(elementId: elementId)
            deleteButton(elementId: elementId)
        }
    }

    // MARK: - Text Style Buttons (Bold + Underline)

    private func textStyleButtons(elementId: UUID, data: TextData) -> some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .text(var d) = el.type {
                            d.bold.toggle()
                            el.type = .text(d)
                        }
                    }
                }
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: 12, weight: data.bold ? .bold : .regular))
                    .foregroundStyle(data.bold ? .primary : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Bold")

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    document.updateElement(id: elementId, undoManager: undoManager) { el in
                        if case .text(var d) = el.type {
                            d.underline.toggle()
                            el.type = .text(d)
                        }
                    }
                }
            } label: {
                Image(systemName: "underline")
                    .font(.system(size: 12, weight: data.underline ? .bold : .regular))
                    .foregroundStyle(data.underline ? .primary : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Underline")
        }
    }

    // MARK: - Text Preset Buttons

    private func textPresetButtons(elementId: UUID, data: TextData) -> some View {
        HStack(spacing: 1) {
            ForEach(TextPreset.allCases, id: \.self) { preset in
                let isMatch = data.fontSize == preset.fontSize && data.bold == preset.isBold
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        document.updateElement(id: elementId, undoManager: undoManager) { el in
                            if case .text(var d) = el.type {
                                d.fontSize = preset.fontSize
                                d.bold = preset.isBold
                                el.type = .text(d)
                            }
                        }
                    }
                } label: {
                    Text(preset.shortName)
                        .font(.system(size: 10, weight: preset.isBold ? .bold : .regular))
                        .foregroundStyle(isMatch ? .primary : .secondary)
                        .frame(minWidth: 26, minHeight: 26, maxHeight: 26)
                        .fixedSize()
                        .contentShape(Rectangle())
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isMatch)
                }
                .buttonStyle(.plain)
                .help(preset.displayName)
            }
        }
    }

    // MARK: - Scale Buttons

    private func scaleButtons(elementId: UUID) -> some View {
        HStack(spacing: 2) {
            Button {
                document.scaleElement(id: elementId, factor: 0.8, undoManager: undoManager)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Smaller")

            Button {
                document.scaleElement(id: elementId, factor: 1.25, undoManager: undoManager)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Larger")
        }
    }

    // MARK: - Shared Components

    private func colorDots(current: CodableColor, onSelect: @escaping (CodableColor) -> Void) -> some View {
        HStack(spacing: 2) {
            ForEach(CodableColor.palette.prefix(6), id: \.self) { color in
                Circle()
                    .fill(Color(cgColor: color.cgColor))
                    .frame(width: 14, height: 14)
                    .overlay {
                        if current == color {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 1.5)
                                .frame(width: 18, height: 18)
                        }
                    }
                    .overlay {
                        if color == .white {
                            Circle()
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
                    .onTapGesture { onSelect(color) }
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: current == color)
            }
        }
    }

    private func thicknessButtons(current: Double, onSelect: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 1) {
            ForEach([1.0, 2.0, 4.0, 8.0], id: \.self) { size in
                Button { onSelect(size) } label: {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: size + 3, height: size + 3)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                        .opacity(current == size ? 1.0 : 0.4)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: current == size)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fontSizeButtons(current: Double, onSelect: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 2) {
            Button { onSelect(max(current - 4, 8)) } label: {
                Image(systemName: "textformat.size.smaller")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("\(Int(current))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: current)
                .foregroundStyle(.secondary)
                .frame(minWidth: 20)

            Button { onSelect(min(current + 4, 120)) } label: {
                Image(systemName: "textformat.size.larger")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func fontStylePicker(current: FontStyle, onSelect: @escaping (FontStyle) -> Void) -> some View {
        HStack(spacing: 1) {
            ForEach(FontStyle.allCases, id: \.self) { style in
                Button { onSelect(style) } label: {
                    Text("Aa")
                        .font(swiftUIFont(for: style, size: 13))
                        .foregroundStyle(current == style ? .primary : .secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: current == style)
                }
                .buttonStyle(.plain)
                .help(style.displayName)
            }
        }
    }

    private func swiftUIFont(for style: FontStyle, size: CGFloat) -> Font {
        switch style {
        case .system: .system(size: size, weight: .medium)
        case .serif: .system(size: size, weight: .medium, design: .serif)
        case .rounded: .system(size: size, weight: .medium, design: .rounded)
        }
    }

    private func copyButton(elementId: UUID) -> some View {
        Button {
            document.duplicateElement(id: elementId, undoManager: undoManager)
            toolManager.selectedElementIds = []
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Duplicate")
    }

    private func deleteButton(elementId: UUID) -> some View {
        Button {
            toolManager.deleteElementsAnimated(ids: [elementId],
                                               document: document,
                                               undoManager: undoManager)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Delete")
    }

    private var deleteAllButton: some View {
        Button {
            toolManager.deleteElementsAnimated(ids: toolManager.selectedElementIds,
                                               document: document,
                                               undoManager: undoManager)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Delete All")
    }

    private var menuDivider: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 2)
    }
}
