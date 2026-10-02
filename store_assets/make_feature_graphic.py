"""Play Store feature graphic, exactly 1024x500: brand gradient, logo + name + tagline on the left, three real
app screens on the right (taken from store_assets/raw, so they always match the app).

    python store_assets/make_feature_graphic.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
W, H = 1024, 500
TOP_CROP, BOTTOM_CROP = 0.047, 0.028
C1, C2 = (232, 89, 12), (255, 146, 43)


def font(size, bold=True):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient():
    img = Image.new("RGB", (W, H))
    px = ImageDraw.Draw(img)
    for x in range(W):                     # left -> right, slightly darker on the left behind the text
        t = x / W
        px.line([(x, 0), (x, H)], fill=tuple(int(C1[i] + (C2[i] - C1[i]) * t) for i in range(3)))
    return img.convert("RGBA")


def phone(name, height):
    shot = Image.open(os.path.join(RAW, name)).convert("RGB")
    sw, sh = shot.size
    shot = shot.crop((0, int(sh * TOP_CROP), sw, int(sh * (1 - BOTTOM_CROP))))
    w = int(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    r = 30
    pad = 7
    frame = Image.new("RGBA", (w + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius=r + pad, fill=(28, 28, 30, 255))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, height - 1], radius=r, fill=255)
    frame.paste(shot, (pad, pad), mask)
    return frame


def paste_with_shadow(canvas, img, x, y):
    sh = Image.new("RGBA", (img.width + 60, img.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([30, 38, img.width + 30, img.height + 38], radius=36, fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(sh, (x - 30, y - 30))
    canvas.alpha_composite(img, (x, y))


def main():
    canvas = gradient()

    deco = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse([520, -180, 1120, 420], fill=(255, 255, 255, 30))
    dd.ellipse([-160, 330, 300, 760], fill=(255, 255, 255, 24))
    canvas = Image.alpha_composite(canvas, deco)

    # right side: three real screens, centre one in front, the outer two slightly smaller and behind
    left = phone("04_visits.jpg", 420)
    right = phone("03_attendance.jpg", 420)
    centre = phone("02_home.jpg", 500)
    paste_with_shadow(canvas, left, 556, 70)
    paste_with_shadow(canvas, right, 884, 70)
    paste_with_shadow(canvas, centre, 706, 36)

    # left side: logo card, name, tagline
    logo = Image.open(os.path.join(HERE, "..", "assets", "images", "jmm_logo.png")).convert("RGBA").resize((118, 118), Image.LANCZOS)
    card = Image.new("RGBA", (146, 146), (0, 0, 0, 0))
    ImageDraw.Draw(card).rounded_rectangle([0, 0, 145, 145], radius=34, fill=(255, 255, 255, 255))
    card.alpha_composite(logo, (14, 14))
    canvas.alpha_composite(card, (56, 64))

    d = ImageDraw.Draw(canvas)
    d.text((56, 232), "JMM InfoTech", font=font(60), fill="white")
    d.text((58, 298), "Employee App", font=font(44, bold=False), fill=(255, 240, 225))
    d.text((58, 380), "Attendance  \u2022  Field Visits  \u2022  Payslips", font=font(23, bold=False), fill=(255, 240, 225))

    out = os.path.join(HERE, "feature-graphic-1024x500.png")
    old = os.path.join(HERE, "feature-graphic-v1.png")
    if os.path.exists(out) and not os.path.exists(old):
        os.replace(out, old)               # keep the first version
    canvas.convert("RGB").save(out, "PNG")
    print(out, Image.open(out).size)


if __name__ == "__main__":
    main()
