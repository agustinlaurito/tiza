import SwiftUI

struct ColorPalette: View {
    @Binding var selectedColor: CodableColor
    @State private var showPicker = false
    @Namespace private var colorSelectionNS

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CodableColor.palette, id: \.self) { color in
                ColorDot(color: color, isSelected: selectedColor == color,
                         selectionNamespace: colorSelectionNS) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedColor = color
                    }
                }
            }

            Button {
                showPicker.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("More Colors")
            .popover(isPresented: $showPicker) {
                ColorPickerPopover(selectedColor: $selectedColor)
            }
        }
    }
}

private struct ColorDot: View {
    let color: CodableColor
    let isSelected: Bool
    var selectionNamespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Circle()
            .fill(Color(cgColor: color.cgColor))
            .frame(width: 16, height: 16)
            .overlay(
                color == .white
                    ? Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    : nil
            )
            .frame(width: 24, height: 24)
            .background {
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .matchedGeometryEffect(id: "colorRing", in: selectionNamespace)
                }
            }
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
            .accessibilityLabel(color.accessibilityName)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAddTraits(.isButton)
    }
}

private struct ColorPickerPopover: View {
    @Binding var selectedColor: CodableColor
    @State private var nsColor: NSColor = .black

    var body: some View {
        ColorPicker("Color", selection: Binding(
            get: { Color(nsColor: selectedColor.nsColor) },
            set: { newColor in
                if let c = NSColor(newColor).usingColorSpace(.deviceRGB) {
                    selectedColor = CodableColor(c)
                }
            }
        ), supportsOpacity: false)
        .labelsHidden()
        .padding()
    }
}

struct ThicknessControl: View {
    @Binding var thickness: Double
    var glassNS: Namespace.ID
    var selectionNS: Namespace.ID

    private let sizes: [Double] = [1, 2, 4, 8]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sizes, id: \.self) { size in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        thickness = size
                    }
                } label: {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: size + 4, height: size + 4)
                        .frame(width: 24, height: 24)
                        .background {
                            if thickness == size {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 5))
                                    .glassEffectUnion(id: "toolbar", namespace: glassNS)
                                    .matchedGeometryEffect(id: "thicknessSelection", in: selectionNS)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Thickness \(Int(size))")
                .accessibilityAddTraits(thickness == size ? .isSelected : [])
                .help("Thickness \(Int(size))")
            }
        }
    }
}
