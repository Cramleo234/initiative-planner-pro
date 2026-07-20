#!/usr/bin/env python3

"""Validate the checked-in macOS AppIcon set without third-party packages."""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path
from typing import cast

EXPECTED_SIZES = (16, 32, 64, 128, 256, 512, 1024)
EXPECTED_SLOTS = {
    ("16x16", "1x", "icon_16.png"),
    ("16x16", "2x", "icon_32.png"),
    ("32x32", "1x", "icon_32.png"),
    ("32x32", "2x", "icon_64.png"),
    ("128x128", "1x", "icon_128.png"),
    ("128x128", "2x", "icon_256.png"),
    ("256x256", "1x", "icon_256.png"),
    ("256x256", "2x", "icon_512.png"),
    ("512x512", "1x", "icon_512.png"),
    ("512x512", "2x", "icon_1024.png"),
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_rgba_png(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")

    position = len(PNG_SIGNATURE)
    chunks: list[str] = []
    compressed = bytearray()
    width = height = bit_depth = color_type = interlace = None

    while position < len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        chunk_type_bytes = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        chunk_type = chunk_type_bytes.decode("ascii")
        chunks.append(chunk_type)
        position += length + 12

        if chunk_type == "IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
        elif chunk_type == "IDAT":
            compressed.extend(payload)
        elif chunk_type == "IEND":
            break

    if width is None or height is None or bit_depth is None or color_type is None or interlace is None:
        raise ValueError(f"{path}: missing IHDR")
    if bit_depth != 8 or color_type != 6 or interlace != 0:
        raise ValueError(
            f"{path}: expected non-interlaced 8-bit RGBA, got "
            f"bit depth {bit_depth}, color type {color_type}, interlace {interlace}"
        )

    bytes_per_pixel = 4
    row_length = width * bytes_per_pixel
    raw = zlib.decompress(bytes(compressed))
    expected_length = height * (row_length + 1)
    if len(raw) != expected_length:
        raise ValueError(f"{path}: unexpected decompressed byte count {len(raw)}")

    rows: list[bytearray] = []
    offset = 0
    previous = bytearray(row_length)
    for _ in range(height):
        filter_type = raw[offset]
        encoded = raw[offset + 1 : offset + 1 + row_length]
        offset += row_length + 1
        decoded = bytearray(row_length)
        for index, value in enumerate(encoded):
            left = decoded[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            above = previous[index]
            upper_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
            decoded[index] = (value + predictor) & 0xFF
        rows.append(decoded)
        previous = decoded

    alpha_values: list[int] = []
    nontransparent: list[tuple[int, int]] = []
    for y, row in enumerate(rows):
        for x in range(width):
            alpha = row[x * 4 + 3]
            alpha_values.append(alpha)
            if alpha > 0:
                nontransparent.append((x, y))

    if not nontransparent:
        raise ValueError(f"{path}: image is fully transparent")

    left = min(point[0] for point in nontransparent)
    top = min(point[1] for point in nontransparent)
    right = max(point[0] for point in nontransparent)
    bottom = max(point[1] for point in nontransparent)
    corners = [
        rows[0][3],
        rows[0][(width - 1) * 4 + 3],
        rows[height - 1][3],
        rows[height - 1][(width - 1) * 4 + 3],
    ]

    return {
        "width": width,
        "height": height,
        "alpha_min": min(alpha_values),
        "alpha_max": max(alpha_values),
        "nontransparent_bounds": [left, top, right, bottom],
        "corner_alpha": corners,
        "color_profile_chunk": "iCCP" if "iCCP" in chunks else "sRGB" if "sRGB" in chunks else None,
    }


def validate(appiconset: Path) -> list[dict[str, object]]:
    contents = json.loads((appiconset / "Contents.json").read_text(encoding="utf-8"))
    slots = {
        (image.get("size"), image.get("scale"), image.get("filename"))
        for image in contents.get("images", [])
        if image.get("idiom") == "mac"
    }
    if slots != EXPECTED_SLOTS:
        missing = sorted(EXPECTED_SLOTS - slots)
        extra = sorted(slots - EXPECTED_SLOTS)
        raise ValueError(f"Contents.json slot mismatch; missing={missing}, extra={extra}")

    actual_pngs = {path.name for path in appiconset.glob("*.png")}
    expected_pngs = {f"icon_{size}.png" for size in EXPECTED_SIZES}
    if actual_pngs != expected_pngs:
        raise ValueError(
            f"PNG inventory mismatch; missing={sorted(expected_pngs - actual_pngs)}, "
            f"extra={sorted(actual_pngs - expected_pngs)}"
        )

    summaries: list[dict[str, object]] = []
    for size in EXPECTED_SIZES:
        path = appiconset / f"icon_{size}.png"
        summary = decode_rgba_png(path)
        if (summary["width"], summary["height"]) != (size, size):
            raise ValueError(f"{path}: expected {size}x{size}, got {summary['width']}x{summary['height']}")
        if summary["alpha_min"] != 0 or summary["alpha_max"] != 255:
            raise ValueError(f"{path}: expected both transparent and opaque pixels")
        if summary["corner_alpha"] != [0, 0, 0, 0]:
            raise ValueError(f"{path}: canvas corners are not transparent")
        left, top, right, bottom = cast(list[int], summary["nontransparent_bounds"])
        # At 16 px, high-quality downsampling can place faint antialiasing on an
        # edge even though the 1024 px source has a 5% safe margin. Transparent
        # corners are the reliable clipping guard at that size.
        if size >= 32 and (left == 0 or top == 0 or right == size - 1 or bottom == size - 1):
            raise ValueError(f"{path}: nontransparent artwork touches the canvas edge")
        if summary["color_profile_chunk"] is None:
            raise ValueError(f"{path}: no embedded sRGB/iCCP color profile chunk")
        summaries.append({"file": path.name, **summary})
    return summaries


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("appiconset", type=Path)
    args = parser.parse_args()
    try:
        summaries = validate(args.appiconset)
    except (OSError, ValueError, json.JSONDecodeError, zlib.error) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print(json.dumps({"status": "PASS", "icons": summaries}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
