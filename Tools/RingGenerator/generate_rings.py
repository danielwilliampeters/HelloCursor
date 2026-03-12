from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

CANVAS_SIZE = 512
CENTER_X = 256.0
CENTER_Y = 256.0
ALPHA_THRESHOLD = 1
SIZES = [48, 64, 80, 96]


@dataclass
class Annulus:
    inner: float
    outer: float


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(f"Missing file: {path}")

    img = Image.open(path).convert("RGBA")
    if img.size != (CANVAS_SIZE, CANVAS_SIZE):
        raise ValueError(f"{path} must be {CANVAS_SIZE}x{CANVAS_SIZE}, got {img.size}")
    return img


def save_tga(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="TGA")


def bilinear_sample(img: Image.Image, x: float, y: float) -> tuple[int, int, int, int]:
    width, height = img.size

    x = max(0.0, min(width - 1.0, x))
    y = max(0.0, min(height - 1.0, y))

    x0 = int(math.floor(x))
    y0 = int(math.floor(y))
    x1 = min(x0 + 1, width - 1)
    y1 = min(y0 + 1, height - 1)

    dx = x - x0
    dy = y - y0

    p00 = img.getpixel((x0, y0))
    p10 = img.getpixel((x1, y0))
    p01 = img.getpixel((x0, y1))
    p11 = img.getpixel((x1, y1))

    def interp(c00: int, c10: int, c01: int, c11: int) -> int:
        top = c00 * (1.0 - dx) + c10 * dx
        bottom = c01 * (1.0 - dx) + c11 * dx
        return int(round(top * (1.0 - dy) + bottom * dy))

    return tuple(interp(p00[i], p10[i], p01[i], p11[i]) for i in range(4))  # type: ignore[return-value]


def detect_annulus_from_alpha(base_img: Image.Image) -> Annulus:
    min_r = float("inf")
    max_r = 0.0
    found = False

    for y in range(CANVAS_SIZE):
        for x in range(CANVAS_SIZE):
            a = base_img.getpixel((x, y))[3]
            if a > ALPHA_THRESHOLD:
                dx = (x + 0.5) - CENTER_X
                dy = (y + 0.5) - CENTER_Y
                r = math.hypot(dx, dy)
                min_r = min(min_r, r)
                max_r = max(max_r, r)
                found = True

    if not found:
        raise ValueError("No ring pixels found in base alpha.")

    return Annulus(inner=min_r, outer=max_r)


def radial_remap(
    source_img: Image.Image,
    source_annulus: Annulus,
    target_annulus: Annulus,
) -> Image.Image:
    out = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))

    src_inner = source_annulus.inner
    src_outer = source_annulus.outer
    tgt_inner = target_annulus.inner
    tgt_outer = target_annulus.outer

    src_thickness = src_outer - src_inner
    tgt_thickness = tgt_outer - tgt_inner

    if src_thickness <= 0 or tgt_thickness <= 0:
        raise ValueError(
            f"Invalid annulus thickness. Source={src_thickness}, Target={tgt_thickness}"
        )

    for y in range(CANVAS_SIZE):
        for x in range(CANVAS_SIZE):
            dx = (x + 0.5) - CENTER_X
            dy = (y + 0.5) - CENTER_Y
            r_tgt = math.hypot(dx, dy)

            if r_tgt < tgt_inner or r_tgt > tgt_outer:
                continue

            theta = math.atan2(dy, dx)
            t = (r_tgt - tgt_inner) / tgt_thickness
            r_src = src_inner + t * src_thickness

            src_x = CENTER_X + math.cos(theta) * r_src
            src_y = CENTER_Y + math.sin(theta) * r_src

            out.putpixel((x, y), bilinear_sample(source_img, src_x, src_y))

    return out


def generate_layer(
    base_dir: Path,
    master_path: Path,
    output_neon_dir: Path,
    output_prefix: str,
) -> None:
    print(f"\nGenerating {output_prefix} from {master_path.name}")

    source_img = load_rgba(master_path)
    source_base = load_rgba(base_dir / "ring_96.tga")
    source_annulus = detect_annulus_from_alpha(source_base)

    generated_count = 0

    for size in SIZES:
        for small in (False, True):
            base_name = f"ring_small_{size}.tga" if small else f"ring_{size}.tga"
            base_path = base_dir / base_name

            if not base_path.exists():
                print(f"Skipped missing base template: {base_name}")
                continue

            target_base = load_rgba(base_path)
            target_annulus = detect_annulus_from_alpha(target_base)

            out_img = radial_remap(source_img, source_annulus, target_annulus)

            out_name = f"{output_prefix}_small_{size}.tga" if small else f"{output_prefix}_{size}.tga"
            out_path = output_neon_dir / out_name

            save_tga(out_img, out_path)
            generated_count += 1
            print(f"Wrote {out_name}")

    print(f"Finished {output_prefix}: generated {generated_count} files")


def main() -> None:
    root = Path(__file__).resolve().parent
    addon_root = root.parent.parent

    base_dir = root / "Base"
    masters_dir = root / "Masters"
    output_neon_dir = addon_root / "Assets" / "Rings" / "Modern"

    print(f"Root: {root}")
    print(f"Addon root: {addon_root}")
    print(f"Base dir: {base_dir}")
    print(f"Masters dir: {masters_dir}")
    print(f"Output neon dir: {output_neon_dir}")

    if not base_dir.exists():
        raise FileNotFoundError(f"Base dir not found: {base_dir}")

    if not masters_dir.exists():
        raise FileNotFoundError(f"Masters dir not found: {masters_dir}")

    masters = {
        "ring_core_96.tga": "ring_core",
        "ring_edge_96.tga": "ring_edge",
    }

    for master_filename, output_prefix in masters.items():
        master_path = masters_dir / master_filename
        if not master_path.exists():
            raise FileNotFoundError(f"Missing required master file: {master_path}")

        generate_layer(
            base_dir=base_dir,
            master_path=master_path,
            output_neon_dir=output_neon_dir,
            output_prefix=output_prefix,
        )

    print("\nDone. Neon rings written to Assets/Rings/Modern.")


if __name__ == "__main__":
    main()