"""Turns raw phone screenshots into Google Play phone screenshots (1080x1920): brand background, a headline on
top, the real app screen below in rounded corners. Raw files go in store_assets/raw/, results are written to
store_assets/screenshots/. File names decide the headline (see CAPTIONS); anything else uses its own file name.

    python store_assets/make_screenshots.py
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "screenshots")

W, H = 1080, 1920
TOP_CROP = 0.047   # fraction of the phone screenshot's height removed at the top (status bar, clock, battery)
BOTTOM_CROP = 0.028  # ... and at the bottom (the gesture-navigation pill)

# keyword in file name -> (headline, sub line)
CAPTIONS = [
    ("login", ("Secure sign-in", "Your account, your data")),
    ("home", ("Everything in one place", "Attendance, tasks and updates at a glance")),
    ("attendance", ("Punch in & out", "Geofenced attendance, always accurate")),
    ("visit", ("Track field visits", "Start a trip, route recorded automatically")),
    ("trip", ("Track field visits", "Start a trip, route recorded automatically")),
    ("map", ("Plan and assign visits", "Search a place and drop the pin")),
    ("leave", ("Apply for leave", "Track approval status instantly")),
    ("task", ("Stay on top of tasks", "Update progress from anywhere")),
    ("payslip", ("Payslips on your phone", "View and download any month")),
    ("salary", ("Payslips on your phone", "View and download any month")),
    ("wfh", ("Work from home", "Start and end your WFH day")),
    ("notif", ("Never miss an update", "Instant alerts for approvals and reminders")),
    ("profile", ("Your personal hub", "Photo, password and quick access to everything")),
]

BRAND_TOP = (232, 89, 12)      # orange
BRAND_BOTTOM = (255, 146, 43)  # light orange


def font(size, bold=True):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf" if bold else "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            continue
    return ImageFont.load_default()


def caption_for(filename):
    stem = os.path.splitext(filename)[0].lower()
    for key, caption in CAPTIONS:
        if key in stem:
            return caption
    pretty = re.sub(r"^\d+[_\-\s]*", "", stem).replace("_", " ").replace("-", " ").strip().title()
    return (pretty or "JMM InfoTech", "")


def gradient():
    img = Image.new("RGB", (W, H), BRAND_TOP)
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        px.line([(0, y), (W, y)], fill=tuple(int(BRAND_TOP[i] + (BRAND_BOTTOM[i] - BRAND_TOP[i]) * t) for i in range(3)))
    return img


def wrap(draw, text, fnt, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def build(path, index):
    shot = Image.open(path).convert("RGB")
    sw, sh = shot.size
    shot = shot.crop((0, int(sh * TOP_CROP), sw, int(sh * (1 - BOTTOM_CROP))))

    canvas = gradient().convert("RGBA")
    deco = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    dd.ellipse([W - 360, -220, W + 260, 400], fill=(255, 255, 255, 26))
    dd.ellipse([-300, H - 520, 360, H + 140], fill=(255, 255, 255, 22))
    canvas = Image.alpha_composite(canvas, deco).convert("RGB")
    d = ImageDraw.Draw(canvas)
    head, sub = caption_for(os.path.basename(path))

    y = 120
    f1 = font(80)
    for line in wrap(d, head, f1, W - 160):
        d.text((W // 2, y), line, font=f1, fill="white", anchor="ma")
        y += 98
    if sub:
        f2 = font(38, bold=False)
        for line in wrap(d, sub, f2, W - 200):
            d.text((W // 2, y + 12), line, font=f2, fill=(255, 240, 225), anchor="ma")
            y += 52

    # the app screen: scaled so the WHOLE screen (including the bottom menu) fits, centred, rounded, with a shadow
    top = max(y + 56, 330)
    avail_h = H - top - 70
    scale = min(avail_h / shot.height, 900 / shot.width)
    target_w = int(shot.width * scale)
    shot = shot.resize((target_w, int(shot.height * scale)), Image.LANCZOS)
    x = (W - target_w) // 2

    radius = 46
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height], radius=radius, fill=255)

    shadow = Image.new("RGBA", (shot.width + 80, shot.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 52, shot.width + 40, shot.height + 52], radius=radius, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.paste(shadow, (x - 40, top - 40), shadow)

    frame = Image.new("RGB", (shot.width + 16, shot.height + 16), (28, 28, 30))
    fmask = Image.new("L", frame.size, 0)
    ImageDraw.Draw(fmask).rounded_rectangle([0, 0, frame.width, frame.height], radius=radius + 8, fill=255)
    canvas.paste(frame, (x - 8, top - 8), fmask)
    canvas.paste(shot, (x, top), mask)

    out = os.path.join(OUT, "%02d_%s.png" % (index, os.path.splitext(os.path.basename(path))[0].lower().lstrip("0123456789_- ")))
    canvas.save(out, "PNG")
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    files = sorted(f for f in os.listdir(RAW) if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
    if not files:
        print("No screenshots found in", RAW)
        return 1
    for i, f in enumerate(files, 1):
        print(build(os.path.join(RAW, f), i))
    return 0


if __name__ == "__main__":
    sys.exit(main())
