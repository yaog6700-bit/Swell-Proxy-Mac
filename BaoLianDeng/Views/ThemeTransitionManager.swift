import SwiftUI

class ThemeTransitionManager: ObservableObject {
    static let shared = ThemeTransitionManager()
    
    @Published var snapshotImage: NSImage?
    @Published var center: CGPoint = .zero
    @Published var radius: CGFloat = 0
}

extension NSView {
    func snapshot() -> NSImage? {
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage()
        image.addRepresentation(bitmapRep)
        return image
    }
}
