import AppKit
import QuartzCore

final class CanvasAnimator {
    struct DeletingElement {
        let element: Element
        let center: CGPoint
        let startTime: CFTimeInterval
        var progress: CGFloat
    }

    var deletingElements: [DeletingElement] = []
    var animatingOffsets: [UUID: CGPoint] = [:]
    var onNeedsRedraw: (() -> Void)?

    private var deleteDisplayLink: CADisplayLink?
    private var alignDisplayLink: CADisplayLink?
    private var alignInitialDeltas: [UUID: CGPoint] = [:]
    private var alignStartTime: CFTimeInterval = 0

    func deleteElementsAnimated(ids: Set<UUID>, document: TizaDocument,
                                undoManager: UndoManager?) {
        guard let board = document.activeBoardData else { return }
        let selected = board.elements.filter { ids.contains($0.id) }
        guard !selected.isEmpty else { return }

        let now = CACurrentMediaTime()
        deletingElements.append(contentsOf: selected.map { element in
            let bounds = HitTesting.elementBounds(element)
            return DeletingElement(element: element,
                                   center: CGPoint(x: bounds.midX, y: bounds.midY),
                                   startTime: now, progress: 0)
        })

        undoManager?.beginUndoGrouping()
        for id in ids {
            document.removeElement(id: id, undoManager: undoManager)
        }
        undoManager?.endUndoGrouping()

        startDeleteAnimation()
    }

    private func startDeleteAnimation() {
        guard deleteDisplayLink == nil else { return }
        let duration: CFTimeInterval = 0.2

        let target = DisplayLinkTarget { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()

            for i in self.deletingElements.indices {
                let elapsed = now - self.deletingElements[i].startTime
                self.deletingElements[i].progress = min(CGFloat(elapsed / duration), 1.0)
            }

            self.deletingElements.removeAll { $0.progress >= 1.0 }
            self.onNeedsRedraw?()

            if self.deletingElements.isEmpty {
                self.deleteDisplayLink?.invalidate()
                self.deleteDisplayLink = nil
            }
        }

        guard let link = NSScreen.main?.displayLink(target: target,
                                                     selector: #selector(DisplayLinkTarget.step)) else { return }
        link.add(to: .main, forMode: .common)
        deleteDisplayLink = link
    }

    func alignElementsAnimated(ids: Set<UUID>, alignment: AlignmentMode,
                                document: TizaDocument, undoManager: UndoManager?) {
        guard let board = document.activeBoardData else { return }

        var oldCenters: [UUID: CGPoint] = [:]
        for element in board.elements where ids.contains(element.id) {
            let bounds = HitTesting.elementBounds(element)
            oldCenters[element.id] = CGPoint(x: bounds.midX, y: bounds.midY)
        }

        document.alignElements(ids: ids, alignment: alignment, undoManager: undoManager)

        guard let newBoard = document.activeBoardData else { return }
        var deltas: [UUID: CGPoint] = [:]
        for element in newBoard.elements where ids.contains(element.id) {
            let newBounds = HitTesting.elementBounds(element)
            let newCenter = CGPoint(x: newBounds.midX, y: newBounds.midY)
            if let oldCenter = oldCenters[element.id] {
                let dx = oldCenter.x - newCenter.x
                let dy = oldCenter.y - newCenter.y
                if abs(dx) > 0.5 || abs(dy) > 0.5 {
                    deltas[element.id] = CGPoint(x: dx, y: dy)
                }
            }
        }

        guard !deltas.isEmpty else { return }

        alignDisplayLink?.invalidate()
        alignInitialDeltas = deltas
        animatingOffsets = deltas
        alignStartTime = CACurrentMediaTime()

        let duration: CFTimeInterval = 0.3

        let target = DisplayLinkTarget { [weak self] in
            guard let self else { return }
            let elapsed = CACurrentMediaTime() - self.alignStartTime
            let progress = min(CGFloat(elapsed / duration), 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3)

            var newOffsets: [UUID: CGPoint] = [:]
            for (id, delta) in self.alignInitialDeltas {
                newOffsets[id] = CGPoint(x: delta.x * (1.0 - eased),
                                        y: delta.y * (1.0 - eased))
            }
            self.animatingOffsets = newOffsets
            self.onNeedsRedraw?()

            if progress >= 1.0 {
                self.alignDisplayLink?.invalidate()
                self.alignDisplayLink = nil
                self.animatingOffsets = [:]
                self.alignInitialDeltas = [:]
                self.onNeedsRedraw?()
            }
        }

        guard let link = NSScreen.main?.displayLink(target: target,
                                                     selector: #selector(DisplayLinkTarget.step)) else { return }
        link.add(to: .main, forMode: .common)
        alignDisplayLink = link
    }
}

private final class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    @objc func step(_ link: CADisplayLink) { callback() }
}
