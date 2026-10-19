import os
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

def create_japanese_tech_font(output_path="assets/fonts/NNTSNeoTokyo-Black.ttf"):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    UPM = 1000
    CAP = 720
    ASC = 800
    DESC = -200
    XH = 480   # x-height for lowercase
    SW = 160   # Stem width (vertical)
    HW = 130   # Horizontal bar thickness
    CH = 60    # 45-degree chamfer size (for mecha corners)
    
    # Lowercase specific thicknesses
    SW_LC = 135
    HW_LC = 110
    CH_LC = 45

    fb = FontBuilder(UPM, isTTF=True)
    
    # All uppercase, lowercase, digits, symbols
    uc_letters = [chr(c) for c in range(ord('A'), ord('Z')+1)]
    lc_letters = [chr(c) for c in range(ord('a'), ord('z')+1)]
    num_names = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
    punct_names = [
        'period', 'comma', 'colon', 'hyphen', 'plus', 'slash', 'bracketleft', 'bracketright',
        'parenleft', 'parenright', 'exclam', 'periodcentered', 'ampersand'
    ]
    
    glyph_names = ['.notdef', 'space'] + uc_letters + lc_letters + num_names + punct_names
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
    for char in uc_letters:
        cmap[ord(char)] = char
    for char in lc_letters:
        cmap[ord(char)] = char
    for i, name in enumerate(num_names):
        cmap[ord(str(i))] = name
        
    fb.setupCharacterMap(cmap)
    
    glyf_dict = {}
    metrics_dict = {}
    
    def draw_polygon_cw(pen, points):
        pen.moveTo(points[0])
        for p in points[1:]:
            pen.lineTo(p)
        pen.closePath()

    def draw_polygon_ccw(pen, points):
        pen.moveTo(points[0])
        for p in points[1:]:
            pen.lineTo(p)
        pen.closePath()

    # .notdef
    pen = TTGlyphPen(None)
    draw_polygon_cw(pen, [(100, 0), (100, CAP), (700, CAP), (700, 0)])
    draw_polygon_ccw(pen, [(100 + SW, SW), (700 - SW, SW), (700 - SW, CAP - SW), (100 + SW, CAP - SW)])
    glyf_dict['.notdef'] = pen.glyph()
    metrics_dict['.notdef'] = (800, 100)
    
    # space
    pen = TTGlyphPen(None)
    glyf_dict['space'] = pen.glyph()
    metrics_dict['space'] = (360, 0)

    # =========================================================================
    # UPPERCASE GLYPHS (CHAMFERED MECHA / KATANA BLADE GEOMETRY)
    # =========================================================================

    # N
    pen = TTGlyphPen(None)
    W_N = 920
    draw_polygon_cw(pen, [(60, 0), (60, CAP - CH), (60 + CH, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(W_N - 60 - SW, 0), (W_N - 60 - SW, CAP), (W_N - 60, CAP), (W_N - 60, CH), (W_N - 60 - CH, 0)])
    pen.moveTo((60, CAP))
    pen.lineTo((60 + SW + 80, CAP))
    pen.lineTo((W_N - 60, 0))
    pen.lineTo((W_N - 60 - SW - 80, 0))
    pen.closePath()
    glyf_dict['N'] = pen.glyph()
    metrics_dict['N'] = (W_N + 30, 60)

    # T
    pen = TTGlyphPen(None)
    W_T = 860
    draw_polygon_cw(pen, [(50, CAP - HW + CH), (50 + CH, CAP), (W_T - 50 - CH, CAP), (W_T - 50, CAP - HW + CH), (W_T - 50 - CH, CAP - HW), (50 + CH, CAP - HW)])
    cx = W_T // 2
    draw_polygon_cw(pen, [(cx - SW//2, 0), (cx - SW//2, CAP - HW), (cx + SW//2, CAP - HW), (cx + SW//2, 0)])
    glyf_dict['T'] = pen.glyph()
    metrics_dict['T'] = (W_T + 30, 50)

    # S
    pen = TTGlyphPen(None)
    W_S = 880
    draw_polygon_cw(pen, [
        (60 + CH, CAP), (W_S - 60 - CH, CAP), (W_S - 60, CAP - CH), (W_S - 60, CAP - HW - 90),
        (W_S - 60 - SW, CAP - HW - 90), (W_S - 60 - SW, CAP - HW), (60 + SW + CH, CAP - HW),
        (60 + SW, CAP - HW - CH), (60 + SW, CAP//2 + HW//2), (W_S - 60 - CH, CAP//2 + HW//2),
        (W_S - 60, CAP//2 + HW//2 - CH), (W_S - 60, CH), (W_S - 60 - CH, 0), (60 + CH, 0),
        (60, CH), (60, HW + 90), (60 + SW, HW + 90), (60 + SW, HW),
        (W_S - 60 - SW - CH, HW), (W_S - 60 - SW, HW + CH), (W_S - 60 - SW, CAP//2 - HW//2),
        (60 + CH, CAP//2 - HW//2), (60, CAP//2 - HW//2 + CH), (60, CAP - CH)
    ])
    glyf_dict['S'] = pen.glyph()
    metrics_dict['S'] = (W_S + 30, 60)

    # O
    pen = TTGlyphPen(None)
    W_O = 940
    draw_polygon_cw(pen, [(60 + CH, CAP), (W_O - 60 - CH, CAP), (W_O - 60, CAP - CH), (W_O - 60, CH), (W_O - 60 - CH, 0), (60 + CH, 0), (60, CH), (60, CAP - CH)])
    draw_polygon_ccw(pen, [(60 + SW + CH, CAP - HW), (60 + SW, CAP - HW - CH), (60 + SW, HW + CH), (60 + SW + CH, HW), (W_O - 60 - SW - CH, HW), (W_O - 60 - SW, HW + CH), (W_O - 60 - SW, CAP - HW - CH), (W_O - 60 - SW - CH, CAP - HW)])
    glyf_dict['O'] = pen.glyph()
    metrics_dict['O'] = (W_O + 30, 60)

    # A
    pen = TTGlyphPen(None)
    W_A = 940
    draw_polygon_cw(pen, [(50, 0), (50, CH), (W_A//2 - SW//2, CAP), (W_A//2 + SW//2, CAP), (50 + SW + 50, 0)])
    draw_polygon_cw(pen, [(W_A - 50 - SW - 50, 0), (W_A//2 - SW//2, CAP), (W_A//2 + SW//2, CAP), (W_A - 50, CH), (W_A - 50, 0)])
    draw_polygon_cw(pen, [(220, 200), (220, 200 + HW), (W_A - 220, 200 + HW), (W_A - 220, 200)])
    glyf_dict['A'] = pen.glyph()
    metrics_dict['A'] = (W_A + 30, 50)

    # P
    pen = TTGlyphPen(None)
    W_P = 860
    draw_polygon_cw(pen, [(60, 0), (60, CAP - CH), (60 + CH, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(60 + SW, CAP), (W_P - 60 - CH, CAP), (W_P - 60, CAP - CH), (W_P - 60, CAP//2 + CH), (W_P - 60 - CH, CAP//2), (60 + SW, CAP//2)])
    draw_polygon_ccw(pen, [(60 + SW, CAP - HW), (60 + SW, CAP//2 + HW), (W_P - 60 - SW - 20, CAP//2 + HW), (W_P - 60 - SW, CAP//2 + HW + 20), (W_P - 60 - SW, CAP - HW - 20), (W_P - 60 - SW - 20, CAP - HW)])
    glyf_dict['P'] = pen.glyph()
    metrics_dict['P'] = (W_P + 30, 60)

    # R
    pen = TTGlyphPen(None)
    W_R = 900
    draw_polygon_cw(pen, [(60, 0), (60, CAP - CH), (60 + CH, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(60 + SW, CAP), (W_R - 80 - CH, CAP), (W_R - 80, CAP - CH), (W_R - 80, CAP//2 + CH), (W_R - 80 - CH, CAP//2), (60 + SW, CAP//2)])
    draw_polygon_ccw(pen, [(60 + SW, CAP - HW), (60 + SW, CAP//2 + HW), (W_R - 80 - SW - 20, CAP//2 + HW), (W_R - 80 - SW, CAP//2 + HW + 20), (W_R - 80 - SW, CAP - HW - 20), (W_R - 80 - SW - 20, CAP - HW)])
    draw_polygon_cw(pen, [(W_R - 80 - SW, CAP//2 - 20), (W_R - 80, CAP//2 - 20), (W_R - 60, CH), (W_R - 60 - CH, 0), (W_R - 60 - SW - 80, 0)])
    glyf_dict['R'] = pen.glyph()
    metrics_dict['R'] = (W_R + 30, 60)

    # C
    pen = TTGlyphPen(None)
    W_C = 900
    draw_polygon_cw(pen, [
        (W_C - 60, CAP - HW), (W_C - 60 - CH, CAP), (60 + CH, CAP), (60, CAP - CH), (60, CH),
        (60 + CH, 0), (W_C - 60 - CH, 0), (W_C - 60, HW), (W_C - 60 - SW, HW), (W_C - 60 - SW - CH, HW),
        (60 + SW, HW + CH), (60 + SW, CAP - HW - CH), (W_C - 60 - SW - CH, CAP - HW), (W_C - 60 - SW, CAP - HW)
    ])
    glyf_dict['C'] = pen.glyph()
    metrics_dict['C'] = (W_C + 30, 60)

    # E
    pen = TTGlyphPen(None)
    W_E = 840
    draw_polygon_cw(pen, [
        (60, 0), (60, CAP - CH), (60 + CH, CAP), (W_E - 60 - CH, CAP), (W_E - 60, CAP - CH), (W_E - 60, CAP - HW),
        (60 + SW, CAP - HW), (60 + SW, CAP//2 + HW//2), (W_E - 100, CAP//2 + HW//2), (W_E - 100, CAP//2 - HW//2),
        (60 + SW, CAP//2 - HW//2), (60 + SW, HW), (W_E - 60, HW), (W_E - 60, CH), (W_E - 60 - CH, 0)
    ])
    glyf_dict['E'] = pen.glyph()
    metrics_dict['E'] = (W_E + 30, 60)

    # L
    pen = TTGlyphPen(None)
    W_L = 780
    draw_polygon_cw(pen, [(60, 0), (60, CAP - CH), (60 + CH, CAP), (60 + SW, CAP), (60 + SW, HW), (W_L - 60, HW), (W_L - 60, CH), (W_L - 60 - CH, 0)])
    glyf_dict['L'] = pen.glyph()
    metrics_dict['L'] = (W_L + 30, 60)

    # I
    pen = TTGlyphPen(None)
    W_I = 360
    draw_polygon_cw(pen, [(W_I//2 - SW//2, 0), (W_I//2 - SW//2, CAP - CH), (W_I//2 - SW//2 + CH, CAP), (W_I//2 + SW//2, CAP), (W_I//2 + SW//2, 0)])
    glyf_dict['I'] = pen.glyph()
    metrics_dict['I'] = (W_I + 20, W_I//2 - SW//2)

    # F
    pen = TTGlyphPen(None)
    W_F = 820
    draw_polygon_cw(pen, [(60, 0), (60, CAP - CH), (60 + CH, CAP), (W_F - 60 - CH, CAP), (W_F - 60, CAP - CH), (W_F - 60, CAP - HW), (60 + SW, CAP - HW), (60 + SW, CAP//2 + HW//2), (W_F - 100, CAP//2 + HW//2), (W_F - 100, CAP//2 - HW//2), (60 + SW, CAP//2 - HW//2), (60 + SW, 0)])
    glyf_dict['F'] = pen.glyph()
    metrics_dict['F'] = (W_F + 30, 60)

    # M & W
    pen = TTGlyphPen(None)
    W_M = 1040
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(W_M - 60 - SW, 0), (W_M - 60 - SW, CAP), (W_M - 60, CAP), (W_M - 60, 0)])
    pen.moveTo((60 + SW, CAP))
    pen.lineTo((W_M//2, 180))
    pen.lineTo((W_M - 60 - SW, CAP))
    pen.lineTo((W_M - 60 - SW - 100, CAP))
    pen.lineTo((W_M//2, 340))
    pen.lineTo((60 + SW + 100, CAP))
    pen.closePath()
    glyf_dict['M'] = pen.glyph()
    metrics_dict['M'] = (W_M + 30, 60)

    pen = TTGlyphPen(None)
    W_W = 1040
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(W_W - 60 - SW, 0), (W_W - 60 - SW, CAP), (W_W - 60, CAP), (W_W - 60, 0)])
    pen.moveTo((60 + SW, 0))
    pen.lineTo((W_W//2, CAP - 180))
    pen.lineTo((W_W - 60 - SW, 0))
    pen.lineTo((W_W - 60 - SW - 100, 0))
    pen.lineTo((W_W//2, CAP - 340))
    pen.lineTo((60 + SW + 100, 0))
    pen.closePath()
    glyf_dict['W'] = pen.glyph()
    metrics_dict['W'] = (W_W + 30, 60)

    # H & U
    pen = TTGlyphPen(None)
    W_H = 880
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(W_H - 60 - SW, 0), (W_H - 60 - SW, CAP), (W_H - 60, CAP), (W_H - 60, 0)])
    draw_polygon_cw(pen, [(60 + SW, CAP//2 - HW//2), (60 + SW, CAP//2 + HW//2), (W_H - 60 - SW, CAP//2 + HW//2), (W_H - 60 - SW, CAP//2 - HW//2)])
    glyf_dict['H'] = pen.glyph()
    metrics_dict['H'] = (W_H + 30, 60)

    pen = TTGlyphPen(None)
    W_U = 900
    draw_polygon_cw(pen, [(60, CAP), (60 + SW, CAP), (60 + SW, HW + CH), (60 + SW + CH, HW), (W_U - 60 - SW - CH, HW), (W_U - 60 - SW, HW + CH), (W_U - 60 - SW, CAP), (W_U - 60, CAP), (W_U - 60, CH), (W_U - 60 - CH, 0), (60 + CH, 0), (60, CH)])
    glyf_dict['U'] = pen.glyph()
    metrics_dict['U'] = (W_U + 30, 60)

    # Remaining uppercase (B, D, G, J, K, Q, V, X, Y, Z)
    pen = TTGlyphPen(None)
    W_B = 880
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(60 + SW, CAP), (W_B - 60 - CH, CAP), (W_B - 60, CAP - CH), (W_B - 60, CAP//2 + CH), (W_B - 60 - CH, CAP//2), (60 + SW, CAP//2)])
    draw_polygon_ccw(pen, [(60 + SW, CAP - HW), (60 + SW, CAP//2 + HW//2), (W_B - 60 - SW - 10, CAP//2 + HW//2), (W_B - 60 - SW, CAP//2 + HW//2 + 10), (W_B - 60 - SW, CAP - HW - 10), (W_B - 60 - SW - 10, CAP - HW)])
    draw_polygon_cw(pen, [(60 + SW, CAP//2), (W_B - 60 - CH, CAP//2), (W_B - 60, CAP//2 - CH), (W_B - 60, CH), (W_B - 60 - CH, 0), (60 + SW, 0)])
    draw_polygon_ccw(pen, [(60 + SW, CAP//2 - HW//2), (60 + SW, HW), (W_B - 60 - SW - 10, HW), (W_B - 60 - SW, HW + 10), (W_B - 60 - SW, CAP//2 - HW//2 - 10), (W_B - 60 - SW - 10, CAP//2 - HW//2)])
    glyf_dict['B'] = pen.glyph()
    metrics_dict['B'] = (W_B + 30, 60)

    pen = TTGlyphPen(None)
    W_D = 900
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    draw_polygon_cw(pen, [(60 + SW, CAP), (W_D - 60 - CH*2, CAP), (W_D - 60, CAP - CH*2), (W_D - 60, CH*2), (W_D - 60 - CH*2, 0), (60 + SW, 0)])
    draw_polygon_ccw(pen, [(60 + SW, CAP - HW), (60 + SW, HW), (W_D - 60 - SW - CH, HW), (W_D - 60 - SW, HW + CH), (W_D - 60 - SW, CAP - HW - CH), (W_D - 60 - SW - CH, CAP - HW)])
    glyf_dict['D'] = pen.glyph()
    metrics_dict['D'] = (W_D + 30, 60)

    pen = TTGlyphPen(None)
    W_G = 920
    draw_polygon_cw(pen, [(W_G - 60, CAP - HW), (W_G - 60 - CH, CAP), (60 + CH, CAP), (60, CAP - CH), (60, CH), (60 + CH, 0), (W_G - 60 - CH, 0), (W_G - 60, CH), (W_G - 60, CAP//2), (W_G//2, CAP//2), (W_G//2, CAP//2 - HW), (W_G - 60 - SW, CAP//2 - HW), (W_G - 60 - SW, HW), (60 + SW + CH, HW), (60 + SW, HW + CH), (60 + SW, CAP - HW - CH), (60 + SW + CH, CAP - HW), (W_G - 60 - SW, CAP - HW)])
    glyf_dict['G'] = pen.glyph()
    metrics_dict['G'] = (W_G + 30, 60)

    pen = TTGlyphPen(None)
    W_J = 740
    draw_polygon_cw(pen, [(W_J - 60 - SW, CAP), (W_J - 60, CAP), (W_J - 60, CH), (W_J - 60 - CH, 0), (60 + CH, 0), (60, CH), (60, HW + 90), (60 + SW, HW + 90), (60 + SW, HW), (W_J - 60 - SW - CH, HW), (W_J - 60 - SW, HW + CH)])
    glyf_dict['J'] = pen.glyph()
    metrics_dict['J'] = (W_J + 30, 60)

    pen = TTGlyphPen(None)
    W_K = 860
    draw_polygon_cw(pen, [(60, 0), (60, CAP), (60 + SW, CAP), (60 + SW, 0)])
    pen.moveTo((60 + SW + 50, CAP//2))
    pen.lineTo((W_K - 60 - SW, CAP))
    pen.lineTo((W_K - 60, CAP))
    pen.lineTo((W_K - 60, CAP - CH))
    pen.lineTo((60 + SW + 140, CAP//2 - 40))
    pen.closePath()
    pen.moveTo((60 + SW + 140, CAP//2))
    pen.lineTo((W_K - 60, 0))
    pen.lineTo((W_K - 60 - SW - 30, 0))
    pen.lineTo((60 + SW + 50, CAP//2 - 60))
    pen.closePath()
    glyf_dict['K'] = pen.glyph()
    metrics_dict['K'] = (W_K + 30, 60)

    pen = TTGlyphPen(None)
    W_Q = 940
    draw_polygon_cw(pen, [(60 + CH, CAP), (W_Q - 60 - CH, CAP), (W_Q - 60, CAP - CH), (W_Q - 60, CH), (W_Q - 60 - CH, 0), (60 + CH, 0), (60, CH), (60, CAP - CH)])
    draw_polygon_ccw(pen, [(60 + SW + CH, CAP - HW), (60 + SW, CAP - HW - CH), (60 + SW, HW + CH), (60 + SW + CH, HW), (W_Q - 60 - SW - CH, HW), (W_Q - 60 - SW, HW + CH), (W_Q - 60 - SW, CAP - HW - CH), (W_Q - 60 - SW - CH, CAP - HW)])
    draw_polygon_cw(pen, [(W_Q//2, HW + 20), (W_Q - 30, -50), (W_Q - 30 - SW, -50), (W_Q//2 - 80, HW + 20)])
    glyf_dict['Q'] = pen.glyph()
    metrics_dict['Q'] = (W_Q + 30, 60)

    pen = TTGlyphPen(None)
    W_V = 920
    draw_polygon_cw(pen, [(50, CAP), (50 + SW + 30, CAP), (W_V//2 + SW//2, 0), (W_V//2 - SW//2, 0)])
    draw_polygon_cw(pen, [(W_V - 50 - SW - 30, CAP), (W_V - 50, CAP), (W_V//2 + SW//2, 0), (W_V//2 - SW//2, 0)])
    glyf_dict['V'] = pen.glyph()
    metrics_dict['V'] = (W_V + 30, 50)

    pen = TTGlyphPen(None)
    W_X = 880
    draw_polygon_cw(pen, [(50, CAP), (50 + SW + 50, CAP), (W_X - 50, 0), (W_X - 50 - SW - 50, 0)])
    draw_polygon_cw(pen, [(W_X - 50 - SW - 50, CAP), (W_X - 50, CAP), (50 + SW + 50, 0), (50, 0)])
    glyf_dict['X'] = pen.glyph()
    metrics_dict['X'] = (W_X + 30, 50)

    pen = TTGlyphPen(None)
    W_Y = 880
    draw_polygon_cw(pen, [(50, CAP), (50 + SW + 30, CAP), (W_Y//2 + SW//2, CAP//2), (W_Y//2 - SW//2, CAP//2)])
    draw_polygon_cw(pen, [(W_Y - 50 - SW - 30, CAP), (W_Y - 50, CAP), (W_Y//2 + SW//2, CAP//2), (W_Y//2 - SW//2, CAP//2)])
    draw_polygon_cw(pen, [(W_Y//2 - SW//2, 0), (W_Y//2 - SW//2, CAP//2), (W_Y//2 + SW//2, CAP//2), (W_Y//2 + SW//2, 0)])
    glyf_dict['Y'] = pen.glyph()
    metrics_dict['Y'] = (W_Y + 30, 50)

    pen = TTGlyphPen(None)
    W_Z = 860
    draw_polygon_cw(pen, [(60, CAP - HW), (60 + CH, CAP), (W_Z - 60, CAP), (W_Z - 60, CAP - HW), (60 + SW + 80, HW), (W_Z - 60, HW), (W_Z - 60, 0), (60, 0), (60, HW), (W_Z - 60 - SW - 80, CAP - HW)])
    glyf_dict['Z'] = pen.glyph()
    metrics_dict['Z'] = (W_Z + 30, 60)

    # =========================================================================
    # LOWERCASE GLYPHS (AUTHENTIC JAPANESE TECH LOWERCASE FOR CAPS LOCK)
    # =========================================================================
    
    # c
    pen = TTGlyphPen(None)
    w_c = 720
    draw_polygon_cw(pen, [
        (w_c - 50, XH - HW_LC), (w_c - 50 - CH_LC, XH), (50 + CH_LC, XH), (50, XH - CH_LC), (50, CH_LC),
        (50 + CH_LC, 0), (w_c - 50 - CH_LC, 0), (w_c - 50, HW_LC), (w_c - 50 - SW_LC, HW_LC),
        (w_c - 50 - SW_LC - CH_LC, HW_LC), (50 + SW_LC, HW_LC + CH_LC), (50 + SW_LC, XH - HW_LC - CH_LC),
        (w_c - 50 - SW_LC - CH_LC, XH - HW_LC), (w_c - 50 - SW_LC, XH - HW_LC)
    ])
    glyf_dict['c'] = pen.glyph()
    metrics_dict['c'] = (w_c + 20, 50)

    # a
    pen = TTGlyphPen(None)
    w_a = 760
    # outer loop
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_a - 50 - CH_LC, XH), (w_a - 50, XH - CH_LC), (w_a - 50, 0), (50 + CH_LC, 0), (50, CH_LC), (50, XH - CH_LC)])
    # inner hole
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_a - 50 - SW_LC, HW_LC), (w_a - 50 - SW_LC, XH - HW_LC)])
    glyf_dict['a'] = pen.glyph()
    metrics_dict['a'] = (w_a + 20, 50)

    # p
    pen = TTGlyphPen(None)
    w_p = 740
    draw_polygon_cw(pen, [(50, -180), (50, XH - CH_LC), (50 + CH_LC, XH), (50 + SW_LC, XH), (50 + SW_LC, -180)])
    draw_polygon_cw(pen, [(50 + SW_LC, XH), (w_p - 50 - CH_LC, XH), (w_p - 50, XH - CH_LC), (w_p - 50, CH_LC), (w_p - 50 - CH_LC, 0), (50 + SW_LC, 0)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_p - 50 - SW_LC, HW_LC), (w_p - 50 - SW_LC, XH - HW_LC)])
    glyf_dict['p'] = pen.glyph()
    metrics_dict['p'] = (w_p + 20, 50)

    # s
    pen = TTGlyphPen(None)
    w_s = 720
    draw_polygon_cw(pen, [
        (50 + CH_LC, XH), (w_s - 50 - CH_LC, XH), (w_s - 50, XH - CH_LC), (w_s - 50, XH - HW_LC - 50),
        (w_s - 50 - SW_LC, XH - HW_LC - 50), (w_s - 50 - SW_LC, XH - HW_LC), (50 + SW_LC + CH_LC, XH - HW_LC),
        (50 + SW_LC, XH - HW_LC - CH_LC), (50 + SW_LC, XH//2 + HW_LC//2), (w_s - 50 - CH_LC, XH//2 + HW_LC//2),
        (w_s - 50, XH//2 + HW_LC//2 - CH_LC), (w_s - 50, CH_LC), (w_s - 50 - CH_LC, 0), (50 + CH_LC, 0),
        (50, CH_LC), (50, HW_LC + 50), (50 + SW_LC, HW_LC + 50), (50 + SW_LC, HW_LC),
        (w_s - 50 - SW_LC - CH_LC, HW_LC), (w_s - 50 - SW_LC, HW_LC + CH_LC), (w_s - 50 - SW_LC, XH//2 - HW_LC//2),
        (50 + CH_LC, XH//2 - HW_LC//2), (50, XH//2 - HW_LC//2 + CH_LC), (50, XH - CH_LC)
    ])
    glyf_dict['s'] = pen.glyph()
    metrics_dict['s'] = (w_s + 20, 50)

    # l
    pen = TTGlyphPen(None)
    w_l = 320
    draw_polygon_cw(pen, [(w_l//2 - SW_LC//2, 0), (w_l//2 - SW_LC//2, CAP - CH_LC), (w_l//2 - SW_LC//2 + CH_LC, CAP), (w_l//2 + SW_LC//2, CAP), (w_l//2 + SW_LC//2, 0)])
    glyf_dict['l'] = pen.glyph()
    metrics_dict['l'] = (w_l + 20, w_l//2 - SW_LC//2)

    # o
    pen = TTGlyphPen(None)
    w_o = 760
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_o - 50 - CH_LC, XH), (w_o - 50, XH - CH_LC), (w_o - 50, CH_LC), (w_o - 50 - CH_LC, 0), (50 + CH_LC, 0), (50, CH_LC), (50, XH - CH_LC)])
    draw_polygon_ccw(pen, [(50 + SW_LC + CH_LC, XH - HW_LC), (50 + SW_LC, XH - HW_LC - CH_LC), (50 + SW_LC, HW_LC + CH_LC), (50 + SW_LC + CH_LC, HW_LC), (w_o - 50 - SW_LC - CH_LC, HW_LC), (w_o - 50 - SW_LC, HW_LC + CH_LC), (w_o - 50 - SW_LC, XH - HW_LC - CH_LC), (w_o - 50 - SW_LC - CH_LC, XH - HW_LC)])
    glyf_dict['o'] = pen.glyph()
    metrics_dict['o'] = (w_o + 20, 50)

    # k
    pen = TTGlyphPen(None)
    w_k = 720
    draw_polygon_cw(pen, [(50, 0), (50, CAP), (50 + SW_LC, CAP), (50 + SW_LC, 0)])
    pen.moveTo((50 + SW_LC + 30, XH//2))
    pen.lineTo((w_k - 50 - SW_LC, XH))
    pen.lineTo((w_k - 50, XH))
    pen.lineTo((w_k - 50, XH - CH_LC))
    pen.lineTo((50 + SW_LC + 100, XH//2 - 30))
    pen.closePath()
    pen.moveTo((50 + SW_LC + 100, XH//2))
    pen.lineTo((w_k - 50, 0))
    pen.lineTo((w_k - 50 - SW_LC, 0))
    pen.lineTo((50 + SW_LC + 30, XH//2 - 40))
    pen.closePath()
    glyf_dict['k'] = pen.glyph()
    metrics_dict['k'] = (w_k + 20, 50)

    # b, d, e, f, g, h, i, j, m, n, q, r, t, u, v, w, x, y, z
    # b
    pen = TTGlyphPen(None)
    w_b = 740
    draw_polygon_cw(pen, [(50, 0), (50, CAP), (50 + SW_LC, CAP), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(50 + SW_LC, XH), (w_b - 50 - CH_LC, XH), (w_b - 50, XH - CH_LC), (w_b - 50, CH_LC), (w_b - 50 - CH_LC, 0), (50 + SW_LC, 0)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_b - 50 - SW_LC, HW_LC), (w_b - 50 - SW_LC, XH - HW_LC)])
    glyf_dict['b'] = pen.glyph()
    metrics_dict['b'] = (w_b + 20, 50)

    # d
    pen = TTGlyphPen(None)
    w_d = 740
    draw_polygon_cw(pen, [(w_d - 50 - SW_LC, 0), (w_d - 50 - SW_LC, CAP), (w_d - 50, CAP), (w_d - 50, 0)])
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_d - 50 - SW_LC, XH), (w_d - 50 - SW_LC, 0), (50 + CH_LC, 0), (50, CH_LC), (50, XH - CH_LC)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_d - 50 - SW_LC, HW_LC), (w_d - 50 - SW_LC, XH - HW_LC)])
    glyf_dict['d'] = pen.glyph()
    metrics_dict['d'] = (w_d + 20, 50)

    # e
    pen = TTGlyphPen(None)
    w_e = 740
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_e - 50 - CH_LC, XH), (w_e - 50, XH - CH_LC), (w_e - 50, XH//2 - HW_LC//2), (50, XH//2 - HW_LC//2), (50, CH_LC), (50 + CH_LC, 0), (w_e - 50, 0), (w_e - 50, HW_LC), (50 + SW_LC, HW_LC), (50 + SW_LC, XH//2 + HW_LC//2), (w_e - 50, XH//2 + HW_LC//2), (w_e - 50, XH - CH_LC)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, XH//2 + HW_LC//2), (w_e - 50 - SW_LC, XH//2 + HW_LC//2), (w_e - 50 - SW_LC, XH - HW_LC)])
    glyf_dict['e'] = pen.glyph()
    metrics_dict['e'] = (w_e + 20, 50)

    # f
    pen = TTGlyphPen(None)
    w_f = 500
    draw_polygon_cw(pen, [(50, 0), (50, CAP - CH_LC), (50 + CH_LC, CAP), (w_f - 50, CAP), (w_f - 50, CAP - HW_LC), (50 + SW_LC, CAP - HW_LC), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(20, XH), (w_f - 20, XH), (w_f - 20, XH - HW_LC), (20, XH - HW_LC)])
    glyf_dict['f'] = pen.glyph()
    metrics_dict['f'] = (w_f + 20, 50)

    # g
    pen = TTGlyphPen(None)
    w_g = 740
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_g - 50 - SW_LC, XH), (w_g - 50 - SW_LC, 0), (50 + CH_LC, 0), (50, CH_LC), (50, XH - CH_LC)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_g - 50 - SW_LC, HW_LC), (w_g - 50 - SW_LC, XH - HW_LC)])
    draw_polygon_cw(pen, [(w_g - 50 - SW_LC, -180 + HW_LC), (w_g - 50, -180 + HW_LC), (w_g - 50, XH), (w_g - 50 - SW_LC, XH)])
    draw_polygon_cw(pen, [(50, -180), (w_g - 50, -180), (w_g - 50, -180 + HW_LC), (50, -180 + HW_LC)])
    glyf_dict['g'] = pen.glyph()
    metrics_dict['g'] = (w_g + 20, 50)

    # h
    pen = TTGlyphPen(None)
    w_h = 740
    draw_polygon_cw(pen, [(50, 0), (50, CAP), (50 + SW_LC, CAP), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(50 + SW_LC, XH), (w_h - 50 - CH_LC, XH), (w_h - 50, XH - CH_LC), (w_h - 50, 0), (w_h - 50 - SW_LC, 0), (w_h - 50 - SW_LC, XH - HW_LC), (50 + SW_LC, XH - HW_LC)])
    glyf_dict['h'] = pen.glyph()
    metrics_dict['h'] = (w_h + 20, 50)

    # i
    pen = TTGlyphPen(None)
    w_i = 300
    draw_polygon_cw(pen, [(w_i//2 - SW_LC//2, 0), (w_i//2 - SW_LC//2, XH), (w_i//2 + SW_LC//2, XH), (w_i//2 + SW_LC//2, 0)])
    draw_polygon_cw(pen, [(w_i//2 - SW_LC//2, CAP - SW_LC), (w_i//2 - SW_LC//2, CAP), (w_i//2 + SW_LC//2, CAP), (w_i//2 + SW_LC//2, CAP - SW_LC)])
    glyf_dict['i'] = pen.glyph()
    metrics_dict['i'] = (w_i + 20, w_i//2 - SW_LC//2)

    # j
    pen = TTGlyphPen(None)
    w_j = 420
    draw_polygon_cw(pen, [(w_j - 50 - SW_LC, -180), (w_j - 50, -180), (w_j - 50, XH), (w_j - 50 - SW_LC, XH)])
    draw_polygon_cw(pen, [(50, -180), (w_j - 50, -180), (w_j - 50, -180 + HW_LC), (50, -180 + HW_LC)])
    draw_polygon_cw(pen, [(w_j - 50 - SW_LC, CAP - SW_LC), (w_j - 50 - SW_LC, CAP), (w_j - 50, CAP), (w_j - 50, CAP - SW_LC)])
    glyf_dict['j'] = pen.glyph()
    metrics_dict['j'] = (w_j + 20, 50)

    # m
    pen = TTGlyphPen(None)
    w_m = 980
    draw_polygon_cw(pen, [(50, 0), (50, XH), (50 + SW_LC, XH), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(w_m//2 - SW_LC//2, 0), (w_m//2 - SW_LC//2, XH), (w_m//2 + SW_LC//2, XH), (w_m//2 + SW_LC//2, 0)])
    draw_polygon_cw(pen, [(w_m - 50 - SW_LC, 0), (w_m - 50 - SW_LC, XH), (w_m - 50, XH), (w_m - 50, 0)])
    draw_polygon_cw(pen, [(50, XH), (w_m - 50, XH), (w_m - 50, XH - HW_LC), (50, XH - HW_LC)])
    glyf_dict['m'] = pen.glyph()
    metrics_dict['m'] = (w_m + 20, 50)

    # n
    pen = TTGlyphPen(None)
    w_n = 740
    draw_polygon_cw(pen, [(50, 0), (50, XH), (50 + SW_LC, XH), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(w_n - 50 - SW_LC, 0), (w_n - 50 - SW_LC, XH), (w_n - 50, XH), (w_n - 50, 0)])
    draw_polygon_cw(pen, [(50, XH), (w_n - 50, XH), (w_n - 50, XH - HW_LC), (50, XH - HW_LC)])
    glyf_dict['n'] = pen.glyph()
    metrics_dict['n'] = (w_n + 20, 50)

    # q
    pen = TTGlyphPen(None)
    w_q = 740
    draw_polygon_cw(pen, [(50 + CH_LC, XH), (w_q - 50 - SW_LC, XH), (w_q - 50 - SW_LC, 0), (50 + CH_LC, 0), (50, CH_LC), (50, XH - CH_LC)])
    draw_polygon_ccw(pen, [(50 + SW_LC, XH - HW_LC), (50 + SW_LC, HW_LC), (w_q - 50 - SW_LC, HW_LC), (w_q - 50 - SW_LC, XH - HW_LC)])
    draw_polygon_cw(pen, [(w_q - 50 - SW_LC, -180), (w_q - 50, -180), (w_q - 50, XH), (w_q - 50 - SW_LC, XH)])
    glyf_dict['q'] = pen.glyph()
    metrics_dict['q'] = (w_q + 20, 50)

    # r
    pen = TTGlyphPen(None)
    w_r = 540
    draw_polygon_cw(pen, [(50, 0), (50, XH), (50 + SW_LC, XH), (50 + SW_LC, 0)])
    draw_polygon_cw(pen, [(50 + SW_LC, XH), (w_r - 50, XH), (w_r - 50, XH - HW_LC), (50 + SW_LC, XH - HW_LC)])
    glyf_dict['r'] = pen.glyph()
    metrics_dict['r'] = (w_r + 20, 50)

    # t
    pen = TTGlyphPen(None)
    w_t = 560
    draw_polygon_cw(pen, [(w_t//2 - SW_LC//2, 0), (w_t//2 - SW_LC//2, CAP), (w_t//2 + SW_LC//2, CAP), (w_t//2 + SW_LC//2, 0)])
    draw_polygon_cw(pen, [(50, XH), (w_t - 50, XH), (w_t - 50, XH - HW_LC), (50, XH - HW_LC)])
    glyf_dict['t'] = pen.glyph()
    metrics_dict['t'] = (w_t + 20, 50)

    # u
    pen = TTGlyphPen(None)
    w_u = 740
    draw_polygon_cw(pen, [(50, XH), (50 + SW_LC, XH), (50 + SW_LC, HW_LC), (w_u - 50 - SW_LC, HW_LC), (w_u - 50 - SW_LC, XH), (w_u - 50, XH), (w_u - 50, 0), (50, 0)])
    glyf_dict['u'] = pen.glyph()
    metrics_dict['u'] = (w_u + 20, 50)

    # v
    pen = TTGlyphPen(None)
    w_v = 740
    draw_polygon_cw(pen, [(50, XH), (50 + SW_LC, XH), (w_v//2 + SW_LC//2, 0), (w_v//2 - SW_LC//2, 0)])
    draw_polygon_cw(pen, [(w_v - 50 - SW_LC, XH), (w_v - 50, XH), (w_v//2 + SW_LC//2, 0), (w_v//2 - SW_LC//2, 0)])
    glyf_dict['v'] = pen.glyph()
    metrics_dict['v'] = (w_v + 20, 50)

    # w
    pen = TTGlyphPen(None)
    w_w = 980
    draw_polygon_cw(pen, [(50, XH), (50 + SW_LC, XH), (50 + SW_LC, 0), (50, 0)])
    draw_polygon_cw(pen, [(w_w//2 - SW_LC//2, XH), (w_w//2 + SW_LC//2, XH), (w_w//2 + SW_LC//2, 0), (w_w//2 - SW_LC//2, 0)])
    draw_polygon_cw(pen, [(w_w - 50 - SW_LC, XH), (w_w - 50, XH), (w_w - 50, 0), (w_w - 50 - SW_LC, 0)])
    draw_polygon_cw(pen, [(50, 0), (w_w - 50, 0), (w_w - 50, HW_LC), (50, HW_LC)])
    glyf_dict['w'] = pen.glyph()
    metrics_dict['w'] = (w_w + 20, 50)

    # x
    pen = TTGlyphPen(None)
    w_x = 740
    draw_polygon_cw(pen, [(50, XH), (50 + SW_LC, XH), (w_x - 50, 0), (w_x - 50 - SW_LC, 0)])
    draw_polygon_cw(pen, [(w_x - 50 - SW_LC, XH), (w_x - 50, XH), (50 + SW_LC, 0), (50, 0)])
    glyf_dict['x'] = pen.glyph()
    metrics_dict['x'] = (w_x + 20, 50)

    # y
    pen = TTGlyphPen(None)
    w_y = 740
    draw_polygon_cw(pen, [(50, XH), (50 + SW_LC, XH), (w_y//2 + SW_LC//2, 0), (w_y//2 - SW_LC//2, 0)])
    draw_polygon_cw(pen, [(w_y - 50 - SW_LC, XH), (w_y - 50, XH), (50, -180), (50 - SW_LC, -180)])
    glyf_dict['y'] = pen.glyph()
    metrics_dict['y'] = (w_y + 20, 50)

    # z
    pen = TTGlyphPen(None)
    w_z = 700
    draw_polygon_cw(pen, [(50, XH), (w_z - 50, XH), (w_z - 50, XH - HW_LC), (50 + SW_LC, HW_LC), (w_z - 50, HW_LC), (w_z - 50, 0), (50, 0), (50, HW_LC), (w_z - 50 - SW_LC, XH - HW_LC), (50, XH - HW_LC)])
    glyf_dict['z'] = pen.glyph()
    metrics_dict['z'] = (w_z + 20, 50)

    # =========================================================================
    # NUMERALS 0-9 & PUNCTUATION
    # =========================================================================
    # 0-9
    pen = TTGlyphPen(None)
    W_0 = 880
    draw_polygon_cw(pen, [(60 + CH, CAP), (W_0 - 60 - CH, CAP), (W_0 - 60, CAP - CH), (W_0 - 60, CH), (W_0 - 60 - CH, 0), (60 + CH, 0), (60, CH), (60, CAP - CH)])
    draw_polygon_ccw(pen, [(60 + SW + CH, CAP - HW), (60 + SW, CAP - HW - CH), (60 + SW, HW + CH), (60 + SW + CH, HW), (W_0 - 60 - SW - CH, HW), (W_0 - 60 - SW, HW + CH), (W_0 - 60 - SW, CAP - HW - CH), (W_0 - 60 - SW - CH, CAP - HW)])
    draw_polygon_cw(pen, [(W_0//2 - 25, CAP//2 - 25), (W_0//2 - 25, CAP//2 + 25), (W_0//2 + 25, CAP//2 + 25), (W_0//2 + 25, CAP//2 - 25)])
    glyf_dict['zero'] = pen.glyph()
    metrics_dict['zero'] = (W_0 + 30, 60)

    pen = TTGlyphPen(None)
    W_1 = 520
    draw_polygon_cw(pen, [(W_1 - 60 - SW, 0), (W_1 - 60 - SW, CAP), (W_1 - 60, CAP), (W_1 - 60, 0)])
    draw_polygon_cw(pen, [(60, CAP - HW - 60), (W_1 - 60 - SW, CAP), (W_1 - 60 - SW, CAP - HW), (60, CAP - HW - 120)])
    glyf_dict['one'] = pen.glyph()
    metrics_dict['one'] = (W_1 + 30, 60)

    pen = TTGlyphPen(None)
    W_2 = 860
    draw_polygon_cw(pen, [(60 + CH, CAP), (W_2 - 60 - CH, CAP), (W_2 - 60, CAP - CH), (W_2 - 60, CAP//2 + CH), (60 + SW + 50, HW), (W_2 - 60, HW), (W_2 - 60, 0), (60, 0), (60, HW), (W_2 - 60 - SW - 10, CAP//2 + CH), (W_2 - 60 - SW, CAP - HW - CH), (60 + SW + CH, CAP - HW), (60, CAP - HW - 50)])
    glyf_dict['two'] = pen.glyph()
    metrics_dict['two'] = (W_2 + 30, 60)

    pen = TTGlyphPen(None)
    W_3 = 860
    draw_polygon_cw(pen, [(60, CAP - HW), (60 + CH, CAP), (W_3 - 60 - CH, CAP), (W_3 - 60, CAP - CH), (W_3 - 60, CAP//2 + CH), (W_3 - 60 - CH, CAP//2), (W_3 - 60, CAP//2 - CH), (W_3 - 60, CH), (W_3 - 60 - CH, 0), (60 + CH, 0), (60, HW), (W_3 - 60 - SW - CH, HW), (W_3 - 60 - SW, HW + CH), (W_3 - 60 - SW, CAP//2 - HW//2), (W_3 - 180, CAP//2 - HW//2), (W_3 - 180, CAP//2 + HW//2), (W_3 - 60 - SW, CAP//2 + HW//2), (W_3 - 60 - SW, CAP - HW - CH), (W_3 - 60 - SW - CH, CAP - HW)])
    glyf_dict['three'] = pen.glyph()
    metrics_dict['three'] = (W_3 + 30, 60)

    pen = TTGlyphPen(None)
    W_4 = 880
    draw_polygon_cw(pen, [(W_4 - 60 - SW, 0), (W_4 - 60 - SW, CAP), (W_4 - 60, CAP), (W_4 - 60, 0)])
    draw_polygon_cw(pen, [(60, CAP), (60 + SW, CAP), (60 + SW, 240 + HW), (W_4 - 60, 240 + HW), (W_4 - 60, 240), (60, 240)])
    glyf_dict['four'] = pen.glyph()
    metrics_dict['four'] = (W_4 + 30, 60)

    for num, w in [('five', 860), ('six', 880), ('seven', 840), ('eight', 880), ('nine', 880)]:
        pen = TTGlyphPen(None)
        if num == 'seven':
            draw_polygon_cw(pen, [(60, CAP - HW), (60, CAP), (w - 60, CAP), (w - 60, CAP - HW), (w//2, 0), (w//2 - SW, 0)])
        elif num == 'eight':
            draw_polygon_cw(pen, [(60 + CH, CAP), (w - 60 - CH, CAP), (w - 60, CAP - CH), (w - 60, CH), (w - 60 - CH, 0), (60 + CH, 0), (60, CH), (60, CAP - CH)])
            draw_polygon_ccw(pen, [(60 + SW, CAP - HW), (60 + SW, CAP//2 + HW//2), (w - 60 - SW, CAP//2 + HW//2), (w - 60 - SW, CAP - HW)])
            draw_polygon_ccw(pen, [(60 + SW, CAP//2 - HW//2), (60 + SW, HW), (w - 60 - SW, HW), (w - 60 - SW, CAP//2 - HW//2)])
        else:
            draw_polygon_cw(pen, [(60, 0), (60, CAP), (w - 60, CAP), (w - 60, 0)])
            draw_polygon_ccw(pen, [(60 + SW, HW), (w - 60 - SW, HW), (w - 60 - SW, CAP - HW), (60 + SW, CAP - HW)])
        glyf_dict[num] = pen.glyph()
        metrics_dict[num] = (w + 30, 60)

    # Punctuation
    pen = TTGlyphPen(None)
    draw_polygon_cw(pen, [(60, 0), (60, SW), (60 + SW, SW), (60 + SW, 0)])
    glyf_dict['period'] = pen.glyph()
    metrics_dict['period'] = (60 + SW + 60, 60)

    pen = TTGlyphPen(None)
    draw_polygon_cw(pen, [(60, -70), (60, SW), (60 + SW, SW), (60 + SW, 0), (60 + 50, -70)])
    glyf_dict['comma'] = pen.glyph()
    metrics_dict['comma'] = (60 + SW + 60, 60)

    pen = TTGlyphPen(None)
    draw_polygon_cw(pen, [(60, 100), (60, 100 + SW), (60 + SW, 100 + SW), (60 + SW, 100)])
    draw_polygon_cw(pen, [(60, 420), (60, 420 + SW), (60 + SW, 420 + SW), (60 + SW, 420)])
    glyf_dict['colon'] = pen.glyph()
    metrics_dict['colon'] = (60 + SW + 60, 60)

    pen = TTGlyphPen(None)
    W_hy = 520
    draw_polygon_cw(pen, [(60, CAP//2 - HW//2), (60, CAP//2 + HW//2), (W_hy - 60, CAP//2 + HW//2), (W_hy - 60, CAP//2 - HW//2)])
    glyf_dict['hyphen'] = pen.glyph()
    metrics_dict['hyphen'] = (W_hy + 20, 60)

    pen = TTGlyphPen(None)
    W_pl = 680
    cx = W_pl // 2
    cy = CAP // 2
    draw_polygon_cw(pen, [(60, cy - HW//2), (60, cy + HW//2), (W_pl - 60, cy + HW//2), (W_pl - 60, cy - HW//2)])
    draw_polygon_cw(pen, [(cx - SW//2, cy - (W_pl - 120)//2), (cx - SW//2, cy + (W_pl - 120)//2), (cx + SW//2, cy + (W_pl - 120)//2), (cx + SW//2, cy - (W_pl - 120)//2)])
    glyf_dict['plus'] = pen.glyph()
    metrics_dict['plus'] = (W_pl + 30, 60)

    pen = TTGlyphPen(None)
    W_sl = 560
    draw_polygon_cw(pen, [(60, 0), (W_sl - 60 - SW, CAP), (W_sl - 60, CAP), (60 + SW, 0)])
    glyf_dict['slash'] = pen.glyph()
    metrics_dict['slash'] = (W_sl + 20, 60)

    pen = TTGlyphPen(None)
    cy = CAP // 2
    draw_polygon_cw(pen, [(60, cy - SW//2), (60, cy + SW//2), (60 + SW, cy + SW//2), (60 + SW, cy - SW//2)])
    glyf_dict['periodcentered'] = pen.glyph()
    metrics_dict['periodcentered'] = (60 + SW + 60, 60)

    for b_name, is_left in [('bracketleft', True), ('bracketright', False)]:
        pen = TTGlyphPen(None)
        W_br = 480
        if is_left:
            draw_polygon_cw(pen, [(60, 0), (60, CAP), (W_br - 60, CAP), (W_br - 60, CAP - HW), (60 + SW, CAP - HW), (60 + SW, HW), (W_br - 60, HW), (W_br - 60, 0)])
        else:
            draw_polygon_cw(pen, [(W_br - 60 - SW, HW), (W_br - 60 - SW, CAP - HW), (60, CAP - HW), (60, CAP), (W_br - 60, CAP), (W_br - 60, 0), (60, 0), (60, HW)])
        glyf_dict[b_name] = pen.glyph()
        metrics_dict[b_name] = (W_br + 20, 60)

    glyf_dict['parenleft'] = glyf_dict['bracketleft']
    metrics_dict['parenleft'] = metrics_dict['bracketleft']
    glyf_dict['parenright'] = glyf_dict['bracketright']
    metrics_dict['parenright'] = metrics_dict['bracketright']

    pen = TTGlyphPen(None)
    W_ex = 420
    draw_polygon_cw(pen, [(W_ex//2 - SW//2, 220), (W_ex//2 - SW//2, CAP), (W_ex//2 + SW//2, CAP), (W_ex//2 + SW//2, 220)])
    draw_polygon_cw(pen, [(W_ex//2 - SW//2, 0), (W_ex//2 - SW//2, SW), (W_ex//2 + SW//2, SW), (W_ex//2 + SW//2, 0)])
    glyf_dict['exclam'] = pen.glyph()
    metrics_dict['exclam'] = (W_ex + 20, 60)

    glyf_dict['ampersand'] = glyf_dict['plus']
    metrics_dict['ampersand'] = metrics_dict['plus']

    # Finalize TTF
    fb.setupGlyf(glyf_dict)
    fb.setupHorizontalMetrics(metrics_dict)
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
    fb.setupOS2(
        sTypoAscender=ASC,
        sTypoDescender=DESC,
        usWinAscent=ASC,
        usWinDescent=-DESC,
        sxHeight=XH,
        sCapHeight=CAP,
        usWeightClass=950,
        fsType=0
    )
    fb.setupNameTable({
        'familyName': 'NNTS Neo-Tokyo',
        'styleName': 'Black',
        'uniqueFontIdentifier': 'NNTS: Neo-Tokyo Black: 2026',
        'fullName': 'NNTS Neo-Tokyo Black',
        'psName': 'NNTSNeoTokyo-Black',
        'version': 'Version 1.100',
    })
    fb.setupPost()
    fb.save(output_path)
    print(f"Compiled Japanese Tech font with full lowercase: {output_path}")

if __name__ == '__main__':
    create_japanese_tech_font()
