import Foundation
import Testing
import AppKit
@testable import ChromeQuickAccess

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testKeyCodes() {
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_A) == "a")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_C) == "c")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_1) == "1")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_2) == "2")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_3) == "3")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_4) == "4")
        #expect(KeyCodes.character(for: KeyCodes.kVK_Escape) == "escape")
        #expect(KeyCodes.character(for: 0xFFFF) == nil)
    }
    

    @Test @MainActor
    func testKeyCodesExtended() {
        #expect(KeyCodes.kVK_LeftArrow == 0x7B)
        #expect(KeyCodes.kVK_RightArrow == 0x7C)
        #expect(KeyCodes.kVK_DownArrow == 0x7D)
        #expect(KeyCodes.kVK_UpArrow == 0x7E)
        #expect(KeyCodes.kVK_Tab == 0x30)
    }
    

    @Test @MainActor
    func testCapsLockHoldingWithShiftFlagsDoesNotPrematurelyRelease() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var modifierReleasedCalled = false
        engine.onModifierReleased = {
            modifierReleasedCalled = true
        }
        
        // 1. User holds CapsLock (F18 KeyDown)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        let resDown = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(resDown == nil) // F18 down swallowed
        #expect(engine.isCapsHeld == true)
        #expect(engine.capsUsedAsModifier == false)
        
        // 2. User presses Shift while holding CapsLock (e.g. preparing for Shift-Tab navigation)
        let shiftEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true)!
        shiftEvent.flags = [.maskShift]
        let resShift = engine.handleEvent(proxy: proxy, type: .flagsChanged, event: shiftEvent)
        #expect(resShift != nil) // Shift passthrough
        
        // CRITICAL BUG VERIFICATION: Shift MUST NOT cause premature modifier release!
        #expect(engine.isCapsHeld == true)
        #expect(modifierReleasedCalled == false)
        
        // 3. User releases CapsLock (F18 KeyUp)
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        let resUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
        #expect(resUp == nil) // F18 up swallowed
        #expect(engine.isCapsHeld == false)
    }
    

    @Test @MainActor
    func testCapsLockTapWithoutModifierDoesNotTriggerEscapeOrModifierReleased() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var modifierReleased = false
        engine.onModifierReleased = { modifierReleased = true }
        
        // 1. User taps Caps Lock (F18 KeyDown)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        let resDown = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(resDown == nil) // F18 down swallowed
        #expect(engine.isCapsHeld == true)
        #expect(engine.capsUsedAsModifier == false)
        
        // 2. User immediately releases Caps Lock (F18 KeyUp) without pressing any other key
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        let resUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
        #expect(resUp == nil) // F18 up swallowed
        #expect(engine.isCapsHeld == false)
        #expect(engine.capsUsedAsModifier == false)
        // Verify modifierReleased callback is NOT triggered since no action occurred
        #expect(modifierReleased == false)
    }
    

    @Test @MainActor
    func testCapsLockAntigravityTrigger() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var antigravityTriggered = false
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_A] = { antigravityTriggered = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        
        // Press 'A'
        let aDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_A), keyDown: true)!
        let resA = engine.handleEvent(proxy: proxy, type: .keyDown, event: aDown)
        #expect(resA == nil) // 'A' swallowed
        #expect(antigravityTriggered == true)
        #expect(engine.capsUsedAsModifier == true)
    }
    

    @Test @MainActor
    func testCapsLockEngineIsStartedState() {
        let engine = CapsLockEngine()
        #expect(engine.isStarted == false)
        #expect(engine.isCapsHeld == false)
        #expect(engine.capsUsedAsModifier == false)
    }
    

    @Test @MainActor
    func testKeyCodesTerminalNotesIde() {
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_T) == "t")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_N) == "n")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_I) == "i")
        #expect(KeyCodes.kVK_ANSI_T == 0x11)
        #expect(KeyCodes.kVK_ANSI_N == 0x2D)
        #expect(KeyCodes.kVK_ANSI_I == 0x22)
    }
    

    @Test @MainActor
    func testCapsLockDynamicLetterTriggers() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var terminalTriggered = false
        var obsidianTriggered = false
        var ideTriggered = false
        
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_T] = { terminalTriggered = true }
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_O] = { obsidianTriggered = true }
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_I] = { ideTriggered = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        
        // Press 'T' (Terminal)
        let tDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_T), keyDown: true)!
        let resT = engine.handleEvent(proxy: proxy, type: .keyDown, event: tDown)
        #expect(resT == nil) // Swallowed
        #expect(terminalTriggered == true)
        
        // Press 'O' (Obsidian)
        let oDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_O), keyDown: true)!
        let resO = engine.handleEvent(proxy: proxy, type: .keyDown, event: oDown)
        #expect(resO == nil) // Swallowed
        #expect(obsidianTriggered == true)
        
        // Press 'I' (IDE)
        let iDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: true)!
        let resI = engine.handleEvent(proxy: proxy, type: .keyDown, event: iDown)
        #expect(resI == nil) // Swallowed
        #expect(ideTriggered == true)
        
        // Check keyUp swallowed
        let tUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_T), keyDown: false)!
        let resTUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: tUp)
        #expect(resTUp == nil)
        
        let oUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_O), keyDown: false)!
        let resOUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: oUp)
        #expect(resOUp == nil)
        
        let iUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: false)!
        let resIUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: iUp)
        #expect(resIUp == nil)
    }
    

    @Test
    func testKeyCodesFullAlphabetAndLookup() {
        #expect(KeyCodes.keyCode(for: "A") == KeyCodes.kVK_ANSI_A)
        #expect(KeyCodes.keyCode(for: "i") == KeyCodes.kVK_ANSI_I)
        #expect(KeyCodes.keyCode(for: "O") == KeyCodes.kVK_ANSI_O)
        #expect(KeyCodes.keyCode(for: "t") == KeyCodes.kVK_ANSI_T)
        #expect(KeyCodes.keyCode(for: "c") == KeyCodes.kVK_ANSI_C)
        #expect(KeyCodes.keyCode(for: "D") == KeyCodes.kVK_ANSI_D)
        #expect(KeyCodes.keyCode(for: "v") == KeyCodes.kVK_ANSI_V)
        #expect(KeyCodes.keyCode(for: "x") == KeyCodes.kVK_ANSI_X)
        #expect(KeyCodes.keyCode(for: "g") == KeyCodes.kVK_ANSI_G)
        #expect(KeyCodes.keyCode(for: "w") == KeyCodes.kVK_ANSI_W)
        
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_I) == "i")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_O) == "o")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_D) == "d")
    }
    

    @Test @MainActor
    func testCapsLockEngineDynamicKeyTriggers() {
        let engine = CapsLockEngine.shared
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        var triggeredKey: UInt32? = nil
        
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_I] = {
            triggeredKey = KeyCodes.kVK_ANSI_I
        }
        defer { engine.dynamicKeyTriggers.removeAll() }
        
        // Simulate Caps Lock held down (F18 down)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(engine.isCapsHeld == true)
        
        // Simulate pressing 'I' (iTerm2 dynamic shortcut)
        let iDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: true)!
        let result = engine.handleEvent(proxy: proxy, type: .keyDown, event: iDown)
        
        // Event should be swallowed and dynamic trigger executed
        #expect(result == nil)
        #expect(triggeredKey == KeyCodes.kVK_ANSI_I)
        #expect(engine.capsUsedAsModifier == true)
        
        // Clean up Caps Lock release
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        _ = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
    }
    
}
