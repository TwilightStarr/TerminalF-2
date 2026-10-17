"""TerminalF logo: komut istemi (>) + imlec (_).

Tek, kalin, yuvarlak uclu bir cizgi: ">" isareti marka gradyaniyla
(beyaz -> gumus), altinda aydinlik bir imlec blogu. Ayni geometri SVG'yi,
Android ikon PNG'lerini, bildirim ikonunu ve README bannerini uretir.

Calistirma: python3 branding/generate_logo.py  (Pillow gerekir)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

S = 1024
BG1, BG2 = (0, 0, 0), (27, 27, 27)
TEAL, BLUE = (255, 255, 255), (189, 189, 189)  # beyaz -> gumus
WHITE = (245, 245, 245)

# ">" cizgisi (orta cizgi noktalari) ve kalinligi
CHEV = [(318, 316), (548, 512), (318, 708)]
CHEV_W = 132
# imlec blogu (x0, y0, x1, y1) ve koseler
CURSOR = (598, 664, 790, 768)
CURSOR_R = 34


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, c1, c2):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = lerp(c1, c2, (x + y) / (2 * (size - 1)))
    return img


def chevron_mask(n, k):
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    pts = [(x * k, y * k) for x, y in CHEV]
    w = CHEV_W * k
    d.line(pts, fill=255, width=w, joint="curve")
    r = w / 2
    for x, y in pts:  # yuvarlak uclar ve kose
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def content(mono=False):
    """1024x1024 RGBA, seffaf zemin: > + imlec."""
    k = 3
    n = S * k
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    col = (Image.new("RGBA", (n, n), (255, 255, 255, 255)) if mono
           else gradient(n, TEAL, BLUE).convert("RGBA"))
    out.paste(col, (0, 0), chevron_mask(n, k))
    cm = Image.new("L", (n, n), 0)
    x0, y0, x1, y1 = CURSOR
    ImageDraw.Draw(cm).rounded_rectangle(
        [x0 * k, y0 * k, x1 * k, y1 * k], radius=CURSOR_R * k, fill=255)
    ccol = Image.new("RGBA", (n, n), (255, 255, 255, 255) if mono else WHITE + (255,))
    out.paste(ccol, (0, 0), cm)
    return out.resize((S, S), Image.LANCZOS)


def background(shape):
    bg = gradient(S, BG1, BG2).convert("RGBA")
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    if shape == "round":
        d.ellipse([0, 0, S - 1, S - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=232, fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), m)
    return out


def banner(root, legacy):
    W, H = 1280, 480
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    logo = legacy.resize((260, 260), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([146, 106, 414, 374], radius=68, outline=(42, 42, 42), width=2)
    img.alpha_composite(logo, (150, 110))
    bold = regular = None
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(p):
            bold = ImageFont.truetype(p, 104)
            regular = ImageFont.truetype(p.replace("-Bold", "").replace("Sans-Bold", "Sans"), 36)
            break
    if bold:
        d.text((450, 130), "TerminalF", font=bold, fill=WHITE)
        d.text((454, 270), "Telefonunu tek yerden yönet.", font=regular, fill=(142, 142, 142))
        d.text((454, 322), "Açık kaynak · Reklamsız · Veri göndermez", font=regular, fill=(214, 214, 214))
    os.makedirs(os.path.join(root, "docs"), exist_ok=True)
    img.convert("RGB").save(os.path.join(root, "docs", "banner.png"), optimize=True)
    legacy.resize((256, 256), Image.LANCZOS).save(os.path.join(root, "docs", "logo.png"), optimize=True)


def build(root):
    res = os.path.join(root, "branding", "android", "res")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    fg, mono = content(False), content(True)
    legacy = Image.alpha_composite(background("squircle"), fg)
    rnd = Image.alpha_composite(background("round"), fg)
    for name, f in dens.items():
        d = os.path.join(res, f"mipmap-{name}")
        os.makedirs(d, exist_ok=True)
        l = int(48 * f)
        a = int(108 * f)
        legacy.resize((l, l), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
        rnd.resize((l, l), Image.LANCZOS).save(os.path.join(d, "ic_launcher_round.png"))
        fg.resize((a, a), Image.LANCZOS).save(os.path.join(d, "ic_launcher_foreground.png"))
        mono.resize((a, a), Image.LANCZOS).save(os.path.join(d, "ic_launcher_monochrome.png"))
    v26 = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(v26, exist_ok=True)
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
           '    <background android:drawable="@color/ic_launcher_background"/>\n'
           '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
           '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
           '</adaptive-icon>\n')
    for fn in ("ic_launcher.xml", "ic_launcher_round.xml"):
        open(os.path.join(v26, fn), "w").write(xml)
    vals = os.path.join(res, "values")
    os.makedirs(vals, exist_ok=True)
    open(os.path.join(vals, "ic_launcher_background.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#000000</color>\n</resources>\n')
    # Bildirim ikonu: durum cubugunda tek renk (beyaz) vektor + R8 koruma
    dr = os.path.join(res, "drawable")
    os.makedirs(dr, exist_ok=True)
    open(os.path.join(dr, "ic_stat_notify.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="24dp" android:height="24dp"\n'
        '    android:viewportWidth="24" android:viewportHeight="24">\n'
        '    <path android:pathData="M6.5,5.5 L14,12 L6.5,18.5"\n'
        '        android:strokeColor="#FFFFFF" android:strokeWidth="3"\n'
        '        android:strokeLineCap="round" android:strokeLineJoin="round"/>\n'
        '    <path android:pathData="M16.5,18.5 L20,18.5"\n'
        '        android:strokeColor="#FFFFFF" android:strokeWidth="3"\n'
        '        android:strokeLineCap="round"/>\n'
        '</vector>\n')
    raw = os.path.join(res, "raw")
    os.makedirs(raw, exist_ok=True)
    open(os.path.join(raw, "keep.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources xmlns:tools="http://schemas.android.com/tools"\n'
        '    tools:keep="@drawable/ic_stat_notify,@mipmap/ic_launcher" />\n')
    os.makedirs(os.path.join(root, "assets", "icon"), exist_ok=True)
    legacy.save(os.path.join(root, "assets", "icon", "icon.png"))
    legacy.resize((512, 512), Image.LANCZOS).save(os.path.join(root, "branding", "play_store_512.png"))
    banner(root, legacy)
    return legacy


def svg():
    (ax, ay), (bx, by), (cx, cy) = CHEV
    x0, y0, x1, y1 = CURSOR
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#000000"/><stop offset="1" stop-color="#1B1B1B"/></linearGradient>
    <linearGradient id="brand" gradientUnits="userSpaceOnUse" x1="250" y1="250" x2="620" y2="780"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#BDBDBD"/></linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="232" fill="url(#bg)"/>
  <path d="M {ax} {ay} L {bx} {by} L {cx} {cy}" fill="none" stroke="url(#brand)" stroke-width="{CHEV_W}" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" rx="{CURSOR_R}" fill="#F5F5F5"/>
</svg>
'''


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    build(root)
    open(os.path.join(root, "assets", "icon", "icon.svg"), "w").write(svg())
    print("ok")
