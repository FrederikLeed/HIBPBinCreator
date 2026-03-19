#!/usr/bin/env python3
"""Generate HIBP Pipeline PNG diagram.

Produces docs/diagrams/HIBP-Pipeline.png matching the .drawio source.
Requires: Pillow, a TTF font (set FONT_PATH env var or uses /tmp/fonts/OpenSans.ttf).

Usage:
    python3 docs/diagrams/generate_pipeline_png.py
"""

from PIL import Image, ImageDraw, ImageFont
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(SCRIPT_DIR, "HIBP-Pipeline.png")
FONT_PATH = os.environ.get("FONT_PATH", "/tmp/fonts/OpenSans.ttf")

# Canvas
W, H = 900, 820
BG = "#FFFFFF"

# Colors matching drawio spec
BLUE   = {"bg": "#dae8fc", "border": "#6c8ebf"}   # Download phase
GREEN  = {"bg": "#d5e8d4", "border": "#82b366"}   # Conversion phase
YELLOW = {"bg": "#fff2cc", "border": "#d6b656"}   # Validation
GREY   = {"bg": "#f5f5f5", "border": "#666666"}   # Inputs/outputs
PURPLE = {"bg": "#e1d5e7", "border": "#9673a6"}   # Dependencies


def load_fonts():
    """Load fonts, fall back to default if TTF unavailable."""
    try:
        return {
            "title":    ImageFont.truetype(FONT_PATH, 24),
            "node":     ImageFont.truetype(FONT_PATH, 14),
            "node_sm":  ImageFont.truetype(FONT_PATH, 11),
            "dep":      ImageFont.truetype(FONT_PATH, 11),
            "phase":    ImageFont.truetype(FONT_PATH, 12),
            "arrow":    ImageFont.truetype(FONT_PATH, 11),
        }
    except OSError:
        print(f"Warning: Font not found at {FONT_PATH}, using default", file=sys.stderr)
        f = ImageFont.load_default()
        return {k: f for k in ["title", "node", "node_sm", "dep", "phase", "arrow"]}


def rr(draw, xy, fill, outline, r=8, w=2):
    """Draw a rounded rectangle."""
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=w)


