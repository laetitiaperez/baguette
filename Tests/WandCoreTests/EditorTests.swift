import Foundation
import Testing
@testable import WandCore

@MainActor
private func makeEditor(_ image: RGBAImage) -> (Editor, UndoManager) {
    let editor = Editor()
    let um = UndoManager()
    um.groupsByEvent = false
    editor.undoManager = um
    editor.tolerance = 0
    editor.contiguous = true
    editor.antiAlias = false
    editor.featherRadius = 0
    editor.load(image)
    return (editor, um)
}

private func stripes() -> RGBAImage {
    var img = RGBAImage(width: 3, height: 1, fill: (0, 0, 0, 255))
    img.setPixel(x: 1, y: 0, (255, 255, 255, 255))
    return img
}

@MainActor
@Suite struct EditorTests {
    @Test func clickModes() {
        let (e, _) = makeEditor(stripes())
        e.click(x: 0, y: 0, mode: .replace)
        #expect(e.selection?.values == [255, 0, 0])
        e.click(x: 2, y: 0, mode: .add)
        #expect(e.selection?.values == [255, 0, 255])
        e.click(x: 0, y: 0, mode: .subtract)
        #expect(e.selection?.values == [0, 0, 255])
        e.click(x: 2, y: 0, mode: .subtract)
        #expect(e.selection == nil)
    }

    @Test func featherAppliedBeforeCombine() {
        let img = stripes()
        let (e, _) = makeEditor(img)
        e.featherRadius = 2
        e.click(x: 0, y: 0, mode: .replace)
        let raw = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        #expect(e.selection == MaskOps.feather(raw, radius: 2))
    }

    @Test func eraseAndUndo() {
        let img = stripes()
        let (e, um) = makeEditor(img)
        e.click(x: 0, y: 0, mode: .replace)
        let sel = e.selection
        e.eraseSelection()
        #expect(e.image?.pixel(x: 0, y: 0).3 == 0)
        #expect(e.image?.pixel(x: 1, y: 0).3 == 255)
        #expect(e.selection == nil)
        #expect(e.isDirty)
        um.undo()
        #expect(e.image == img)
        #expect(e.selection == sel)
        #expect(!e.isDirty)
        um.redo()
        #expect(e.image?.pixel(x: 0, y: 0).3 == 0)
        #expect(e.selection == nil)
        #expect(e.isDirty)
    }

    @Test func selectionUndo() {
        let (e, um) = makeEditor(stripes())
        e.click(x: 0, y: 0, mode: .replace)
        um.undo()
        #expect(e.selection == nil)
        um.redo()
        #expect(e.selection != nil)
    }

    @Test func invertWithoutSelection() {
        let (e, um) = makeEditor(stripes())
        e.invertSelection()
        #expect(e.selection?.values == [255, 255, 255])
        um.undo()
        #expect(e.selection == nil)
    }

    @Test func deselectUndo() {
        let (e, um) = makeEditor(stripes())
        e.deselect()
        #expect(!um.canUndo)
        e.click(x: 0, y: 0, mode: .replace)
        e.deselect()
        #expect(e.selection == nil)
        um.undo()
        #expect(e.selection != nil)
    }

    @Test func noOpClickRegistersNoUndo() {
        let (e, um) = makeEditor(stripes())
        // ⌥-clic sans sélection : le résultat reste « rien de sélectionné ».
        e.click(x: 0, y: 0, mode: .subtract)
        #expect(e.selection == nil)
        #expect(!um.canUndo)
        // Même clic répété : la sélection ne change pas, un seul pas d'annulation.
        e.click(x: 0, y: 0, mode: .replace)
        e.click(x: 0, y: 0, mode: .replace)
        um.undo()
        #expect(e.selection == nil)
        #expect(!um.canUndo)
    }

    @Test func clickOutsideIsNoOp() {
        let (e, um) = makeEditor(stripes())
        e.click(x: 99, y: 0, mode: .replace)
        #expect(e.selection == nil)
        #expect(!e.isDirty)
        #expect(!um.canUndo)
    }

    @Test func loadResets() {
        let (e, um) = makeEditor(stripes())
        e.click(x: 0, y: 0, mode: .replace)
        e.eraseSelection()
        e.load(stripes())
        #expect(e.selection == nil)
        #expect(!e.isDirty)
        #expect(!um.canUndo)
    }

    @Test func markExportedAndSelectionNotDirty() {
        let (e, _) = makeEditor(stripes())
        e.click(x: 0, y: 0, mode: .replace)
        #expect(!e.isDirty)
        e.eraseSelection()
        #expect(e.isDirty)
        e.markExported()
        #expect(!e.isDirty)
    }

    @Test func worksWithoutUndoManager() {
        let e = Editor()
        e.tolerance = 0
        e.load(stripes())
        e.click(x: 0, y: 0, mode: .replace)
        e.eraseSelection()
        #expect(e.isDirty)
    }
}
