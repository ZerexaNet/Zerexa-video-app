#!/usr/bin/env python3
"""Generate the Zerexa Video app icon for Android / iOS / Windows.

Draws the brand mark with PIL: blue gradient rounded square, white play
triangle, and the three underline bars - matching assets/icon.svg.
"""
from PIL import Image, ImageDraw
import os

ROOT = "/home/z/my-project"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


BLUE_A = (10, 108, 255)
BLUE_B = (0, 175, 240)


def draw_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    s = size / 512.0
    # Rounded-rect gradient background (vertical sweep approximation:
    # per-row horizontal gradient looks close enough at icon sizes).
    x0, y0, x1, y1 = 32 * s, 96 * s, 480 * s, 416 * s
    radius = 72 * s
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [x0, y0, x1, y1], radius=radius, fill=255)

    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(int(y0), int(y1) + 1):
        ty = (y - y0) / max(1, (y1 - y0))
        for x in range(int(x0), int(x1) + 1):
            tx = (x - x0) / max(1, (x1 - x0))
            c = lerp(lerp(BLUE_A, BLUE_B, tx), lerp(BLUE_A, BLUE_B, (tx + ty) / 2), ty * 0.5)
            gd.point((x, y), fill=c + (255,))
    img.paste(grad, (0, 0), mask)

    # Play triangle
    tri = [(216 * s, 176 * s), (336 * s, 256 * s), (216 * s, 336 * s)]
    d.polygon(tri, fill=(255, 255, 255, 255))

    # Underline bars
    bar_y = 432 * s
    bar_h = 14 * s
    for bx, bw in ((80, 64), (160, 96), (272, 40)):
        d.rounded_rectangle(
            [bx * s, bar_y, (bx + bw) * s, bar_y + bar_h],
            radius=bar_h / 2,
            fill=lerp(BLUE_A, BLUE_B, bx / 480.0) + (255,))

    return img


def save(img: Image.Image, path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", path)


base = draw_icon(1024)

# ---- Android mipmaps ----
for dpi, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                ("xxhdpi", 144), ("xxxhdpi", 192)]:
    save(base.resize((px, px), Image.LANCZOS),
         f"{ROOT}/android/app/src/main/res/mipmap-{dpi}/ic_launcher.png")

# ---- iOS asset catalog (single-size universal) ----
appiconset = f"{ROOT}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
save(base, f"{appiconset}/AppIcon.png")
with open(f"{appiconset}/Contents.json", "w") as f:
    f.write('''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''')
print("wrote", f"{appiconset}/Contents.json")

# ---- Windows ICO ----
ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
             (128, 128), (256, 256)]
base.save(f"{ROOT}/windows/runner/resources/app_icon.ico",
          sizes=ico_sizes)
print("wrote", f"{ROOT}/windows/runner/resources/app_icon.ico")
