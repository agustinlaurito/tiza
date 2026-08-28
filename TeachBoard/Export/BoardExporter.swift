import AppKit
import CoreGraphics

enum BoardExporter {
    static func exportAsPNG(board: BoardData, background: BoardBackground,
                            imageCache: [String: NSImage],
                            appearance: NSAppearance?) -> Data? {
        let (camera, size) = computeExportFrame(board: board)
        let scale: CGFloat = 2.0
        let pixelW = Int(size.width * scale)
        let pixelH = Int(size.height * scale)

        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        BoardBackgroundRenderer.draw(background, in: ctx, viewSize: size,
                                     camera: camera, appearance: appearance)
        Renderer.drawElements(board.elements, in: ctx, camera: camera,
                              viewSize: size, imageCache: imageCache)

        guard let image = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = size
        return rep.representation(using: .png, properties: [:])
    }

    static func exportAsPDF(board: BoardData, background: BoardBackground,
                            imageCache: [String: NSImage],
                            appearance: NSAppearance?) -> Data {
        let (camera, size) = computeExportFrame(board: board)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: size)

        guard let consumer = CGDataConsumer(data: data),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return Data() }

        ctx.beginPDFPage(nil)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        BoardBackgroundRenderer.draw(background, in: ctx, viewSize: size,
                                     camera: camera, appearance: appearance)
        Renderer.drawElements(board.elements, in: ctx, camera: camera,
                              viewSize: size, imageCache: imageCache)

        ctx.endPDFPage()
        ctx.closePDF()

        return data as Data
    }

    private static func computeExportFrame(board: BoardData) -> (Camera, CGSize) {
        guard !board.elements.isEmpty else {
            return (Camera(), CGSize(width: 1024, height: 768))
        }

        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity

        for element in board.elements {
            let bounds = HitTesting.elementBounds(element)
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }

        let padding: CGFloat = 50
        let w = maxX - minX + padding * 2
        let h = maxY - minY + padding * 2
        let size = CGSize(width: max(w, 200), height: max(h, 200))

        var camera = Camera()
        camera.center = CGPoint(x: minX + (maxX - minX) / 2,
                                y: minY + (maxY - minY) / 2)
        camera.scale = 1.0

        return (camera, size)
    }
}
