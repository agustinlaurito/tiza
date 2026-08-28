import SwiftUI

struct WelcomeOverlay: View {
    var onNewWhiteboard: () -> Void
    var onOpenExisting: () -> Void

    @State private var showCard = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButtons = false
    @State private var recentFiles: [URL] = []

    var body: some View {
        ZStack {
            Color.black.opacity(showCard ? 0.15 : 0)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(.primary)
                            .scaleEffect(showIcon ? 1.0 : 0.3)
                            .opacity(showIcon ? 1.0 : 0)
                            .rotationEffect(.degrees(showIcon ? 0 : -20))

                        Text("Tiza")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .opacity(showTitle ? 1.0 : 0)
                            .offset(y: showTitle ? 0 : 8)

                        Text("Whiteboard for teaching")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .opacity(showSubtitle ? 1.0 : 0)
                            .offset(y: showSubtitle ? 0 : 6)
                    }

                    VStack(spacing: 10) {
                        Button(action: onNewWhiteboard) {
                            Label("New Whiteboard", systemImage: "plus.rectangle")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        Button(action: onOpenExisting) {
                            Label("Open Existing\u{2026}", systemImage: "folder")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .frame(width: 220)
                    .opacity(showButtons ? 1.0 : 0)
                    .offset(y: showButtons ? 0 : 10)

                    if !recentFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recent")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            ForEach(recentFiles.prefix(5), id: \.absoluteString) { url in
                                Button {
                                    NSDocumentController.shared.openDocument(
                                        withContentsOf: url, display: true
                                    ) { _, _, _ in }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 13, design: .rounded))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 220)
                        .opacity(showButtons ? 1.0 : 0)
                    }
                }
                .padding(32)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

                Spacer()
            }
            .scaleEffect(showCard ? 1.0 : 0.92)
            .opacity(showCard ? 1.0 : 0)
        }
        .onAppear {
            recentFiles = NSDocumentController.shared.recentDocumentURLs
                .filter { $0.pathExtension == "tiza" }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showCard = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                showIcon = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.25)) {
                showTitle = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.35)) {
                showSubtitle = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.45)) {
                showButtons = true
            }
        }
    }
}
