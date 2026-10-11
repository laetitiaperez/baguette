import Foundation
import Observation

/// État d'édition observable : image, sélection, réglages, et annulation par instantanés.
@MainActor @Observable
public final class Editor {
    public private(set) var image: RGBAImage?
    /// `nil` = rien de sélectionné.
    public private(set) var selection: Mask?
    /// Modifié depuis le chargement ou le dernier export.
    public private(set) var isDirty: Bool = false

    public var tolerance: Int = 32
    public var contiguous: Bool = true
    public var antiAlias: Bool = true
    public var featherRadius: Double = 0
    /// Affecté par l'app (celui de la fenêtre). Sans lui, les actions fonctionnent sans annulation.
    @ObservationIgnored public var undoManager: UndoManager?

    private struct Snapshot {
        var image: RGBAImage?
        var selection: Mask?
        var isDirty: Bool
    }

    public init() {}

    public func load(_ image: RGBAImage) {
        self.image = image
        selection = nil
        isDirty = false
        undoManager?.removeAllActions(withTarget: self)
    }

    public func click(x: Int, y: Int, mode: SelectionMode) {
        guard let image, x >= 0, y >= 0, x < image.width, y < image.height else { return }
        var new = MagicWand.select(image, x: x, y: y, tolerance: tolerance,
                                   contiguous: contiguous, antiAlias: antiAlias)
        if featherRadius > 0 { new = MaskOps.feather(new, radius: featherRadius) }
        let combined = MaskOps.combine(selection, new, mode: mode)
        guard combined != selection else { return }
        perform(actionName: "Sélection") { $0.selection = combined }
    }

    public func eraseSelection() {
        guard let image, let selection else { return }
        let erased = erase(image, mask: selection)
        perform(actionName: "Effacer") {
            $0.image = erased
            $0.selection = nil
            $0.isDirty = true
        }
    }

    public func invertSelection() {
        guard let image else { return }
        let inverted = selection.map { MaskOps.invert($0) }
            ?? Mask(width: image.width, height: image.height, value: 255)
        perform(actionName: "Inverser") { $0.selection = inverted.isEmpty ? nil : inverted }
    }

    public func deselect() {
        guard selection != nil else { return }
        perform(actionName: "Désélectionner") { $0.selection = nil }
    }

    public func markExported() {
        isDirty = false
    }

    // MARK: - Annulation

    private var snapshot: Snapshot { Snapshot(image: image, selection: selection, isDirty: isDirty) }

    /// Applique un changement en un seul pas d'annulation.
    private func perform(actionName: String, _ change: (Editor) -> Void) {
        let before = snapshot
        change(self)
        guard let undoManager else { return }
        undoManager.beginUndoGrouping()
        register(restoring: before, actionName: actionName, with: undoManager)
        undoManager.endUndoGrouping()
    }

    private func register(restoring target: Snapshot, actionName: String, with undoManager: UndoManager) {
        undoManager.registerUndo(withTarget: self) { editor in
            MainActor.assumeIsolated {
                let current = editor.snapshot
                editor.image = target.image
                editor.selection = target.selection
                editor.isDirty = target.isDirty
                editor.register(restoring: current, actionName: actionName, with: undoManager)
            }
        }
        undoManager.setActionName(actionName)
    }
}
