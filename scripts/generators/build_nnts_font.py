import os
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

def build_nnts_display_font(output_path="assets/fonts/NNTSDisplay-Black.ttf"):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    UPM = 1000
    CAP = 750
    ASC = 800
    DESC = -200
    SW = 190   # Stem width (vertical thickness)
    HW = 175   # Horizontal bar thickness
    
    fb = FontBuilder(UPM, isTTF=True)
    
    glyph_names = [
        '.notdef', 'space',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
        'period', 'comma', 'colon', 'hyphen', 'plus', 'slash', 'bracketleft', 'bracketright',
        'parenleft', 'parenright', 'exclam', 'periodcentered', 'ampersand'
    ]
    fb.setupGlyphOrder(glyph_names)
    
    cmap = {
        0x20: 'space',
        ord('.'): 'period',
        ord(','): 'comma',
        ord(':'): 'colon',
        ord('-'): 'hyphen',
        ord('+'): 'plus',
        ord('/'): 'slash',
        ord('&'): 'ampersand',
        ord('['): 'bracketleft',
        ord(']'): 'bracketright',
        ord('('): 'parenleft',
        ord(')'): 'parenright',
        ord('!'): 'exclam',
        0x00B7: 'periodcentered',
        0x2013: 'hyphen',  # en-dash –
        0x2014: 'hyphen',  # em-dash —
    }
    for char in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        cmap[ord(char)] = char
    num_names = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
    for i, name in enumerate(num_names):
        cmap[ord(str(i))] = name
        
    fb.setupCharacterMap(cmap)
    
    glyf_dict = {}
    metrics_dict = {}
    
    # Clockwise rectangle in TTF: (x0,y0) -> (x0,y1) -> (x1,y1) -> (x1,y0) -> close
    def draw_cw_rect(pen, x0, y0, x1, y1):
        pen.moveTo((x0, y0))
        pen.lineTo((x0, y1))
        pen.lineTo((x1, y1))
        pen.lineTo((x1, y0))
        pen.closePath()

    # .notdef
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 100, 0, 700, CAP)
    # Counter-clockwise hole
    pen.moveTo((100 + SW, SW))
    pen.lineTo((700 - SW, SW))
    pen.lineTo((700 - SW, CAP - SW))
    pen.lineTo((100 + SW, CAP - SW))
    pen.closePath()
    glyf_dict['.notdef'] = pen.glyph()
    metrics_dict['.notdef'] = (800, 100)
    
    # space
    pen = TTGlyphPen(None)
    glyf_dict['space'] = pen.glyph()
    metrics_dict['space'] = (380, 0)

    # N (Canonical NNTS master geometry)
    pen = TTGlyphPen(None)
    W_N = 920
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_N - 60 - SW, 0, W_N - 60, CAP)
    # Diagonal (CW)
    pen.moveTo((60, CAP))
    pen.lineTo((60 + SW + 80, CAP))
    pen.lineTo((W_N - 60, 0))
    pen.lineTo((W_N - 60 - SW - 80, 0))
    pen.closePath()
    glyf_dict['N'] = pen.glyph()
    metrics_dict['N'] = (W_N + 30, 60)

    # T (Canonical NNTS master geometry)
    pen = TTGlyphPen(None)
    W_T = 840
    draw_cw_rect(pen, 40, CAP - HW, W_T - 40, CAP)
    cx = W_T // 2
    draw_cw_rect(pen, cx - SW//2, 0, cx + SW//2, CAP - HW)
    glyf_dict['T'] = pen.glyph()
    metrics_dict['T'] = (W_T + 20, 40)

    # S (Canonical NNTS master geometry - Open apertures)
    pen = TTGlyphPen(None)
    W_S = 860
    # Top bar
    draw_cw_rect(pen, 60, CAP - HW, W_S - 60, CAP)
    # Upper-left stem (only goes down to middle)
    draw_cw_rect(pen, 60, CAP//2, 60 + SW, CAP)
    # Middle crossbar
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_S - 60, CAP//2 + HW//2)
    # Lower-right stem (only goes from bottom up to middle)
    draw_cw_rect(pen, W_S - 60 - SW, 0, W_S - 60, CAP//2)
    # Bottom bar
    draw_cw_rect(pen, 60, 0, W_S - 60, HW)
    # Top terminal (pointing down from top-right)
    draw_cw_rect(pen, W_S - 60 - SW, CAP - HW - 90, W_S - 60, CAP - HW)
    # Bottom terminal (pointing up from bottom-left)
    draw_cw_rect(pen, 60, HW, 60 + SW, HW + 90)
    glyf_dict['S'] = pen.glyph()
    metrics_dict['S'] = (W_S + 30, 60)

    # A (Clean unified geometry)
    pen = TTGlyphPen(None)
    W_A = 920
    # Left stem (CW)
    pen.moveTo((60, 0))
    pen.lineTo((60, 0))
    pen.lineTo((W_A//2 - SW//2, CAP))
    pen.lineTo((W_A//2 + SW//2, CAP))
    pen.lineTo((60 + SW, 0))
    pen.closePath()
    # Right stem (CW)
    pen.moveTo((W_A - 60 - SW, 0))
    pen.lineTo((W_A//2 - SW//2, CAP))
    pen.lineTo((W_A//2 + SW//2, CAP))
    pen.lineTo((W_A - 60, 0))
    pen.closePath()
    # Top cap fill
    draw_cw_rect(pen, W_A//2 - SW//2, CAP - HW, W_A//2 + SW//2, CAP)
    # Crossbar
    draw_cw_rect(pen, 200, 200, W_A - 200, 200 + HW)
    glyf_dict['A'] = pen.glyph()
    metrics_dict['A'] = (W_A + 30, 60)

    # B
    pen = TTGlyphPen(None)
    W_B = 860
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_B - 100, CAP)
    draw_cw_rect(pen, W_B - 100 - SW, CAP//2, W_B - 60, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_B - 100, CAP//2 + HW//2)
    draw_cw_rect(pen, W_B - 100 - SW, 0, W_B - 60, CAP//2)
    draw_cw_rect(pen, 60, 0, W_B - 100, HW)
    glyf_dict['B'] = pen.glyph()
    metrics_dict['B'] = (W_B + 30, 60)

    # C
    pen = TTGlyphPen(None)
    W_C = 860
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_C - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_C - 60, HW)
    draw_cw_rect(pen, W_C - 60 - SW, CAP - HW - 130, W_C - 60, CAP - HW)
    draw_cw_rect(pen, W_C - 60 - SW, HW, W_C - 60, HW + 130)
    glyf_dict['C'] = pen.glyph()
    metrics_dict['C'] = (W_C + 30, 60)

    # D
    pen = TTGlyphPen(None)
    W_D = 880
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_D - 120, CAP)
    draw_cw_rect(pen, W_D - 100 - SW, 100, W_D - 60, CAP - 100)
    draw_cw_rect(pen, 60, 0, W_D - 120, HW)
    pen.moveTo((W_D - 120, CAP))
    pen.lineTo((W_D - 60, CAP - 100))
    pen.lineTo((W_D - 60 - SW, CAP - 100))
    pen.lineTo((W_D - 120, CAP - HW))
    pen.closePath()
    pen.moveTo((W_D - 120, 0))
    pen.lineTo((W_D - 120, HW))
    pen.lineTo((W_D - 60 - SW, 100))
    pen.lineTo((W_D - 60, 100))
    pen.closePath()
    glyf_dict['D'] = pen.glyph()
    metrics_dict['D'] = (W_D + 30, 60)

    # E
    pen = TTGlyphPen(None)
    W_E = 800
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_E - 60, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_E - 160, CAP//2 + HW//2)
    draw_cw_rect(pen, 60, 0, W_E - 60, HW)
    glyf_dict['E'] = pen.glyph()
    metrics_dict['E'] = (W_E + 30, 60)

    # F
    pen = TTGlyphPen(None)
    W_F = 780
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_F - 60, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_F - 160, CAP//2 + HW//2)
    glyf_dict['F'] = pen.glyph()
    metrics_dict['F'] = (W_F + 30, 60)

    # G
    pen = TTGlyphPen(None)
    W_G = 880
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_G - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_G - 60, HW)
    draw_cw_rect(pen, W_G - 60 - SW, 0, W_G - 60, CAP//2)
    draw_cw_rect(pen, W_G//2, CAP//2 - HW, W_G - 60, CAP//2)
    draw_cw_rect(pen, W_G - 60 - SW, CAP - HW - 130, W_G - 60, CAP - HW)
    glyf_dict['G'] = pen.glyph()
    metrics_dict['G'] = (W_G + 30, 60)

    # H
    pen = TTGlyphPen(None)
    W_H = 900
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_H - 60 - SW, 0, W_H - 60, CAP)
    draw_cw_rect(pen, 60 + SW, CAP//2 - HW//2, W_H - 60 - SW, CAP//2 + HW//2)
    glyf_dict['H'] = pen.glyph()
    metrics_dict['H'] = (W_H + 30, 60)

    # I
    pen = TTGlyphPen(None)
    W_I = 340
    draw_cw_rect(pen, W_I//2 - SW//2, 0, W_I//2 + SW//2, CAP)
    glyf_dict['I'] = pen.glyph()
    metrics_dict['I'] = (W_I + 20, 60)

    # J
    pen = TTGlyphPen(None)
    W_J = 660
    draw_cw_rect(pen, W_J - 60 - SW, 100, W_J - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_J - 60, HW)
    draw_cw_rect(pen, 60, 0, 60 + SW, 240)
    glyf_dict['J'] = pen.glyph()
    metrics_dict['J'] = (W_J + 30, 60)

    # K
    pen = TTGlyphPen(None)
    W_K = 880
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    pen.moveTo((60 + SW, CAP//2 - 40))
    pen.lineTo((W_K - 60, CAP))
    pen.lineTo((W_K - 60 + SW, CAP))
    pen.lineTo((60 + SW, CAP//2 - 40 - HW))
    pen.closePath()
    pen.moveTo((W_K//2, CAP//2 - HW//2))
    pen.lineTo((W_K - 60, 0))
    pen.lineTo((W_K - 60 - SW, 0))
    pen.lineTo((W_K//2 - SW//2, CAP//2 - HW//2))
    pen.closePath()
    glyf_dict['K'] = pen.glyph()
    metrics_dict['K'] = (W_K + 30, 60)

    # L
    pen = TTGlyphPen(None)
    W_L = 740
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, 0, W_L - 60, HW)
    glyf_dict['L'] = pen.glyph()
    metrics_dict['L'] = (W_L + 30, 60)

    # M
    pen = TTGlyphPen(None)
    W_M = 1040
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_M - 60 - SW, 0, W_M - 60, CAP)
    pen.moveTo((60 + SW, CAP))
    pen.lineTo((W_M//2, 160))
    pen.lineTo((W_M//2 - SW//2, 160))
    pen.lineTo((60, CAP))
    pen.closePath()
    pen.moveTo((W_M//2, 160))
    pen.lineTo((W_M - 60 - SW, CAP))
    pen.lineTo((W_M - 60, CAP))
    pen.lineTo((W_M//2 + SW//2, 160))
    pen.closePath()
    glyf_dict['M'] = pen.glyph()
    metrics_dict['M'] = (W_M + 40, 60)

    # O
    pen = TTGlyphPen(None)
    W_O = 920
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_O - 60 - SW, 0, W_O - 60, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_O - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_O - 60, HW)
    glyf_dict['O'] = pen.glyph()
    metrics_dict['O'] = (W_O + 30, 60)

    # P
    pen = TTGlyphPen(None)
    W_P = 840
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_P - 60, CAP)
    draw_cw_rect(pen, W_P - 60 - SW, CAP//2, W_P - 60, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_P - 60, CAP//2 + HW//2)
    glyf_dict['P'] = pen.glyph()
    metrics_dict['P'] = (W_P + 30, 60)

    # Q
    pen = TTGlyphPen(None)
    W_Q = 920
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_Q - 60 - SW, 0, W_Q - 60, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_Q - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_Q - 60, HW)
    pen.moveTo((W_Q - 260, 200))
    pen.lineTo((W_Q + 20, -60))
    pen.lineTo((W_Q - 120, -60))
    pen.lineTo((W_Q - 360, 100))
    pen.closePath()
    glyf_dict['Q'] = pen.glyph()
    metrics_dict['Q'] = (W_Q + 40, 60)

    # R
    pen = TTGlyphPen(None)
    W_R = 880
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_R - 80, CAP)
    draw_cw_rect(pen, W_R - 80 - SW, CAP//2, W_R - 60, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_R - 60, CAP//2 + HW//2)
    pen.moveTo((W_R//2 - 20, CAP//2 - HW//2))
    pen.lineTo((W_R - 60, 0))
    pen.lineTo((W_R - 60 - SW, 0))
    pen.lineTo((W_R//2 - 20 - SW//2, CAP//2 - HW//2))
    pen.closePath()
    glyf_dict['R'] = pen.glyph()
    metrics_dict['R'] = (W_R + 30, 60)

    # U
    pen = TTGlyphPen(None)
    W_U = 900
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_U - 60 - SW, 0, W_U - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_U - 60, HW)
    glyf_dict['U'] = pen.glyph()
    metrics_dict['U'] = (W_U + 30, 60)

    # V
    pen = TTGlyphPen(None)
    W_V = 900
    pen.moveTo((60, CAP))
    pen.lineTo((60 + SW, CAP))
    pen.lineTo((W_V//2 + SW//2, 0))
    pen.lineTo((W_V//2, 0))
    pen.closePath()
    pen.moveTo((W_V - 60, CAP))
    pen.lineTo((W_V//2, 0))
    pen.lineTo((W_V//2 - SW//2, 0))
    pen.lineTo((W_V - 60 - SW, CAP))
    pen.closePath()
    glyf_dict['V'] = pen.glyph()
    metrics_dict['V'] = (W_V + 30, 60)

    # W
    pen = TTGlyphPen(None)
    W_W = 1120
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_W - 60 - SW, 0, W_W - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_W - 60, HW)
    draw_cw_rect(pen, W_W//2 - SW//2, 0, W_W//2 + SW//2, CAP - 120)
    glyf_dict['W'] = pen.glyph()
    metrics_dict['W'] = (W_W + 40, 60)

    # X
    pen = TTGlyphPen(None)
    W_X = 860
    pen.moveTo((60, CAP))
    pen.lineTo((60 + SW, CAP))
    pen.lineTo((W_X - 60, 0))
    pen.lineTo((W_X - 60 - SW, 0))
    pen.closePath()
    pen.moveTo((W_X - 60, CAP))
    pen.lineTo((W_X - 60 - SW, CAP))
    pen.lineTo((60, 0))
    pen.lineTo((60 + SW, 0))
    pen.closePath()
    glyf_dict['X'] = pen.glyph()
    metrics_dict['X'] = (W_X + 30, 60)

    # Y
    pen = TTGlyphPen(None)
    W_Y = 860
    pen.moveTo((60, CAP))
    pen.lineTo((60 + SW, CAP))
    pen.lineTo((W_Y//2 + SW//2, CAP//2))
    pen.lineTo((W_Y//2, CAP//2))
    pen.closePath()
    pen.moveTo((W_Y - 60, CAP))
    pen.lineTo((W_Y//2, CAP//2))
    pen.lineTo((W_Y//2 - SW//2, CAP//2))
    pen.lineTo((W_Y - 60 - SW, CAP))
    pen.closePath()
    draw_cw_rect(pen, W_Y//2 - SW//2, 0, W_Y//2 + SW//2, CAP//2)
    glyf_dict['Y'] = pen.glyph()
    metrics_dict['Y'] = (W_Y + 30, 60)

    # Z
    pen = TTGlyphPen(None)
    W_Z = 840
    draw_cw_rect(pen, 60, CAP - HW, W_Z - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_Z - 60, HW)
    pen.moveTo((W_Z - 60, CAP - HW))
    pen.lineTo((60 + SW, HW))
    pen.lineTo((60, HW))
    pen.lineTo((W_Z - 60 - SW, CAP - HW))
    pen.closePath()
    glyf_dict['Z'] = pen.glyph()
    metrics_dict['Z'] = (W_Z + 30, 60)

    # Numbers
    W_NUM = 820
    # zero
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
    draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
    glyf_dict['zero'] = pen.glyph()
    metrics_dict['zero'] = (W_NUM + 30, 60)

    # one
    pen = TTGlyphPen(None)
    W_1 = 500
    draw_cw_rect(pen, W_1//2 - SW//2, 0, W_1//2 + SW//2, CAP)
    pen.moveTo((W_1//2 - SW//2, CAP))
    pen.lineTo((W_1//2 - SW//2, CAP - HW))
    pen.lineTo((W_1//2 - SW//2 - 120, CAP - 120 - HW))
    pen.lineTo((W_1//2 - SW//2 - 120, CAP - 120))
    pen.closePath()
    draw_cw_rect(pen, 60, 0, W_1 - 60, HW)
    glyf_dict['one'] = pen.glyph()
    metrics_dict['one'] = (W_1 + 30, 60)

    # two..nine
    for name in ['two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']:
        pen = TTGlyphPen(None)
        if name == 'two':
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, W_NUM - 60 - SW, CAP//2, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, 60, 0, 60 + SW, CAP//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        elif name == 'three':
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP)
            draw_cw_rect(pen, W_NUM//2, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        elif name == 'four':
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//3, 60 + SW, CAP)
            draw_cw_rect(pen, 60, CAP//3, W_NUM - 60, CAP//3 + HW)
        elif name == 'five':
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//2, 60 + SW, CAP)
            draw_cw_rect(pen, 60, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        elif name == 'six':
            draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        elif name == 'seven':
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            pen.moveTo((W_NUM - 60, CAP - HW))
            pen.lineTo((W_NUM//3, 0))
            pen.lineTo((W_NUM//3 + SW, 0))
            pen.lineTo((W_NUM - 60, CAP))
            pen.closePath()
        elif name == 'eight':
            draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        elif name == 'nine':
            draw_cw_rect(pen, 60, CAP//2, 60 + SW, CAP)
            draw_cw_rect(pen, W_NUM - 60 - SW, 0, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP - HW, W_NUM - 60, CAP)
            draw_cw_rect(pen, 60, CAP//2 - HW//2, W_NUM - 60, CAP//2 + HW//2)
            draw_cw_rect(pen, 60, 0, W_NUM - 60, HW)
        glyf_dict[name] = pen.glyph()
        metrics_dict[name] = (W_NUM + 30, 60)

    # Punctuation
    # period
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, 0, 60 + SW, SW)
    glyf_dict['period'] = pen.glyph()
    metrics_dict['period'] = (SW + 120, 60)

    # comma
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, 0, 60 + SW, SW)
    pen.moveTo((60 + SW, SW))
    pen.lineTo((60 + SW, 0))
    pen.lineTo((60, -80))
    pen.closePath()
    glyf_dict['comma'] = pen.glyph()
    metrics_dict['comma'] = (SW + 120, 60)

    # colon
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, 0, 60 + SW, SW)
    draw_cw_rect(pen, 60, CAP - SW, 60 + SW, CAP)
    glyf_dict['colon'] = pen.glyph()
    metrics_dict['colon'] = (SW + 120, 60)

    # hyphen
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, 440, CAP//2 + HW//2)
    glyf_dict['hyphen'] = pen.glyph()
    metrics_dict['hyphen'] = (500, 60)

    # plus
    pen = TTGlyphPen(None)
    W_PL = 620
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_PL - 60, CAP//2 + HW//2)
    draw_cw_rect(pen, W_PL//2 - SW//2, CAP//2 - 200, W_PL//2 + SW//2, CAP//2 + 200)
    glyf_dict['plus'] = pen.glyph()
    metrics_dict['plus'] = (W_PL + 20, 60)

    # slash
    pen = TTGlyphPen(None)
    W_SL = 500
    pen.moveTo((W_SL - 60, CAP))
    pen.lineTo((W_SL - 60 - SW, CAP))
    pen.lineTo((60, 0))
    pen.lineTo((60 + SW, 0))
    pen.closePath()
    glyf_dict['slash'] = pen.glyph()
    metrics_dict['slash'] = (W_SL + 20, 60)

    # ampersand (&)
    pen = TTGlyphPen(None)
    W_AMP = 820
    draw_cw_rect(pen, 60, 0, 60 + SW, CAP)
    draw_cw_rect(pen, 60, CAP - HW, W_AMP - 120, CAP)
    draw_cw_rect(pen, 60, CAP//2 - HW//2, W_AMP - 120, CAP//2 + HW//2)
    draw_cw_rect(pen, 60, 0, W_AMP - 60, HW)
    pen.moveTo((W_AMP - 140, CAP))
    pen.lineTo((W_AMP - 60, 0))
    pen.lineTo((W_AMP - 60 - SW, 0))
    pen.lineTo((W_AMP - 140 - SW, CAP))
    pen.closePath()
    glyf_dict['ampersand'] = pen.glyph()
    metrics_dict['ampersand'] = (W_AMP + 30, 60)

    # brackets
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, -60, 60 + SW, CAP + 60)
    draw_cw_rect(pen, 60, CAP + 60 - HW, 340, CAP + 60)
    draw_cw_rect(pen, 60, -60, 340, -60 + HW)
    glyf_dict['bracketleft'] = pen.glyph()
    metrics_dict['bracketleft'] = (400, 60)

    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 340 - SW, -60, 340, CAP + 60)
    draw_cw_rect(pen, 60, CAP + 60 - HW, 340, CAP + 60)
    draw_cw_rect(pen, 60, -60, 340, -60 + HW)
    glyf_dict['bracketright'] = pen.glyph()
    metrics_dict['bracketright'] = (400, 60)

    # parens
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 140, -60, 140 + SW, CAP + 60)
    glyf_dict['parenleft'] = pen.glyph()
    metrics_dict['parenleft'] = (340, 60)

    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, -60, 60 + SW, CAP + 60)
    glyf_dict['parenright'] = pen.glyph()
    metrics_dict['parenright'] = (340, 60)

    # exclam
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 80, 220, 80 + SW, CAP)
    draw_cw_rect(pen, 80, 0, 80 + SW, SW)
    glyf_dict['exclam'] = pen.glyph()
    metrics_dict['exclam'] = (SW + 160, 80)

    # periodcentered (·)
    pen = TTGlyphPen(None)
    draw_cw_rect(pen, 60, CAP//2 - SW//2, 60 + SW, CAP//2 + SW//2)
    glyf_dict['periodcentered'] = pen.glyph()
    metrics_dict['periodcentered'] = (SW + 120, 60)

    # Assemble tables
    fb.setupGlyf(glyf_dict)
    fb.setupHorizontalMetrics(metrics_dict)
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
    
    name_strings = dict(
        familyName="NNTS Display",
        styleName="Black",
        uniqueFontIdentifier="1.000;ALMOSTELEVEN;NNTSDisplay-Black",
        fullName="NNTS Display Black",
        version="Version 1.000",
        psName="NNTSDisplay-Black",
        manufacturer="Almost Eleven / NNTS",
        designer="NNTS Design Lab",
        description="Proprietary Neo-Brutalist Ultra-Heavy Display Typeface derived from canonical NNTS wordmark geometry."
    )
    fb.setupNameTable(name_strings)
    
    fb.setupOS2(
        sTypoAscender=ASC,
        sTypoDescender=DESC,
        sTypoLineGap=100,
        usWeightClass=950,
        usWidthClass=8,
        sxHeight=520,
        sCapHeight=CAP
    )
    fb.setupPost()
    fb.save(output_path)
    print(f"Compiled custom font: {output_path}")

if __name__ == '__main__':
    build_nnts_display_font()
