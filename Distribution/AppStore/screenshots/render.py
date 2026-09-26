import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW = "/Users/moooofan/Fridge/Distribution/AppStore/screenshots/raw"
OUT = "/Users/moooofan/Fridge/Distribution/AppStore/screenshots"
FONT_PATH = "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc"
FONT_INDEX_SEMIBOLD = 10  # PingFang TC Semibold

W, H = 1320, 2868
BG = (0x29, 0xA3, 0x6E)
SIDE_MARGIN = 80  # required minimum side margin

# headline lines are given EXPLICITLY — the renderer never auto-wraps.
# A tuple of one string = single line. A tuple of two strings = two lines,
# broken exactly where specified (never mid-word).
shots = [
    ("1_list.png", "list.png", ("冰箱有什麼，就煮什麼",)),
    ("2_detail.png", "detail.png", ("以專業食譜為底", "AI 幫你配菜")),
    ("3_home.png", "home.png", ("打字或拍照，輸入食材",)),
    ("4_onboarding.png", "onboarding.png", ("少買一點，少浪費一點",)),
    ("5_login.png", "login.png", ("Apple、Google、LINE", "一鍵登入")),
]

def load_font(size):
    return ImageFont.truetype(FONT_PATH, size, index=FONT_INDEX_SEMIBOLD)

def line_width(draw, text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]

def fit_font_for_lines(draw, lines, max_width, start_size=92, min_size=40):
    size = start_size
    font = load_font(size)
    while size > min_size:
        widest = max(line_width(draw, line, font) for line in lines)
        if widest <= max_width:
            break
        size -= 2
        font = load_font(size)
    return font, size

def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size[0], size[1]], radius=radius, fill=255)
    return mask

def make_card(image_path, target_width, radius, shadow_blur=40, shadow_offset=20, shadow_opacity=110):
    raw = Image.open(image_path).convert("RGB")
    scale = target_width / raw.width
    target_height = int(raw.height * scale)
    resized = raw.resize((target_width, target_height), Image.LANCZOS)

    mask = rounded_mask((target_width, target_height), radius)
    rounded = Image.new("RGBA", (target_width, target_height))
    rounded.paste(resized, (0, 0), mask)

    pad = shadow_blur * 3
    shadow_canvas = Image.new("RGBA", (target_width + pad * 2, target_height + pad * 2), (0, 0, 0, 0))
    shadow_shape = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_shape)
    sd.rounded_rectangle([0, 0, target_width, target_height], radius=radius, fill=(0, 0, 0, shadow_opacity))
    shadow_canvas.paste(shadow_shape, (pad, pad + shadow_offset), shadow_shape)
    shadow_canvas = shadow_canvas.filter(ImageFilter.GaussianBlur(shadow_blur))

    return rounded, shadow_canvas, pad

def render_all():
    max_text_width = W - SIDE_MARGIN * 2
    for out_name, raw_name, lines in shots:
        raw_path = os.path.join(RAW, raw_name)
        canvas = Image.new("RGB", (W, H), BG)
        draw = ImageDraw.Draw(canvas)

        font, font_size = fit_font_for_lines(draw, lines, max_text_width)

        ascent, descent = font.getmetrics()
        line_height = int((ascent + descent) * 1.25)
        total_text_height = line_height * len(lines)
        text_top = 150

        y = text_top
        for line in lines:
            lw = line_width(draw, line, font)
            x = (W - lw) / 2
            draw.text((x + 2, y + 2), line, font=font, fill=(0, 0, 0, 60))
            draw.text((x, y), line, font=font, fill=(255, 255, 255))
            y += line_height

        card_top = text_top + total_text_height + 90
        bottom_margin = 60
        max_card_height = H - card_top - bottom_margin

        raw_probe = Image.open(raw_path)
        aspect = raw_probe.height / raw_probe.width

        card_width = int(W * 0.82)
        if card_width * aspect > max_card_height:
            card_width = int(max_card_height / aspect)

        radius = 60
        card, shadow, pad = make_card(raw_path, card_width, radius)
        card_x = (W - card_width) // 2

        canvas.paste(shadow, (card_x - pad, card_top - pad), shadow)
        canvas.paste(card, (card_x, card_top), card)

        out_path = os.path.join(OUT, out_name)
        canvas.save(out_path)
        print("saved", out_path, canvas.size, "font_size", font_size, "card bottom", card_top + card.height)

if __name__ == "__main__":
    render_all()
