import SwiftUI

struct ColorPalette: View {
    @Binding var selectedColor: CodableColor
    @State private var showPicker = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CodableColor.palette, id: \.self) { color in
                ColorDot(color: color, isSelected: selectedColor == color) {
                    selectedColor = color
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
    let onTap: () -> Void

    var body: some View {
        Circle()
            .fill(Color(cgColor: color.cgColor))
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
                    .frame(width: 20, height: 20)
            )
            .overlay(
                color == .white
                    ? Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    : nil
            )
            .frame(width: 24, height: 24)
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
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

    private let sizes: [Double] = [1, 2, 4, 8]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sizes, id: \.self) { size in
                Button {
                    thickness = size
                } label: {
                    Circle()
                        .fill(Color.primary)
                        .frame(width: size + 4, height: size + 4)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .background(
                    thickness == size
                        ? RoundedRectangle(cornerRadius: 5)
                            .fill(.quaternary)
                        : nil
                )
                .accessibilityLabel("Thickness \(Int(size))")
                .accessibilityAddTraits(thickness == size ? .isSelected : [])
                .help("Thickness \(Int(size))")
            }
        }
    }
}
