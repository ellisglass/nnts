import Foundation
import CoreGraphics

public enum KeyCodes {
    // Virtual Keycodes for macOS (Carbon / HIToolbox standard)
    public static let kVK_ANSI_A: UInt32 = 0x00
    public static let kVK_ANSI_S: UInt32 = 0x01
    public static let kVK_ANSI_D: UInt32 = 0x02
    public static let kVK_ANSI_F: UInt32 = 0x03
    public static let kVK_ANSI_H: UInt32 = 0x04
    public static let kVK_ANSI_G: UInt32 = 0x05
    public static let kVK_ANSI_Z: UInt32 = 0x06
    public static let kVK_ANSI_X: UInt32 = 0x07
    public static let kVK_ANSI_C: UInt32 = 0x08
    public static let kVK_ANSI_V: UInt32 = 0x09
    public static let kVK_ANSI_B: UInt32 = 0x0B
    public static let kVK_ANSI_Q: UInt32 = 0x0C
    public static let kVK_ANSI_W: UInt32 = 0x0D
    public static let kVK_ANSI_E: UInt32 = 0x0E
    public static let kVK_ANSI_R: UInt32 = 0x0F
    public static let kVK_ANSI_Y: UInt32 = 0x10
    public static let kVK_ANSI_T: UInt32 = 0x11
    public static let kVK_ANSI_1: UInt32 = 0x12
    public static let kVK_ANSI_2: UInt32 = 0x13
    public static let kVK_ANSI_3: UInt32 = 0x14
    public static let kVK_ANSI_4: UInt32 = 0x15
    public static let kVK_ANSI_6: UInt32 = 0x16
    public static let kVK_ANSI_5: UInt32 = 0x17
    public static let kVK_ANSI_9: UInt32 = 0x19
    public static let kVK_ANSI_7: UInt32 = 0x1A
    public static let kVK_ANSI_8: UInt32 = 0x1C
    public static let kVK_ANSI_0: UInt32 = 0x1D
    public static let kVK_ANSI_O: UInt32 = 0x1F
    public static let kVK_ANSI_U: UInt32 = 0x20
    public static let kVK_ANSI_I: UInt32 = 0x22
    public static let kVK_ANSI_P: UInt32 = 0x23
    public static let kVK_ANSI_L: UInt32 = 0x25
    public static let kVK_ANSI_J: UInt32 = 0x26
    public static let kVK_ANSI_K: UInt32 = 0x28
    public static let kVK_ANSI_N: UInt32 = 0x2D
    public static let kVK_ANSI_M: UInt32 = 0x2E
    public static let kVK_Escape: UInt32 = 0x35
    public static let kVK_Return: UInt32 = 0x24
    public static let kVK_Space: UInt32 = 0x31
    public static let kVK_F18: UInt32 = 0x4F // 79
    public static let kVK_CapsLock: UInt32 = 0x39 // 57
    public static let kVK_Tab: UInt32 = 0x30
    public static let kVK_LeftArrow: UInt32 = 0x7B
    public static let kVK_RightArrow: UInt32 = 0x7C
    public static let kVK_DownArrow: UInt32 = 0x7D
    public static let kVK_UpArrow: UInt32 = 0x7E
    
    /// Map keycode to character string
    public static func character(for keyCode: UInt32) -> String? {
        switch keyCode {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Escape: return "escape"
        default: return nil
        }
    }
    
    /// Map character (case-insensitive) to Carbon virtual keycode
    public static func keyCode(for character: Character) -> UInt32? {
        switch character.lowercased() {
        case "a": return kVK_ANSI_A
        case "b": return kVK_ANSI_B
        case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D
        case "e": return kVK_ANSI_E
        case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G
        case "h": return kVK_ANSI_H
        case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J
        case "k": return kVK_ANSI_K
        case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M
        case "n": return kVK_ANSI_N
        case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P
        case "q": return kVK_ANSI_Q
        case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S
        case "t": return kVK_ANSI_T
        case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V
        case "w": return kVK_ANSI_W
        case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y
        case "z": return kVK_ANSI_Z
        case "0": return kVK_ANSI_0
        case "1": return kVK_ANSI_1
        case "2": return kVK_ANSI_2
        case "3": return kVK_ANSI_3
        case "4": return kVK_ANSI_4
        case "5": return kVK_ANSI_5
        case "6": return kVK_ANSI_6
        case "7": return kVK_ANSI_7
        case "8": return kVK_ANSI_8
        case "9": return kVK_ANSI_9
        default: return nil
        }
    }
}
