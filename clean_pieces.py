"""
One-shot cleanup for chess piece images.

Run once after dropping the 12 PNGs into assets/images/. Walks every
{white,black}_*.png in that folder and:
  1. Samples each image's actual background color from the corners.
  2. Removes any pixel within RGB-distance TOLERANCE of that color.
  3. Finds the LARGEST connected opaque region (the piece) and uses
     its bounding box for cropping, so cast shadows that aren't
     directly attached to the piece don't push it off-center.
  4. Pads to a square canvas (piece centered).
  5. Resizes to 512x512.
  6. Saves back in place.

Usage (from the project root):
    python clean_pieces.py

Requires Pillow + numpy:
    pip install Pillow numpy
"""

from collections import deque
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageFile

# The 9p-mounted source PNGs sometimes arrive without the trailing IEND
# chunk; let Pillow decode what it has rather than refusing the file.
ImageFile.LOAD_TRUNCATED_IMAGES = True

PIECES_DIR = Path(__file__).parent / "assets" / "images"
TOLERANCE = 35      # max RGB Euclidean distance from corner colour
CORNER_PATCH = 8    # sample size in each corner for background colour
OUTPUT_SIZE = 512


def background_colour(arr: np.ndarray) -> tuple[int, int, int]:
    """Return the median RGB across all four CORNER_PATCH x CORNER_PATCH
    corner patches. Median is more robust than mean against an occasional
    stray dark edge pixel."""
    h, w, _ = arr.shape
    p = CORNER_PATCH
    patches = [
        arr[0:p, 0:p, :3],
        arr[0:p, w - p:w, :3],
        arr[h - p:h, 0:p, :3],
        arr[h - p:h, w - p:w, :3],
    ]
    stack = np.concatenate([patch.reshape(-1, 3) for patch in patches])
    med = np.median(stack, axis=0).astype(int)
    return int(med[0]), int(med[1]), int(med[2])


def remove_background(img: Image.Image) -> Image.Image:
    """Set alpha to 0 for any pixel within TOLERANCE of the corner-sampled
    background colour."""
    img = img.convert("RGBA")
    arr = np.array(img)
    bg = background_colour(arr)
    rgb = arr[..., :3].astype(np.int16)
    diff = rgb - np.array(bg, dtype=np.int16)
    dist = np.sqrt((diff * diff).sum(axis=2))
    mask = dist < TOLERANCE  # True where pixel matches background
    arr[..., 3] = np.where(mask, 0, arr[..., 3])
    return Image.fromarray(arr, "RGBA")


def largest_opaque_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    """Find the bounding box of the LARGEST 4-connected component of
    opaque pixels. Returns (left, top, right, bottom) or None if the
    image is entirely transparent.

    This excludes detached shadow remnants (a smaller component) from
    the bounding box, so the piece sits centered after square-padding.
    """
    arr = np.array(img)
    if arr.shape[2] < 4:
        return img.getbbox()
    opaque = arr[..., 3] > 0
    if not opaque.any():
        return None

    # Flood-fill style 4-connected component labelling. We only need the
    # largest, so we can avoid scipy's label() and just do a manual BFS.
    h, w = opaque.shape
    visited = np.zeros_like(opaque, dtype=bool)
    best_bbox = None
    best_size = 0

    for y0 in range(h):
        for x0 in range(w):
            if not opaque[y0, x0] or visited[y0, x0]:
                continue
            # BFS
            q = deque([(y0, x0)])
            visited[y0, x0] = True
            min_x, max_x, min_y, max_y = x0, x0, y0, y0
            size = 0
            while q:
                y, x = q.popleft()
                size += 1
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and \
                       opaque[ny, nx] and not visited[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))
            if size > best_size:
                best_size = size
                best_bbox = (min_x, min_y, max_x + 1, max_y + 1)

    return best_bbox


def trim_and_square(img: Image.Image) -> Image.Image:
    """Crop to the largest opaque component, then pad to a square."""
    bbox = largest_opaque_bbox(img)
    if bbox is None:
        return img
    cropped = img.crop(bbox)
    w, h = cropped.size
    side = max(w, h)
    padded = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    padded.paste(cropped, ((side - w) // 2, (side - h) // 2))
    return padded


def process_one(path: Path) -> None:
    print(f"  {path.name} ... ", end="", flush=True)
    # Some mounted file systems stream PNGs unreliably for Pillow; read
    # the whole file into memory first then let PIL decode from BytesIO.
    raw = path.read_bytes()
    img = Image.open(BytesIO(raw))
    img.load()  # force decode while the BytesIO buffer is still valid
    img = remove_background(img)
    img = trim_and_square(img)
    img = img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)
    # Write via BytesIO too so partial-write flakes don't leave a half
    # file on the mount.
    out_buf = BytesIO()
    img.save(out_buf, "PNG", optimize=True)
    path.write_bytes(out_buf.getvalue())
    print("done")


def main() -> None:
    if not PIECES_DIR.exists():
        raise SystemExit(f"Pieces folder not found: {PIECES_DIR}")

    pngs = sorted(
        p for p in PIECES_DIR.glob("*.png")
        if p.stem.startswith(("white_", "black_"))
    )
    if not pngs:
        raise SystemExit(
            f"No piece PNGs found in {PIECES_DIR}. Drop in 12 files named "
            "{white,black}_{king,queen,rook,bishop,knight,pawn}.png first."
        )

    print(f"Processing {len(pngs)} piece(s) in {PIECES_DIR}:")
    for path in pngs:
        process_one(path)
    print("\nAll done. Now run `flutter run` and a fresh launch.")


if __name__ == "__main__":
    main()
