# Chess piece assets

Drop 12 PNG files here with transparent backgrounds. The board will pick them
up automatically; if any are missing, the vector-painter fallback is used
for that piece.

## Required filenames (case-sensitive, lowercase)

white_king.png
white_queen.png
white_rook.png
white_bishop.png
white_knight.png
white_pawn.png

black_king.png
black_queen.png
black_rook.png
black_bishop.png
black_knight.png
black_pawn.png

## Recommended specs

- **Size:** 512×512 px (renders crisply on every device up to ~3x density)
- **Format:** PNG with alpha channel (transparent background)
- **Aspect:** square; the piece itself should be vertically centered and fill
  roughly 80–90% of the canvas height (leave a little margin so pieces don't
  touch the square edges)
- **Shadow:** either baked-in soft drop shadow, or none — NOT a hard cast
  shadow, since the board already draws square borders

## Where to get them

### Free / CC-licensed
- **OpenGameArt.org** — search "chess pieces 3d"; several CC0 sets
- **Wikimedia Commons** — Cburnett SVG set (vector, not photoreal); convert
  to PNG at 512px if you want this look
- **Lichess piece sets** — the "Staunty" and "Merida" families are SVG but
  render cleanly when rasterized

### Paid / commercial
- **Chess.com asset packs** — not publicly licensed; contact their team
- **Shutterstock / Adobe Stock** — search "chess pieces isolated 3d render";
  typically $10–$30 per image
- **Fiverr / Upwork** — a freelance Blender artist will render a full
  12-piece set for roughly $50–$150

### DIY (best quality, most control)
Render your own in Blender:
1. Download a free Staunton model from BlendSwap or Sketchfab (CC-BY).
2. Set up a 3-light studio rig (key + fill + rim).
3. Use a charcoal/obsidian material for black, ivory for white.
4. Render at 1024×1024 with transparent background, then downscale to 512.

## After adding assets

Run `flutter pub get` and hot-restart. No code changes required — the widget
auto-detects PNGs by filename.
