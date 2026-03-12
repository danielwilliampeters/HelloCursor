## Ring Generator

This is a small Python tool that generates the modern neon cursor ring textures for the HelloCursor addon.

It takes master ring images from `Tools/RingGenerator/Masters` and projects them onto the various base templates in `Tools/RingGenerator/Base`, writing the finished TGA files into `Assets/Rings/Modern`.

### Requirements

- Python 3
- Pillow image library (`pip install pillow`)

### Usage

From the root of the HelloCursor repository, run:

```bash
python Tools/RingGenerator/generate_rings.py
```

If everything is set up correctly you should see output for each generated file, and the new ring textures will appear under `Assets/Rings/Modern`.

### Notes

- All input images must be 512x512 RGBA TGA files.
- The script currently expects these master files in `Tools/RingGenerator/Masters`:
  - `ring_core_192.tga`
  - `ring_edge_192.tga`
- Base template files are read from `Tools/RingGenerator/Base` (for sizes 48, 64, 80, 96 and their `ring_small_*.tga` variants).
