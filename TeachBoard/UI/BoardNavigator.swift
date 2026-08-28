import SwiftUI

struct BoardNavigator: View {
    @ObservedObject var document: TeachBoardDocument
    @Environment(\.undoManager) private var undoManager

    @State private var isHovering = false
    @State private var showNavigator = true

    var body: some View {
        if showNavigator {
            HStack(spacing: 6) {
                ForEach(Array(document.model.boards.enumerated()), id: \.element.id) { index, board in
                    BoardTab(
                        index: index,
                        board: board,
                        isActive: index == document.model.activeBoardIndex,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                document.switchToBoard(at: index)
                            }
                        }
                    )
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        document.addBoard(undoManager: undoManager)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("New Board (⇧⌘N)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .opacity(isHovering ? 1.0 : 0.7)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
    }
}

private struct BoardTab: View {
    let index: Int
    let board: BoardReference
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: isActive ? .semibold : .regular,
                              design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    isActive
                        ? AnyShapeStyle(.thinMaterial)
                        : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(board.name ?? "Board \(index + 1)")
    }
}
