#!/usr/bin/env python3
"""
Generates a polished macOS AppIcon.icns for DualSynth.
Creates an iconset directory with all required resolutions and compiles via iconutil.
"""
import os
import subprocess
from PIL import Image, ImageDraw

def create_base_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # macOS squircle bounds (standard 824px inner icon size on 1024 grid)
    padding = int(size * 0.09)
    box = [padding, padding, size - padding, size - padding]
    corner_radius = int(size * 0.22)

    # Draw rounded background squircle
    draw.rounded_rectangle(box, radius=corner_radius, fill=(20, 22, 28, 255), outline=(50, 56, 70, 255), width=int(size * 0.008))

    # Inner subtle glow border
    inner_box = [padding + int(size * 0.008), padding + int(size * 0.008), size - padding - int(size * 0.008), size - padding - int(size * 0.008)]
    draw.rounded_rectangle(inner_box, radius=corner_radius - 4, outline=(0, 229, 255, 60), width=int(size * 0.006))

    cx, cy = size // 2, size // 2

    # Draw DualSense Controller stylized silhouette
    # Main body contour
    # Left grip, right grip, center bridge
    grip_w = int(size * 0.14)
    grip_h = int(size * 0.38)
    center_w = int(size * 0.54)
    center_h = int(size * 0.26)

    # Upper arch / touchpad plate
    tp_w = int(size * 0.24)
    tp_h = int(size * 0.14)
    tp_box = [cx - tp_w // 2, cy - int(size * 0.16), cx + tp_w // 2, cy - int(size * 0.16) + tp_h]
    draw.rounded_rectangle(tp_box, radius=int(size * 0.03), fill=(10, 12, 16, 255), outline=(0, 229, 255, 200), width=int(size * 0.006))

    # Controller main curve
    controller_box = [cx - center_w // 2, cy - int(size * 0.12), cx + center_w // 2, cy + int(size * 0.18)]
    draw.rounded_rectangle(controller_box, radius=int(size * 0.10), fill=(30, 34, 44, 255), outline=(0, 229, 255, 220), width=int(size * 0.010))

    # Left / Right stick circles
    stick_r = int(size * 0.065)
    left_stick = [cx - int(size * 0.13) - stick_r, cy + int(size * 0.04) - stick_r, cx - int(size * 0.13) + stick_r, cy + int(size * 0.04) + stick_r]
    right_stick = [cx + int(size * 0.13) - stick_r, cy + int(size * 0.04) - stick_r, cx + int(size * 0.13) + stick_r, cy + int(size * 0.04) + stick_r]

    draw.ellipse(left_stick, fill=(15, 18, 24, 255), outline=(0, 229, 255, 255), width=int(size * 0.007))
    draw.ellipse(right_stick, fill=(15, 18, 24, 255), outline=(255, 150, 0, 255), width=int(size * 0.007))

    # D-pad cross on left
    dpad_cx = cx - int(size * 0.17)
    dpad_cy = cy - int(size * 0.04)
    dpad_size = int(size * 0.024)
    dpad_arm = int(size * 0.048)
    draw.rectangle([dpad_cx - dpad_size, dpad_cy - dpad_arm, dpad_cx + dpad_size, dpad_cy + dpad_arm], fill=(70, 78, 96, 255))
    draw.rectangle([dpad_cx - dpad_arm, dpad_cy - dpad_size, dpad_cx + dpad_arm, dpad_cy + dpad_size], fill=(70, 78, 96, 255))

    # Face buttons on right (4 dots: triangle, circle, cross, square)
    fb_cx = cx + int(size * 0.17)
    fb_cy = cy - int(size * 0.04)
    dot_r = int(size * 0.014)
    f_offset = int(size * 0.038)
    draw.ellipse([fb_cx - dot_r, fb_cy - f_offset - dot_r, fb_cx + dot_r, fb_cy - f_offset + dot_r], fill=(0, 230, 118, 255)) # Green triangle
    draw.ellipse([fb_cx + f_offset - dot_r, fb_cy - dot_r, fb_cx + f_offset + dot_r, fb_cy + dot_r], fill=(255, 59, 48, 255)) # Red circle
    draw.ellipse([fb_cx - dot_r, fb_cy + f_offset - dot_r, fb_cx + dot_r, fb_cy + f_offset + dot_r], fill=(0, 122, 255, 255)) # Blue cross
    draw.ellipse([fb_cx - f_offset - dot_r, fb_cy - dot_r, fb_cx - f_offset + dot_r, fb_cy + dot_r], fill=(255, 45, 85, 255)) # Pink square

    # Audio Waveform bars across bottom
    wave_y = cy + int(size * 0.28)
    bar_heights = [0.03, 0.06, 0.10, 0.16, 0.11, 0.07, 0.14, 0.18, 0.12, 0.08, 0.04]
    bar_w = int(size * 0.022)
    bar_gap = int(size * 0.015)
    total_wave_w = len(bar_heights) * (bar_w + bar_gap) - bar_gap
    start_x = cx - total_wave_w // 2

    for i, h_ratio in enumerate(bar_heights):
        bx = start_x + i * (bar_w + bar_gap)
        bh = int(size * h_ratio)
        bar_box = [bx, wave_y - bh // 2, bx + bar_w, wave_y + bh // 2]
        # Gradient effect: cyan to orange
        ratio = i / (len(bar_heights) - 1)
        r = int(0 * (1 - ratio) + 255 * ratio)
        g = int(229 * (1 - ratio) + 150 * ratio)
        b = int(255 * (1 - ratio) + 0 * ratio)
        draw.rounded_rectangle(bar_box, radius=bar_w // 2, fill=(r, g, b, 230))

    return img

def main():
    tmp_dir = os.path.abspath("./tmp")
    os.makedirs(tmp_dir, exist_ok=True)
    iconset_dir = os.path.join(tmp_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    base = create_base_icon(1024)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for s, name in sizes:
        resized = base.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))

    icns_path = os.path.join(tmp_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"✅ Generated AppIcon.icns at {icns_path}")

if __name__ == "__main__":
    main()
