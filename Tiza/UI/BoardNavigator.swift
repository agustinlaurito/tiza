import SwiftUI

struct BoardNavigator: View {
    @ObservedObject var document: TizaDocument
    @Environment(\.undoManager) private var undoManager
    @Namespace private var navNamespace
    @Namespace private var boardSelectionNS

    @State private var editingBoardIndex: Int?
    @State private var editingName = ""

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(document.model.boards.enumerated()), id: \.element.id) { index, board in
                if editingBoardIndex == index {
                    TextField("Name", text: $editingName, onCommit: {
                        commitRename(at: index)
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(width: 80, height: 28)
                    .multilineTextAlignment(.center)
                    .onExitCommand { editingBoardIndex = nil }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    BoardTab(
                        index: index,
                        board: board,
                        isActive: index == document.model.activeBoardIndex,
                        namespace: navNamespace,
                        selectionNamespace: boardSelectionNS,
                        onSelect: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                document.switchToBoard(at: index)
                            }
                        }
                    )
                    .contextMenu { boardContextMenu(index: index, board: board) }
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    document.addBoard(undoManager: undoManager)
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 6))
                    .glassEffectUnion(id: "nav", namespace: navNamespace)
            }
            .buttonStyle(.plain)
            .help("New Board (⇧⌘N)")
            .accessibilityLabel("Add board")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
        .glassEffectUnion(id: "nav", namespace: navNamespace)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Board navigator")
    }

    @ViewBuilder
    private func boardContextMenu(index: Int, board: BoardReference) -> some View {
        Button("Rename...") {
            editingName = board.name ?? ""
            editingBoardIndex = index
        }

        Divider()

        Menu("Background") {
            ForEach(BoardBackground.allCases, id: \.self) { bg in
                Button {
                    document.model.boards[index].background = bg
                } label: {
                    HStack {
                        Text(bg.displayName)
                        if board.background == bg {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        Button("Duplicate") {
            withAnimation(.easeInOut(duration: 0.15)) {
                document.duplicateBoard(at: index, undoManager: undoManager)
            }
        }

        if document.model.boards.count > 1 {
            Button("Delete", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    document.removeBoard(at: index, undoManager: undoManager)
                }
            }
        }
    }

    private func commitRename(at index: Int) {
        let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        document.model.boards[index].name = name.isEmpty ? nil : name
        editingBoardIndex = nil
    }
}

private struct BoardTab: View {
    let index: Int
    let board: BoardReference
    let isActive: Bool
    var namespace: Namespace.ID
    var selectionNamespace: Namespace.ID
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(board.name ?? "\(index + 1)")
                .font(.system(size: 12, weight: isActive ? .semibold : .regular,
                              design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(minWidth: 28, minHeight: 28, maxHeight: 28)
                .padding(.horizontal, board.name != nil ? 6 : 0)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                            .glassEffectUnion(id: "nav", namespace: namespace)
                            .matchedGeometryEffect(id: "boardSelection", in: selectionNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(board.name ?? "Board \(index + 1)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .help(board.name ?? "Board \(index + 1)")
    }
}
