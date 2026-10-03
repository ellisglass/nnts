import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def generate_font_showcase(out_path="assets/nnts_font_showcase.png"):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    
    # 4K Retina Canvas (3840 x 2160)
    SCALE = 2
    S = lambda v: int(v * SCALE)
    W, H = S(1920), S(1080)

    canvas = Image.new('RGBA', (W, H), (12, 14, 20, 255))

    # Color Palette
    TEXT_WHITE = (255, 255, 255, 255)
    TEXT_MUTED = (165, 170, 190, 255)
    TEXT_DIM = (110, 115, 135, 255)
    ACCENT_GREEN = (0, 255, 157, 255)
    ACCENT_CYAN = (0, 225, 255, 255)
    ACCENT_AMBER = (255, 185, 0, 255)
    ACCENT_PURPLE = (210, 140, 255, 255)
    BG_CARD = (20, 22, 32, 255)
    BG_CARD_HIGHLIGHT = (22, 26, 38, 255)
    BORDER_CARD = (40, 44, 62, 255)

    # Global UI Fonts
    font_header_title = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", S(32))
    font_header_sub = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", S(19))
    font_badge = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", S(15))
    font_card_num = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", S(16))
    font_card_name = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", S(18))
    font_card_desc = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", S(14))
    font_tag = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", S(13))

    draw = ImageDraw.Draw(canvas)

    # Top Header
    draw.text((S(80), S(60)), "NNTS TYPOGRAPHY LAB", font=font_header_title, fill=TEXT_WHITE)
    draw.text((S(80), S(104)), "Curated Brand Candidates & Japanese Neo-Brutalist Typeface Lab", font=font_header_sub, fill=TEXT_MUTED)

    # Right Badge
    badge_rect = (S(1540), S(60), S(1840), S(102))
    draw.rounded_rectangle(badge_rect, radius=S(8), fill=(24, 38, 28, 255), outline=ACCENT_GREEN, width=S(1))
    draw.text((S(1690), S(81)), "4K RETINA SPECIMEN", font=font_badge, fill=ACCENT_GREEN, anchor="mm")

    # The 5 Typefaces to Showcase
    # 01. Syne ExtraBold (User Favorite)
    # 02. Dela Gothic One (Tokyo Street Poster Brutalism)
    # 03. Zen Dots (Japanese Cyberpunk Arcade Tech)
    # 04. NNTS Neo-Tokyo (Our Custom Proprietary Japanese Mecha Typeface with Lowercase)
    # 05. Space Grotesk Bold (Cybernetic Tech Sans)
    fonts_data = [
        {
            "num": "01",
            "name": "SPACE GROTESK BOLD (OFFICIAL BRAND WINNER · 100% SELECTED)",
            "desc": "Official brand typeface: engineered proportional sans with monospace roots, terminal ergonomics, and hardware DNA",
            "tag": "OFFICIAL WINNER • WEIGHT 700 • HARDWARE & DEVELOPER DNA",
            "tag_color": ACCENT_GREEN,
            "path": "assets/fonts/SpaceGrotesk-Bold.ttf",
            "size_headline": S(34),
            "size_sample": S(16.5),
            "headline": "NNTS — App & Profile Switcher",
            "sample_1": "caps lock + c/b + 1..4  ·  hold caps lock + [a-z]  ·  copy-on-select",
            "sample_2": "A–Z   a–z   0123456789   ·  +  /  -  :",
            "highlight": True,
            "border_color": (0, 255, 157, 220)
        },
        {
            "num": "02",
            "name": "SYNE EXTRABOLD (CONTEMPORARY AVANT-GARDE BRUTALIST)",
            "desc": "Striking contemporary avant-garde brutalism with expansive proportions and distinctive counters",
            "tag": "CONTENDER • WEIGHT 800 • AVANT-GARDE NEO-BRUTALISM",
            "tag_color": (220, 160, 255, 255),
            "path": "assets/fonts/Syne-ExtraBold.ttf",
            "size_headline": S(34),
            "size_sample": S(16.5),
            "headline": "NNTS — App & Profile Switcher",
            "sample_1": "caps lock + c/b + 1..4  ·  hold caps lock + [a-z]  ·  copy-on-select",
            "sample_2": "A–Z   a–z   0123456789   ·  +  /  -  :",
            "highlight": False,
            "border_color": BORDER_CARD
        },
        {
            "num": "03",
            "name": "DELA GOTHIC ONE (TOKYO POSTER BRUTALISM / AUTHENTIC JAPANESE)",
            "desc": "Ultra-dense Japanese flat-brush poster gothic designed in Tokyo by Takao Saiki (massive visual gravity)",
            "tag": "AUTHENTIC TOKYO DESIGN • WEIGHT 900 • STREET POSTER BRUTALISM",
            "tag_color": ACCENT_AMBER,
            "path": "assets/fonts/DelaGothicOne-Regular.ttf",
            "size_headline": S(32),
            "size_sample": S(16.5),
            "headline": "NNTS — App & Profile Switcher",
            "sample_1": "caps lock + c/b + 1..4  ·  hold caps lock + [a-z]  ·  copy-on-select",
            "sample_2": "A–Z   a–z   0123456789   ·  +  /  -  :",
            "highlight": False,
            "border_color": BORDER_CARD
        },
        {
            "num": "04",
            "name": "ZEN DOTS (JAPANESE CYBERPUNK / ARCADE TECH)",
            "desc": "Futuristic Japanese cybernetic typeface by Yoshimichi Ohira with slashed counters and mecha geometry",
            "tag": "JAPANESE SCI-FI TECH • WEIGHT 700 • ARCADE CYBERPUNK DNA",
            "tag_color": (255, 110, 180, 255),
            "path": "assets/fonts/ZenDots-Regular.ttf",
            "size_headline": S(30),
            "size_sample": S(16),
            "headline": "NNTS - app & profile switcher",
            "sample_1": "caps lock + c/b + 1..4  ·  hold caps lock + [a-z]  ·  copy-on-select",
            "sample_2": "A–Z   a–z   0123456789   ·  +  /  -  :",
            "highlight": False,
            "border_color": BORDER_CARD
        },
        {
            "num": "05",
            "name": "NNTS NEO-TOKYO (PROPRIETARY JAPANESE MECHA DISPLAY)",
            "desc": "Custom typeface with 45° octagonal mecha chamfers, Katana blade terminal slashes, and full lowercase",
            "tag": "PROPRIETARY • WEIGHT 950 • MECHA CHAMFERS • FULL LOWERCASE",
            "tag_color": ACCENT_CYAN,
            "path": "assets/fonts/NNTSNeoTokyo-Black.ttf",
            "size_headline": S(32),
            "size_sample": S(16.5),
            "headline": "NNTS - APP & PROFILE SWITCHER",
            "sample_1": "caps lock + c/b + 1..4  ·  hold caps lock + [a-z]  ·  copy-on-select",
            "sample_2": "A–Z   a–z   0123456789   ·  +  /  -  :",
            "highlight": False,
            "border_color": BORDER_CARD
        }
    ]

    card_y = S(140)
    card_h = S(172)
    card_gap = S(16)

    for f_idx, item in enumerate(fonts_data):
        y0 = card_y + f_idx * (card_h + card_gap)
        y1 = y0 + card_h
        
        # Soft shadow
        s_mask = Image.new('L', (W, H), 0)
        ImageDraw.Draw(s_mask).rounded_rectangle((S(80), y0 + S(4), S(1840), y1 + S(4)), radius=S(16), fill=90)
        s_blur = s_mask.filter(ImageFilter.GaussianBlur(S(16)))
        s_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        s_layer.putalpha(s_blur)
        canvas = Image.alpha_composite(canvas, s_layer)
        
        d = ImageDraw.Draw(canvas)
        bg = BG_CARD_HIGHLIGHT if item.get("highlight") else BG_CARD
        card_border = item.get("border_color", BORDER_CARD)
        border_w = S(2 if item.get("highlight") else 1)
        
        d.rounded_rectangle((S(80), y0, S(1840), y1), radius=S(16), fill=bg, outline=card_border, width=border_w)
        
        # Card Sub-header
        d.text((S(110), y0 + S(22)), item["num"], font=font_card_num, fill=item["tag_color"])
        d.text((S(150), y0 + S(21)), item["name"], font=font_card_name, fill=TEXT_WHITE)
        d.text((S(150), y0 + S(48)), item["desc"], font=font_card_desc, fill=TEXT_MUTED)

        # Right Tag Pill
        bbox_tag = font_tag.getbbox(item["tag"])
        tag_w = bbox_tag[2] - bbox_tag[0] + S(24)
        tag_h = S(28)
        tag_x1 = S(1810)
        tag_x0 = tag_x1 - tag_w
        tag_y0 = y0 + S(22)
        tag_y1 = tag_y0 + tag_h
        d.rounded_rectangle((tag_x0, tag_y0, tag_x1, tag_y1), radius=S(6), fill=(16, 18, 26, 255), outline=item["tag_color"], width=S(1))
        d.text((tag_x0 + S(12), tag_y0 + S(6)), item["tag"], font=font_tag, fill=item["tag_color"])

        # Load Typeface Specimen
        f_head = ImageFont.truetype(item["path"], item["size_headline"])
        f_sample = ImageFont.truetype(item["path"], item["size_sample"])

        # Headline
        d.text((S(110), y0 + S(80)), item["headline"], font=f_head, fill=TEXT_WHITE)

        # Bottom Specimen Row (Green Shortcut & Character Matrix)
        d.text((S(110), y0 + S(136)), item["sample_1"], font=f_sample, fill=ACCENT_GREEN)
        
        # Matrix on Right
        bbox_m = f_sample.getbbox(item["sample_2"])
        m_w = bbox_m[2] - bbox_m[0]
        matrix_x = S(1810) - m_w
        d.text((matrix_x, y0 + S(136)), item["sample_2"], font=f_sample, fill=TEXT_DIM)

    canvas.save(out_path)
    print(f"Generated {out_path} at 4K Retina resolution ({W}x{H}) successfully")

if __name__ == '__main__':
    generate_font_showcase()
