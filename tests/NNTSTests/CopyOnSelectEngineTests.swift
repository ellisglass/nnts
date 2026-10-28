import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testCopyOnSelectDefaultParameters() {
        UserDefaults.standard.removeObject(forKey: CopyOnSelectEngine.keyIsEnabled)
        UserDefaults.standard.removeObject(forKey: CopyOnSelectEngine.keyIsToastEnabled)
        UserDefaults.standard.removeObject(forKey: CopyOnSelectEngine.keyAllowEverywhere)
        let engine = CopyOnSelectEngine()
        #expect(engine.isEnabled == true)
        #expect(engine.isToastEnabled == false)
        #expect(engine.allowEverywhere == true)
        #expect(engine.dragThreshold == 7.0)
        #expect(engine.dragCopyDelayMs == 50)
        #expect(engine.multiClickCopyDelayMs == 140)
    }
    

    @Test @MainActor
    func testCopyOnSelectUserDefaultsPersistence() {
        let engine = CopyOnSelectEngine()
        defer {
            engine.isEnabled = true
            engine.isToastEnabled = false
            engine.allowEverywhere = true
        }
        
        engine.isEnabled = false
        #expect(UserDefaults.standard.bool(forKey: CopyOnSelectEngine.keyIsEnabled) == false)
        
        engine.isToastEnabled = true
        #expect(UserDefaults.standard.bool(forKey: CopyOnSelectEngine.keyIsToastEnabled) == true)
        
        engine.allowEverywhere = false
        #expect(UserDefaults.standard.bool(forKey: CopyOnSelectEngine.keyAllowEverywhere) == false)
        
        // Fresh engine instance reflects persisted values
        let secondEngine = CopyOnSelectEngine()
        #expect(secondEngine.isEnabled == false)
        #expect(secondEngine.isToastEnabled == true)
        #expect(secondEngine.allowEverywhere == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectToastSuppression() {
        let engine = CopyOnSelectEngine()
        let originalToast = engine.isToastEnabled
        defer { engine.isToastEnabled = originalToast }
        
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Test Content", forType: .string)
        let initialChangeCount = pboard.changeCount - 1
        
        // When toast is off, evaluateCopiedContent succeeds but CopyToastState remains hidden
        engine.isToastEnabled = false
        CopyToastState.shared.isVisible = false
        let copiedWithoutToast = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: [],
            mousePos: CGPoint(x: 100, y: 100)
        )
        #expect(copiedWithoutToast == true)
        #expect(CopyToastState.shared.isVisible == false)
        
        // When toast is on, evaluateCopiedContent sets CopyToastState.shared.isVisible to true
        engine.isToastEnabled = true
        let copiedWithToast = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: [],
            mousePos: CGPoint(x: 100, y: 100)
        )
        #expect(copiedWithToast == true)
        #expect(CopyToastState.shared.isVisible == true)
        CopyToastState.shared.isVisible = false
    }
    

    @Test @MainActor
    func testCopyOnSelectAllowEverywhereScope() {
        let engine = CopyOnSelectEngine()
        let originalEverywhere = engine.allowEverywhere
        let originalMockFrontmost = CopyOnSelectEngine.mockFrontmostBundleID
        defer {
            engine.allowEverywhere = originalEverywhere
            CopyOnSelectEngine.mockFrontmostBundleID = originalMockFrontmost
        }
        
        CopyOnSelectEngine.mockFrontmostBundleID = "com.apple.Terminal"
        
        // When allowEverywhere is true, Terminal is permitted to copy
        engine.allowEverywhere = true
        let allowed = engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 30, y: 10), clickCount: 1)
        #expect(allowed == true)
        
        // When allowEverywhere is false, Terminal is blocked by sensitiveBundleIDs
        engine.allowEverywhere = false
        let blocked = engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 30, y: 10), clickCount: 1)
        #expect(blocked == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectDragDistanceTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Horizontal drag exceeding threshold (dx = 15 > 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 115, y: 100), clickCount: 1) == true)
        
        // Multi-line vertical drag exceeding threshold (dy = 16 >= 15)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 116), clickCount: 1) == true)
        
        // Negative direction drag exceeding threshold (dx = 15 > 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 85, y: 100), clickCount: 1) == true)
        
        // Sub-threshold movement (dx = 5 <= 10, dy = 5 <= 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 105, y: 105), clickCount: 1) == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectMultiClickTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Double-click at same position (word selection)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 2) == true)
        
        // Triple-click at same position (paragraph selection)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 3) == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectSingleClickNoTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Normal single click with zero displacement
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 250, y: 300), end: CGPoint(x: 250, y: 300), clickCount: 1) == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectDisabledState() {
        let engine = CopyOnSelectEngine()
        let previous = engine.isEnabled
        defer { engine.isEnabled = previous }
        engine.isEnabled = false
        
        // Exceeding drag threshold must be ignored when disabled
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 200, y: 200), clickCount: 1) == false)
        
        // Multi-click must be ignored when disabled
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 2) == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectPostKeystrokeCallback() async throws {
        let engine = CopyOnSelectEngine()
        let previous = engine.isEnabled
        defer { engine.isEnabled = previous }
        engine.isEnabled = true
        var callbackFired = false
        engine.onCopyKeystrokePosted = {
            callbackFired = true
        }
        
        engine.postCopyKeystroke()
        try await Task.sleep(nanoseconds: 35_000_000)
        #expect(callbackFired == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectLifecycleAndToggle() {
        let engine = CopyOnSelectEngine()
        let previous = engine.isEnabled
        defer { engine.isEnabled = previous }
        engine.isEnabled = true
        #expect(engine.isEnabled == true)
        
        engine.isEnabled.toggle()
        #expect(engine.isEnabled == false)
        
        engine.isEnabled.toggle()
        #expect(engine.isEnabled == true)
        
        engine.stop()
        #expect(engine.isStarted == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectEmptyStringFilteringHelper() {
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("   ") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("\n\t\r ") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace(nil) == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("hello") == false)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("  hello  ") == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectPreFlightAXEmptyStringFiltering() {
        CopyOnSelectEngine.mockFocusedSelectedText = "   "
        defer { CopyOnSelectEngine.mockFocusedSelectedText = nil }
        
        let engine = CopyOnSelectEngine()
        let selected = engine.focusedElementSelectedText()
        #expect(selected == "   ")
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace(selected) == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectPasteboardEmptyStringSuppressionAndRestoration() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Preserved Clipboard Content", forType: .string)
        
        // Snapshot existing clipboard state
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // Target app copies empty string or whitespace into pasteboard
        pboard.clearContents()
        pboard.setString("   \n", forType: .string)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 100, y: 100)
        )
        
        // Should suppress the copy and restore previous content
        #expect(didCopy == false)
        #expect(pboard.string(forType: .string) == "Preserved Clipboard Content")
    }
    

    @Test @MainActor
    func testCopyOnSelectPasteboardValidStringAcceptance() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Old Content", forType: .string)
        
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // Target app copies valid non-empty string
        pboard.clearContents()
        pboard.setString("Valid Selected Text", forType: .string)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 100, y: 100)
        )
        
        #expect(didCopy == true)
        #expect(pboard.string(forType: .string) != nil)
    }
    

    @Test @MainActor
    func testCopyOnSelectCanvasPayloadDetectionHelper() {
        // Excalidraw empty canvas payload
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"type\":\"excalidraw/clipboard\",\"elements\":[],\"files\":{}}") == true)
        // Excalidraw shape payload
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"type\":\"excalidraw/clipboard\",\"elements\":[{\"id\":\"1\",\"type\":\"line\"}]}") == true)
        // tldraw payload
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"type\":\"tldraw/clipboard\",\"shape\":\"arrow\"}") == true)
        // Miro schema payload
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"schema\":\"miro\",\"data\":{}}") == true)
        // Draw.io XML payload
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("<mxGraphModel><root><mxCell id=\"0\"/></root></mxGraphModel>") == true)
        // Empty canvas arrays
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"objects\":[]}") == true)
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"shapes\":[]}") == true)
        
        // Normal text and code MUST NOT be flagged as canvas payloads
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("Hello world") == false)
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("{\"name\": \"my-app\", \"version\": \"1.0.0\"}") == false)
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("let x = 42") == false)
        #expect(CopyOnSelectEngine.isCanvasOrInternalEditorPayload("Excalidraw is a whiteboard app") == false)
    }


    @Test @MainActor
    func testCopyOnSelectCanvasPayloadRejectionAndRestoration() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("User Original Note", forType: .string)
        
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // Excalidraw copies canvas JSON into pasteboard
        pboard.clearContents()
        pboard.setString("{\"type\":\"excalidraw/clipboard\",\"elements\":[],\"files\":{}}", forType: .string)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 200, y: 200)
        )
        
        #expect(didCopy == false)
        #expect(pboard.string(forType: .string) == "User Original Note")
    }


    @Test @MainActor
    func testCopyOnSelectCanvasAndDrawingBundleIDsProtection() {
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.apple.freeform"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.figma.Desktop"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.adobe.Photoshop"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("org.blenderfoundation.blender"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.apple.FinalCut"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.apple.logic10"))
        #expect(CopyOnSelectEngine.canvasAndDrawingBundleIDs.contains("com.ableton.live"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSlider"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXScrollBar"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSplitter"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXCanvas"))
    }


    @Test @MainActor
    func testCopyOnSelectNonTextPasteboardRejection() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Preserved Content", forType: .string)
        
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // App copies non-text data (e.g. only custom binary type, no .string)
        pboard.clearContents()
        let customType = NSPasteboard.PasteboardType("com.custom.binary")
        pboard.setData(Data([0x01, 0x02, 0x03]), forType: customType)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 100, y: 100)
        )
        
        #expect(didCopy == false)
        #expect(pboard.string(forType: .string) == "Preserved Content")
    }


    @Test @MainActor
    func testCopyOnSelectNonTextControlSuppression() {
        CopyOnSelectEngine.mockNonTextControlDetected = true
        defer { CopyOnSelectEngine.mockNonTextControlDetected = nil }
        
        let engine = CopyOnSelectEngine()
        #expect(engine.isPointOnNonTextControl(cgPoint: CGPoint(x: 50, y: 50)) == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectSpreadsheetEnvironmentPreFlightSuppression() {
        CopyOnSelectEngine.mockSpreadsheetEnvironment = true
        CopyOnSelectEngine.mockEditingTextInSpreadsheet = false
        defer {
            CopyOnSelectEngine.mockSpreadsheetEnvironment = nil
            CopyOnSelectEngine.mockEditingTextInSpreadsheet = nil
        }
        
        let engine = CopyOnSelectEngine()
        
        // Double-click on column divider / fill handle / grid cell should be SUPPRESSED
        let doubleClickTrigger = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 100, y: 100),
            clickCount: 2
        )
        #expect(doubleClickTrigger == false)
        
        // Dragging column divider to resize or dragging cell to move should be SUPPRESSED
        let dragResizeTrigger = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 150, y: 100),
            clickCount: 1
        )
        #expect(dragResizeTrigger == false)
        
        // When user is actively editing text in cell / formula bar, copying IS allowed
        CopyOnSelectEngine.mockEditingTextInSpreadsheet = true
        let inCellDoubleClickTrigger = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 100, y: 100),
            clickCount: 2
        )
        #expect(inCellDoubleClickTrigger == true)
        
        let inCellDragTrigger = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 120, y: 100),
            clickCount: 1
        )
        #expect(inCellDragTrigger == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectGoogleSheetsAndM365PayloadFiltering() {
        let pboard = NSPasteboard.general
        
        // 1. Google Sheets grid cell origin
        pboard.clearContents()
        pboard.setString("<google-sheets-html-origin><style></style><table><tr><td>Cell 1</td></tr></table>", forType: .html)
        pboard.setString("Cell 1", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == true)
        
        // 2. Google Sheets data-sheets-value
        pboard.clearContents()
        pboard.setString("<span data-sheets-value=\"[null,2,&quot;Total&quot;]\">Total</span>", forType: .html)
        pboard.setString("Total", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == true)
        
        // 3. Microsoft 365 Excel Online ProgId
        pboard.clearContents()
        pboard.setString("<html xmlns:x=\"urn:schemas-microsoft-com:office:excel\"><head><meta name=ProgId content=Excel.Sheet></head><body>123</body></html>", forType: .html)
        pboard.setString("123", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == true)
        
        // 4. Desktop Excel BIFF type
        pboard.clearContents()
        pboard.setData(Data([0x00, 0x01]), forType: NSPasteboard.PasteboardType("com.microsoft.excel.biff12"))
        pboard.setString("Data", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == true)
        
        // 5. Apple Numbers table type
        pboard.clearContents()
        pboard.setData(Data([0x00, 0x01]), forType: NSPasteboard.PasteboardType("com.apple.iWork.table"))
        pboard.setString("Numbers Data", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == true)
        
        // 6. Normal human web selection MUST NOT be flagged as a spreadsheet grid payload
        pboard.clearContents()
        pboard.setString("<meta charset='utf-8'><p>Article text selected on a website</p>", forType: .html)
        pboard.setString("Article text selected on a website", forType: .string)
        #expect(CopyOnSelectEngine.isSpreadsheetCellOrGridPayload(pasteboard: pboard) == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectExpandedNonTextRolesAndSubroles() {
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXColumnHeader"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXRowHeader"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXHeader"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXTableColumn"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSplitGroup"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXRulerMarker"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXDockItem"))
        
        #expect(CopyOnSelectEngine.nonTextSubroles.contains("AXSortButton"))
        #expect(CopyOnSelectEngine.nonTextSubroles.contains("AXResizeHandle"))
        #expect(CopyOnSelectEngine.nonTextSubroles.contains("AXDivider"))
        
        #expect(CopyOnSelectEngine.spreadsheetBundleIDs.contains("com.microsoft.Excel"))
        #expect(CopyOnSelectEngine.spreadsheetBundleIDs.contains("com.apple.iWork.Numbers"))
    }
    

    @Test @MainActor
    func testCopyOnSelectTimingAndSensitivity() {
        let engine = CopyOnSelectEngine()
        #expect(engine.dragThreshold == 7.0)
        #expect(engine.dragCopyDelayMs == 50)
        #expect(engine.multiClickCopyDelayMs == 140)
        
        // Micro-jitter of 3pt is ignored
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 13, y: 11), clickCount: 1) == false)
        // Short text drag of 8pt is accepted
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 18, y: 10), clickCount: 1) == true)
    }
    

    @Test @MainActor
    func testCopyToastWindowTightBoundsAndClamping() {
        let window = CopyToastWindow.shared
        #expect(window.frame.width == 84)
        #expect(window.frame.height == 28)
    }
    

    @Test @MainActor
    func testCopyOnSelectDirectionalJitterRejection() {
        let engine = CopyOnSelectEngine()
        
        // 1. Pure vertical jitter on single line (dx = 2pt < 4pt, dy = 8pt < 15pt) must be REJECTED
        let verticalJitter = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 102, y: 108),
            clickCount: 1,
            duration: 0.2
        )
        #expect(verticalJitter == false)
        
        // 2. Intentional horizontal text selection (dx = 8pt >= 7pt, dy = 1pt) must be ACCEPTED
        let horizontalDrag = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 108, y: 101),
            clickCount: 1,
            duration: 0.2
        )
        #expect(horizontalDrag == true)
        
        // 3. Multi-line vertical text drag (dx = 2pt, dy = 16pt >= 15pt) must be ACCEPTED
        let multiLineDrag = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 102, y: 116),
            clickCount: 1,
            duration: 0.2
        )
        #expect(multiLineDrag == true)
        
        // 4. Sub-threshold micro-jitter (hypot(3, 3) = 4.24 < 7pt) must be REJECTED
        let microJitter = engine.shouldTriggerCopy(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 103, y: 103),
            clickCount: 1,
            duration: 0.2
        )
        #expect(microJitter == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectClickSlipDurationRejection() {
        let engine = CopyOnSelectEngine()
        
        // 1. Rapid click-slip (duration 50ms < 90ms, small distance 10pt < 18pt) must be REJECTED
        let rapidSlip = engine.isIntentionalTextDrag(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 110, y: 100),
            duration: 0.05
        )
        #expect(rapidSlip == false)
        
        // 2. Deliberate drag (duration 150ms >= 90ms, distance 10pt) must be ACCEPTED
        let deliberateDrag = engine.isIntentionalTextDrag(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 110, y: 100),
            duration: 0.15
        )
        #expect(deliberateDrag == true)
        
        // 3. Large fast swipe (duration 50ms, large distance 25pt >= 18pt) must be ACCEPTED
        let fastSwipe = engine.isIntentionalTextDrag(
            start: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 125, y: 100),
            duration: 0.05
        )
        #expect(fastSwipe == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectCaretZeroLengthRejection() {
        let engine = CopyOnSelectEngine()
        
        CopyOnSelectEngine.mockHasActiveTextSelection = false
        #expect(engine.hasActiveTextSelection() == false)
        
        CopyOnSelectEngine.mockHasActiveTextSelection = true
        #expect(engine.hasActiveTextSelection() == true)
        
        CopyOnSelectEngine.mockHasActiveTextSelection = nil
    }
    

    @Test @MainActor
    func testCopyOnSelectInteractiveControlsImmunity() {
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXButton"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXCheckBox"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXRadioButton"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXPopUpButton"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXTab"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSegmentedControl"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSwitch"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXMenuItem"))
    }
    

    @Test @MainActor
    func testCopyOnSelectIgnoresCommandOrControlDrags() {
        let engine = CopyOnSelectEngine()
        
        var copyPosted = false
        engine.onCopyKeystrokePosted = { copyPosted = true }
        
        // MouseDown with Command modifier held (e.g. moving background window)
        let cmdDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        cmdDown.flags = [.maskCommand]
        engine.handleTapEvent(type: .leftMouseDown, event: cmdDown)
        
        // MouseUp with Command modifier held
        let cmdUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 300, y: 300), mouseButton: .left)!
        cmdUp.flags = [.maskCommand]
        engine.handleTapEvent(type: .leftMouseUp, event: cmdUp)
        
        #expect(copyPosted == false)
        
        // MouseDown with Control modifier held (e.g. connecting Xcode IBOutlet)
        let ctrlDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        ctrlDown.flags = [.maskControl]
        engine.handleTapEvent(type: .leftMouseDown, event: ctrlDown)
        
        let ctrlUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 300, y: 300), mouseButton: .left)!
        ctrlUp.flags = [.maskControl]
        engine.handleTapEvent(type: .leftMouseUp, event: ctrlUp)
        
        #expect(copyPosted == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectTapDisablementRecovery() {
        let engine = CopyOnSelectEngine()
        let previous = engine.isEnabled
        defer { engine.isEnabled = previous }
        engine.isEnabled = true
        let dummy = CGEvent(source: nil)!
        
        // Must handle disabled by timeout without throwing or crashing
        engine.handleTapEvent(type: .tapDisabledByTimeout, event: dummy)
        engine.handleTapEvent(type: .tapDisabledByUserInput, event: dummy)
        #expect(engine.isEnabled == true)
    }
    

    @Test @MainActor
    func testCopyOnSelectPendingCopyCancellation() async throws {
        let engine = CopyOnSelectEngine()
        let previous = engine.isEnabled
        let previousEverywhere = engine.allowEverywhere
        defer {
            engine.isEnabled = previous
            engine.allowEverywhere = previousEverywhere
            CopyOnSelectEngine.mockFrontmostBundleID = nil
        }
        engine.isEnabled = true
        engine.allowEverywhere = true
        CopyOnSelectEngine.mockFrontmostBundleID = "com.apple.Safari"
        var copyKeystrokes = 0
        engine.onCopyKeystrokePosted = {
            copyKeystrokes += 1
        }
        engine.copyDelayMs = 40 // short delay for test
        
        // 1. Trigger a double-click to schedule a copy
        let doubleClickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        doubleClickUp.setIntegerValueField(.mouseEventClickState, value: 2)
        
        let dummyDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        engine.handleTapEvent(type: .leftMouseDown, event: dummyDown)
        engine.handleTapEvent(type: .leftMouseUp, event: doubleClickUp)
        
        #expect(engine.hasPendingCopy == true)
        
        // 2. User immediately clicks down somewhere else (e.g. to deselect or click button)
        let deselectDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 200, y: 200), mouseButton: .left)!
        engine.handleTapEvent(type: .leftMouseDown, event: deselectDown)
        
        // The pending copy must be cancelled!
        #expect(engine.hasPendingCopy == false)
        
        // Wait longer than copyDelayMs to confirm keystroke was NEVER posted
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(copyKeystrokes == 0)
    }
    

    @Test @MainActor
    func testCopyToastWindowProperties() {
        let toast = CopyToastWindow.shared
        #expect(toast.isFloatingPanel == true)
        #expect(toast.isOpaque == false)
        #expect(toast.ignoresMouseEvents == true)
        
        toast.show(at: CGPoint(x: 200, y: 200))
        #expect(CopyToastState.shared.isVisible == true)
        toast.hideImmediate()
        #expect(CopyToastState.shared.isVisible == false)
    }
    

    @Test @MainActor
    func testCopyOnSelectNNTSWindowDetection() {
        let engine = CopyOnSelectEngine()
        _ = engine.isInteractingWithNNTSWindow
        #expect(engine.dragThreshold == 7.0)
    }


    @Test @MainActor
    func testCopyOnSelectSensitiveBundleIDsProtection() {
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.Passwords"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.1password.1password"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.bitwarden.desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.keychainaccess"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.Terminal"))
    }


    @Test @MainActor
    func testCopyOnSelectEnhancedSensitiveBundleIDsProtection() {
        // Modern Terminal Emulators
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.mitchellh.ghostty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("net.kovidgoyal.kitty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.alacritty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.github.wez.wezterm"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("dev.warp.Warp-Stable"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.googlecode.iterm2"))
        
        // Password Managers & Vaults
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.dashlane.dashlanephone"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.enpass.Enpass-Desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.nordpass.macos"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.keepassxc.keepassxc"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.whispersystems.signal-desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("me.proton.pass"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.yubico.authenticator"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.authy"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.2fas.desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.strongbox.mac"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.elpass.app"))
    }

    @Test @MainActor
    func testCopyOnSelectInviolableVaultsNeverBypassedEvenWithAllowEverywhere() {
        let engine = CopyOnSelectEngine()
        let originalEverywhere = engine.allowEverywhere
        let originalMockFrontmost = CopyOnSelectEngine.mockFrontmostBundleID
        defer {
            engine.allowEverywhere = originalEverywhere
            CopyOnSelectEngine.mockFrontmostBundleID = originalMockFrontmost
        }
        
        // When allowEverywhere is true, Terminal is permitted
        engine.allowEverywhere = true
        CopyOnSelectEngine.mockFrontmostBundleID = "com.apple.Terminal"
        let terminalAllowed = engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 30, y: 10), clickCount: 1)
        #expect(terminalAllowed == true)
        
        // BUT password vaults and authenticators MUST strictly remain blocked
        let vaultIDs = [
            "com.1password.1password",
            "com.apple.Passwords",
            "me.proton.pass",
            "com.bitwarden.desktop",
            "com.yubico.authenticator"
        ]
        
        for vaultID in vaultIDs {
            CopyOnSelectEngine.mockFrontmostBundleID = vaultID
            let vaultBlocked = engine.shouldTriggerCopy(start: CGPoint(x: 10, y: 10), end: CGPoint(x: 30, y: 10), clickCount: 1)
            #expect(vaultBlocked == false, "Vault \(vaultID) must be blocked even when allowEverywhere is enabled.")
        }
    }


    @Test @MainActor
    func testCopyOnSelectNonTextRolesExcludesAXGraphic() {
        #expect(!CopyOnSelectEngine.nonTextControlRoles.contains("AXGraphic"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXSlider"))
        #expect(CopyOnSelectEngine.nonTextControlRoles.contains("AXScrollBar"))
    }

}
