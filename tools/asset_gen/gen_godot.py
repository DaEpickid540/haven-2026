"""Writes Godot resources for the generated art: SpriteFrames, TileSets, UI Theme."""
import os

from common import ASSETS
import gen_sprites

SPR = os.path.join(ASSETS, "sprites")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        f.write(text)


def sprite_frames(rel_png, meta):
    fw, fh = meta["fw"], meta["fh"]
    used = sorted({i for frames, _, _ in meta["anims"].values() for i in frames})
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/sprites/{rel_png}" id="1_tex"]', ""]
    for i in used:
        lines += [f'[sub_resource type="AtlasTexture" id="frame_{i}"]', 'atlas = ExtResource("1_tex")',
                  f"region = Rect2({i * fw}, 0, {fw}, {fh})", ""]
    anims = []
    for name, (frames, fps, loop) in meta["anims"].items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("frame_%d")\n}' % i for i in frames)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (fr, "true" if loop else "false", name, fps))
    lines += ["[resource]", "animations = [%s]" % ", ".join(anims), ""]
    out = os.path.join(SPR, rel_png.replace(".png", "_frames.tres"))
    write(out, "\n".join(lines))


SOLID = [(0, 0), (1, 0), (2, 0), (3, 0), (7, 0), (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 3), (6, 3)]
ONE_WAY = [(4, 0), (5, 0), (6, 0)]
TYPES = {(6, 1): "ladder", (7, 1): "hazard", (4, 3): "liquid", (7, 3): "pit",
         (6, 2): "door", (7, 2): "door", (7, 0): "crate"}


def tileset(theme):
    lines = ['[gd_resource type="TileSet" format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/sprites/tiles/{theme}_tileset.png" id="1_tex"]', "",
             '[sub_resource type="TileSetAtlasSource" id="atlas"]', 'texture = ExtResource("1_tex")']
    for y in range(4):
        for x in range(8):
            k = f"{x}:{y}/0"
            lines.append(f"{k} = 0")
            if (x, y) in SOLID:
                lines.append(f"{k}/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)")
            if (x, y) in ONE_WAY:
                lines.append(f"{k}/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, -3, -8, -3)")
                lines.append(f"{k}/physics_layer_0/polygon_0/one_way = true")
            if (x, y) in TYPES:
                lines.append(f'{k}/custom_data_0 = "{TYPES[(x, y)]}"')
    lines += ["", "[resource]", "physics_layer_0/collision_layer = 1", "physics_layer_0/collision_mask = 0",
              'custom_data_layer_0/name = "type"', "custom_data_layer_0/type = 4",
              'sources/0 = SubResource("atlas")', ""]
    write(os.path.join(SPR, "tiles", f"{theme}_tileset.tres"), "\n".join(lines))


def ui_theme():
    tex = ["button_normal", "button_hover", "button_pressed", "button_disabled", "panel", "panel_light",
           "checkbox_on", "checkbox_off", "bar_frame", "bar_fill_green"]
    lines = ['[gd_resource type="Theme" format=3]', ""]
    for i, t in enumerate(tex):
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/ui/{t}.png" id="{i + 1}_{t}"]')
    lines.append("")

    def sb(id_, t, m, content=(4, 3, 4, 3)):
        idx = tex.index(t) + 1
        return [f'[sub_resource type="StyleBoxTexture" id="{id_}"]', f'texture = ExtResource("{idx}_{t}")',
                f"texture_margin_left = {m}.0", f"texture_margin_top = {m}.0",
                f"texture_margin_right = {m}.0", f"texture_margin_bottom = {m}.0",
                f"content_margin_left = {content[0]}.0", f"content_margin_top = {content[1]}.0",
                f"content_margin_right = {content[2]}.0", f"content_margin_bottom = {content[3]}.0", ""]

    lines += sb("btn_normal", "button_normal", 4)
    lines += sb("btn_hover", "button_hover", 4)
    lines += sb("btn_pressed", "button_pressed", 4, (4, 4, 4, 2))
    lines += sb("btn_disabled", "button_disabled", 4)
    lines += sb("panel", "panel", 6, (6, 6, 6, 6))
    lines += sb("bar_bg", "bar_frame", 3, (0, 0, 0, 0))
    lines += sb("bar_fill", "bar_fill_green", 3, (0, 0, 0, 0))
    lines += ['[sub_resource type="StyleBoxEmpty" id="empty"]', ""]
    lines += ["[resource]",
              "default_font_size = 8",
              'Button/styles/normal = SubResource("btn_normal")',
              'Button/styles/hover = SubResource("btn_hover")',
              'Button/styles/pressed = SubResource("btn_pressed")',
              'Button/styles/disabled = SubResource("btn_disabled")',
              'Button/styles/focus = SubResource("empty")',
              "Button/colors/font_color = Color(1, 1, 1, 1)",
              "Button/colors/font_hover_color = Color(1, 1, 0.8, 1)",
              "Button/colors/font_disabled_color = Color(0.7, 0.7, 0.75, 1)",
              'Panel/styles/panel = SubResource("panel")',
              'PanelContainer/styles/panel = SubResource("panel")',
              'ProgressBar/styles/background = SubResource("bar_bg")',
              'ProgressBar/styles/fill = SubResource("bar_fill")',
              f'CheckBox/icons/checked = ExtResource("{tex.index("checkbox_on") + 1}_checkbox_on")',
              f'CheckBox/icons/unchecked = ExtResource("{tex.index("checkbox_off") + 1}_checkbox_off")',
              "Label/colors/font_shadow_color = Color(0.094, 0.078, 0.145, 1)",
              "Label/constants/shadow_offset_x = 1",
              "Label/constants/shadow_offset_y = 1", ""]
    write(os.path.join(SPR, "ui", "ui_theme.tres"), "\n".join(lines))


def run():
    if not gen_sprites.MANIFEST:
        gen_sprites.run()
    for rel, meta in gen_sprites.MANIFEST.items():
        sprite_frames(rel, meta)
    for theme in gen_sprites.THEMES:
        tileset(theme)
    ui_theme()
    print(f"godot resources done: {len(gen_sprites.MANIFEST)} SpriteFrames, {len(gen_sprites.THEMES)} TileSets, 1 Theme")


if __name__ == "__main__":
    run()
