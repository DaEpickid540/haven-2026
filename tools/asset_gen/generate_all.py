"""Regenerate every placeholder asset.  Usage:  python tools/asset_gen/generate_all.py [sprites|sfx|music]"""
import sys

import gen_godot
import gen_music
import gen_sfx
import gen_sprites

if __name__ == "__main__":
    what = sys.argv[1:] or ["sprites", "sfx", "music"]
    if "sprites" in what:
        gen_sprites.run()
        print(f"sprites done, {len(gen_sprites.MANIFEST)} animated sheets")
        gen_godot.run()
    if "sfx" in what:
        gen_sfx.run()
    if "music" in what:
        gen_music.run()