def center_text(draw, x, y, w, text, font, fill):
    """Draw text centered horizontally within a given width."""
    bb = draw.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    draw.text((x + (w - tw) // 2, y), text, fill=fill, font=font)


def draw_arrow(draw, x, y1, y2, color="#333333", w=2):
    """Draw a vertical arrow from y1 to y2 at x."""
    draw.line([(x, y1), (x, y2)], fill=color, width=w)
    # Arrowhead
    ah = 8
    draw.polygon([(x, y2), (x - ah // 2, y2 - ah), (x + ah // 2, y2 - ah)], fill=color)


def draw_dashed_arrow(draw, x1, y1, x2, y2, color="#9673a6", w=2):
    """Draw a dashed horizontal arrow."""
    import math
    dx = x2 - x1
    dy = y2 - y1
    length = math.sqrt(dx * dx + dy * dy)
    dash_len = 8
    gap_len = 6
    step = dash_len + gap_len

    if length == 0:
        return

    ux = dx / length
    uy = dy / length

    d = 0
    while d < length - dash_len:
        sx = x1 + ux * d
        sy = y1 + uy * d
        ex = x1 + ux * min(d + dash_len, length)
        ey = y1 + uy * min(d + dash_len, length)
        draw.line([(sx, sy), (ex, ey)], fill=color, width=w)
        d += step

    # Arrowhead
    ah = 8
    draw.polygon([
        (x2, y2),
        (x2 - ah * ux - (ah // 2) * uy, y2 - ah * uy + (ah // 2) * ux),
        (x2 - ah * ux + (ah // 2) * uy, y2 - ah * uy - (ah // 2) * ux),
    ], fill=color)


def main():
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    fonts = load_fonts()

    # Title
    center_text(draw, 0, 20, W, "HIBP Binary Creator Pipeline", fonts["title"], "#1a1a2e")

    # Layout constants
    cx = W // 2          # center x
    node_w = 260
    node_h = 50
    doc_w = 260
    doc_h = 56
    diamond_size = 80
    dep_w = 130
    dep_h = 36
    left = cx - node_w // 2
    right = cx + node_w // 2

    # Phase label positions
    phase_x = right + 40

    # Y positions for each node
    y_cdn = 80
    y_dl = 170
    y_txt = 260
    y_pack = 360
    y_bin = 450
    y_check = 550
    y_done = 700

    # ---- Dependencies (left side, purple) ----
    dep_x = left - dep_w - 60

    # config.psd1
    dep_y1 = y_cdn + 10
    rr(draw, [dep_x, dep_y1, dep_x + dep_w, dep_y1 + dep_h], PURPLE["bg"], PURPLE["border"], r=6)
    center_text(draw, dep_x, dep_y1 + 9, dep_w, "config.psd1", fonts["dep"], "#333333")
    draw_dashed_arrow(draw, dep_x + dep_w, dep_y1 + dep_h // 2, left, y_dl + node_h // 2, PURPLE["border"])

    # .NET SDK 8+
    dep_y2 = y_dl + 5
    rr(draw, [dep_x, dep_y2, dep_x + dep_w, dep_y2 + dep_h], PURPLE["bg"], PURPLE["border"], r=6)
    center_text(draw, dep_x, dep_y2 + 9, dep_w, ".NET SDK 8+", fonts["dep"], "#333333")
    draw_dashed_arrow(draw, dep_x + dep_w, dep_y2 + dep_h // 2, left, y_dl + node_h // 2, PURPLE["border"])

    # Python 3.6+
    dep_y3 = y_pack + 5
    rr(draw, [dep_x, dep_y3, dep_x + dep_w, dep_y3 + dep_h], PURPLE["bg"], PURPLE["border"], r=6)
    center_text(draw, dep_x, dep_y3 + 9, dep_w, "Python 3.6+", fonts["dep"], "#333333")
    draw_dashed_arrow(draw, dep_x + dep_w, dep_y3 + dep_h // 2, left, y_pack + node_h // 2, PURPLE["border"])

    # ---- Download Phase (blue) ----
    # HIBP CDN
    rr(draw, [left, y_cdn, right, y_cdn + node_h], BLUE["bg"], BLUE["border"])
    center_text(draw, left, y_cdn + 8, node_w, "HIBP CDN", fonts["node"], "#1a3a5c")
    center_text(draw, left, y_cdn + 28, node_w, "haveibeenpwned.com", fonts["node_sm"], "#4a6a8a")

    draw_arrow(draw, cx, y_cdn + node_h, y_dl)

    # haveibeenpwned-downloader
    rr(draw, [left, y_dl, right, y_dl + node_h], BLUE["bg"], BLUE["border"])
    center_text(draw, left, y_dl + 8, node_w, "haveibeenpwned-downloader", fonts["node"], "#1a3a5c")
    center_text(draw, left, y_dl + 28, node_w, "64 threads, ~25 min", fonts["node_sm"], "#4a6a8a")

    draw_arrow(draw, cx, y_dl + node_h, y_txt)

    # Phase label: Download
    draw.text((phase_x, y_cdn + 30), "Download", fill=BLUE["border"], font=fonts["phase"])
    draw.text((phase_x, y_cdn + 46), "Phase", fill=BLUE["border"], font=fonts["phase"])

    # ---- Text file output (grey document) ----
    dleft = cx - doc_w // 2
    dright = cx + doc_w // 2
    # Document shape approximation (rectangle with folded corner)
    fold = 14
    draw.polygon([
        (dleft, y_txt),
        (dright - fold, y_txt),
        (dright, y_txt + fold),
        (dright, y_txt + doc_h),
        (dleft, y_txt + doc_h),
    ], fill=GREY["bg"], outline=GREY["border"], width=2)
    draw.line([(dright - fold, y_txt), (dright - fold, y_txt + fold), (dright, y_txt + fold)],
              fill=GREY["border"], width=1)
    center_text(draw, dleft, y_txt + 12, doc_w, "pwnedpasswords_ntlm.txt", fonts["node"], "#333333")
    center_text(draw, dleft, y_txt + 32, doc_w, "~69 GB sorted text", fonts["node_sm"], "#666666")

    draw_arrow(draw, cx, y_txt + doc_h, y_pack)

    # ---- Conversion Phase (green) ----
    rr(draw, [left, y_pack, right, y_pack + node_h], GREEN["bg"], GREEN["border"])
    center_text(draw, left, y_pack + 8, node_w, "pypsirepacker (Python)", fonts["node"], "#2d5a1e")
    center_text(draw, left, y_pack + 28, node_w, "streaming, near-zero memory", fonts["node_sm"], "#4a7a3a")

    draw_arrow(draw, cx, y_pack + node_h, y_bin)

    # Phase label: Conversion
    draw.text((phase_x, y_pack + 8), "Conversion", fill=GREEN["border"], font=fonts["phase"])
    draw.text((phase_x, y_pack + 24), "Phase", fill=GREEN["border"], font=fonts["phase"])

    # ---- Binary file output (grey document) ----
    draw.polygon([
        (dleft, y_bin),
        (dright - fold, y_bin),
        (dright, y_bin + fold),
        (dright, y_bin + doc_h),
        (dleft, y_bin + doc_h),
    ], fill=GREY["bg"], outline=GREY["border"], width=2)
    draw.line([(dright - fold, y_bin), (dright - fold, y_bin + fold), (dright, y_bin + fold)],
              fill=GREY["border"], width=1)
    center_text(draw, dleft, y_bin + 12, doc_w, "hibpntlmhashes.bin", fonts["node"], "#333333")
    center_text(draw, dleft, y_bin + 32, doc_w, "~31 GB packed binary", fonts["node_sm"], "#666666")

    draw_arrow(draw, cx, y_bin + doc_h, y_check)

    # ---- Validation (yellow diamond) ----
    dy_mid = y_check + diamond_size
    draw.polygon([
        (cx, y_check),
        (cx + diamond_size, dy_mid),
        (cx, y_check + diamond_size * 2),
        (cx - diamond_size, dy_mid),
    ], fill=YELLOW["bg"], outline=YELLOW["border"], width=2)
    center_text(draw, cx - diamond_size, dy_mid - 16, diamond_size * 2, "Sanity check", fonts["node"], "#7a6000")
    center_text(draw, cx - diamond_size, dy_mid + 2, diamond_size * 2, ">=10% of source", fonts["node_sm"], "#9a8020")

    # Phase label: Validation
    draw.text((phase_x, dy_mid - 8), "Validation", fill=YELLOW["border"], font=fonts["phase"])
    draw.text((phase_x, dy_mid + 8), "Phase", fill=YELLOW["border"], font=fonts["phase"])

    draw_arrow(draw, cx, y_check + diamond_size * 2, y_done)

    # ---- Done (green ellipse) ----
    done_w = 100
    done_h = 44
    draw.ellipse(
        [cx - done_w // 2, y_done, cx + done_w // 2, y_done + done_h],
        fill=GREEN["bg"], outline=GREEN["border"], width=2
    )
    center_text(draw, cx - done_w // 2, y_done + 12, done_w, "Done", fonts["node"], "#2d5a1e")

    # ---- Legend ----
    leg_x = 20
    leg_y = H - 70
    leg_items = [
        ("Download", BLUE),
        ("Conversion", GREEN),
        ("Validation", YELLOW),
        ("I/O Files", GREY),
        ("Dependencies", PURPLE),
    ]
    lx = leg_x
    for label, color in leg_items:
        rr(draw, [lx, leg_y, lx + 16, leg_y + 16], color["bg"], color["border"], r=3, w=1)
        draw.text((lx + 22, leg_y), label, fill="#333333", font=fonts["node_sm"])
        bb = draw.textbbox((0, 0), label, font=fonts["node_sm"])
        lx += (bb[2] - bb[0]) + 44

    img.save(OUT_PATH, "PNG", dpi=(150, 150))
    print(f"Saved: {OUT_PATH} ({W}x{H})")


if __name__ == "__main__":
    main()
