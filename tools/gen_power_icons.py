"""Writes the power icons to assets/icons/powers/<id>.svg and the run map's
room icons to assets/icons/rooms/<kind>.svg.

Each icon is a white glyph on a 64x64 grid; the game tints it with the
power's path colour (Upgrades.PATHS) and draws the frame round it
(scripts/power_ui.gd). Edit a glyph here, rerun, then
`godot --headless --import --path .` to reimport.

    python tools/gen_power_icons.py
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "powers")
ROOMS_OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "rooms")
SIZE = 128  # rasterised size in Godot (the SVG's width/height)

S = 'fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#fff"'

ICONS = {
    # --- Light ---
    "bloodthirst": f'<path {F} fill-rule="evenodd" d="M32 6 C26 16 14 28 14 40 A18 18 0 0 0 50 40 C50 28 38 16 32 6 Z '
                   f'M24 40 A8 8 0 0 0 30 48 L28 52 A12 12 0 0 1 20 40 Z"/>',
    "rising_edge": f'<path {S} d="M12 54 Q14 24 46 12"/><path {S} d="M36 8 L48 11 L44 23"/>'
                   f'<path {S} d="M26 56 H40"/>',
    "ember_cleave": f'<path {F} fill-rule="evenodd" d="M32 4 C38 16 50 24 47 40 C45 52 38 58 32 58 C23 58 16 51 16 42 '
                    f'C16 32 23 28 26 17 C30 25 33 27 34 33 C38 28 38 20 32 4 Z '
                    f'M32 54 C27 54 24 50 25 45 C26 40 30 38 31 33 C35 39 40 43 38 49 C37 52 35 54 32 54 Z"/>',
    "quickblade": f'<path {F} d="M52 6 L58 12 L30 40 L24 34 Z"/><path {S} d="M20 32 L32 44"/><path {S} d="M24 40 L12 52"/>'
                  f'<path {S} d="M6 20 H20"/><path {S} d="M4 30 H14"/>',
    "thousand_cuts": f'<path {S} d="M12 34 L34 12"/><path {S} d="M18 46 L46 18"/><path {S} d="M30 52 L52 30"/>',
    # --- Heavy ---
    "whirlwind": f'<path {S} d="M8 12 Q32 20 56 12"/><path {S} d="M14 24 Q32 31 50 24"/><path {S} d="M20 36 Q32 42 44 36"/>'
                 f'<path {S} d="M26 48 Q32 51 38 48"/><path {S} d="M31 58 H33"/>',
    "skybreaker": f'<path {S} d="M32 50 V10"/><path {S} d="M19 23 L32 10 L45 23"/><path {S} d="M8 56 H24"/>'
                  f'<path {S} d="M40 56 H56"/><path {S} d="M14 46 L8 40"/><path {S} d="M50 46 L56 40"/>',
    "fault_line": f'<path {S} d="M6 36 L18 32 L25 40 L35 29 L42 37 L58 31"/><path {S} d="M6 50 H58"/>'
                  f'<path {S} d="M25 22 V14"/><path {S} d="M35 18 V8"/><path {S} d="M45 22 V16"/>',
    "quake": f'<path {S} d="M32 6 V26"/><path {S} d="M24 18 L32 26 L40 18"/><path {S} d="M6 54 H58"/>'
             f'<path {S} d="M18 54 A14 14 0 0 1 46 54"/><path {S} d="M8 46 A26 22 0 0 1 56 46"/>',
    "bone_breaker": f'<path {S} stroke-width="8" d="M18 18 L27 27"/><path {S} stroke-width="8" d="M37 37 L46 46"/>'
                    f'<circle {F} cx="12" cy="20" r="6"/><circle {F} cx="20" cy="12" r="6"/>'
                    f'<circle {F} cx="44" cy="52" r="6"/><circle {F} cx="52" cy="44" r="6"/>'
                    f'<path {S} stroke-width="3" d="M26 40 L31 33 L29 31 L36 24"/>',
    "shatter": f'<circle {F} cx="32" cy="32" r="6"/><path {F} d="M32 3 L37 20 L27 20 Z"/><path {F} d="M61 32 L44 37 L44 27 Z"/>'
               f'<path {F} d="M32 61 L27 44 L37 44 Z"/><path {F} d="M3 32 L20 27 L20 37 Z"/>'
               f'<path {F} d="M53 11 L45 25 L39 19 Z"/><path {F} d="M11 53 L19 39 L25 45 Z"/>'
               f'<path {F} d="M53 53 L39 45 L45 39 Z"/><path {F} d="M11 11 L25 19 L19 25 Z"/>',
    # --- Dash ---
    "static_step": f'<path {F} d="M37 4 L14 36 H30 L26 60 L50 26 H34 Z"/>',
    "momentum": f'<path {S} d="M26 32 H54"/><path {S} d="M42 20 L54 32 L42 44"/><path {S} d="M6 22 H22"/>'
                f'<path {S} d="M10 32 H18"/><path {S} d="M6 42 H22"/>',
    "riposte": f'<path {S} d="M14 50 L46 18"/><path {S} d="M50 50 L18 18"/><path {S} d="M8 42 L22 56"/>'
               f'<path {S} d="M42 56 L56 42"/><path {F} d="M46 18 L54 8 L56 10 Z"/><path {F} d="M18 18 L10 8 L8 10 Z"/>',
    "razor_gale": f'<path {F} d="M12 52 L17 10 L24 44 Z"/><path {F} d="M12 52 L44 17 L29 47 Z"/>'
                  f'<path {F} d="M12 52 L56 40 L31 53 Z"/>',
    "eye_of_storm": f'<path {S} d="M32 30 C36 28 39 34 35 37 C29 41 22 35 25 27 C29 18 43 18 46 29 '
                    f'C49 41 38 52 26 50 C14 48 7 36 12 22"/><path {S} d="M6 26 L12 22 L17 27"/>',
    "slipstream": f'<path {S} d="M6 34 H56"/><path {S} d="M46 24 L56 34 L46 44"/><path {S} stroke-width="4" d="M26 14 L34 54"/>'
                  f'<path {S} stroke-width="3" d="M8 24 H20"/><path {S} stroke-width="3" d="M8 44 H20"/>',
    # --- Awaken ---
    "overflow": f'<path {S} d="M16 30 L32 16 L48 30"/><path {S} d="M16 42 L32 28 L48 42"/><path {S} d="M16 54 L32 40 L48 54"/>'
                f'<path {S} d="M32 6 V8"/>',
    "phoenix_heart": f'<path {F} fill-rule="evenodd" d="M32 56 C10 40 5 29 9 20 C13 10 28 9 32 20 C36 9 51 10 55 20 '
                     f'C59 29 54 40 32 56 Z M32 46 C26 42 25 35 30 28 C31 32 33 34 34 31 C38 35 39 41 32 46 Z"/>',
    "eruption": f'<circle {F} cx="32" cy="34" r="9"/><path {S} d="M32 6 V16"/><path {S} d="M32 52 V58"/>'
                f'<path {S} d="M8 34 H16"/><path {S} d="M48 34 H56"/><path {S} d="M14 14 L20 20"/><path {S} d="M50 14 L44 20"/>'
                f'<path {S} d="M14 54 L20 48"/><path {S} d="M50 54 L44 48"/>',
    # --- Soul ---
    "chain_spark": f'<circle {F} cx="11" cy="48" r="6"/><circle {F} cx="32" cy="14" r="6"/><circle {F} cx="53" cy="44" r="6"/>'
                   f'<path {S} stroke-width="4" d="M14 42 L22 34 L19 29 L28 20"/><path {S} stroke-width="4" d="M37 19 L42 30 L40 34 L49 40"/>',
    "second_wind": f'<path {S} d="M32 30 C22 22 24 7 32 7 C40 7 42 22 32 30 Z"/><path {S} d="M16 34 H48"/><path {S} d="M32 30 V58"/>',
    "reaper": f'<path {S} d="M22 58 L42 8"/><path {F} d="M42 8 C32 2 14 4 5 18 C17 13 28 13 39 17 Z"/>',
    # --- Fusions ---
    "crescendo": f'<rect {F} x="8" y="42" width="12" height="16" rx="2"/><rect {F} x="26" y="28" width="12" height="30" rx="2"/>'
                 f'<rect {F} x="44" y="10" width="12" height="48" rx="2"/>',
    "flicker": f'<path {S} stroke-dasharray="5 7" d="M6 42 L34 14"/><path {S} d="M20 54 L50 24"/>'
               f'<path {F} d="M50 24 L58 12 L60 14 Z"/><path {S} d="M16 46 L28 58"/>',
    "shockstep": f'<ellipse {F} cx="32" cy="24" rx="9" ry="13"/><circle {F} cx="32" cy="45" r="6"/>'
                 f'<path {S} d="M14 56 Q5 34 14 12"/><path {S} d="M50 56 Q59 34 50 12"/>',
    "undying_flame": f'<path {S} d="M5 32 Q32 6 59 32 Q32 58 5 32 Z"/>'
                     f'<path {F} d="M32 18 C38 26 41 32 37 40 C35 44 29 44 27 40 C25 34 30 30 32 18 Z"/>',
}


# Run map rooms (RunMap.KINDS), tinted by map_screen.gd.
ROOMS = {
    "fight": f'<path {F} d="M52 6 L58 6 L58 12 L28 42 L22 36 Z"/><path {S} d="M16 34 L30 48"/><path {S} d="M22 42 L10 54"/>',
    "elite": f'<path {F} fill-rule="evenodd" d="M32 12 C18 12 12 21 12 31 C12 38 16 42 20 44 L20 52 L44 52 L44 44 '
             f'C48 42 52 38 52 31 C52 21 46 12 32 12 Z M24 23 A5 5 0 1 0 24 33 A5 5 0 1 0 24 23 Z '
             f'M40 23 A5 5 0 1 0 40 33 A5 5 0 1 0 40 23 Z"/>'
             f'<path {S} d="M14 18 L6 6"/><path {S} d="M50 18 L58 6"/>',
    "rest": f'<path {F} d="M32 8 C38 18 44 22 42 32 C41 38 36 41 32 41 C26 41 22 37 22 31 C22 25 27 22 28 15 '
            f'C31 20 33 22 33 26 C36 22 36 15 32 8 Z"/><path {S} d="M12 56 L52 44"/><path {S} d="M12 44 L52 56"/>',
    "shrine": f'<path {S} d="M10 56 H54"/><path {S} d="M16 56 V40 H48 V56"/><rect {F} x="28" y="22" width="8" height="18" rx="2"/>'
              f'<path {F} d="M32 6 C36 12 37 15 35 18 C34 20 30 20 29 18 C27 15 29 12 32 6 Z"/>',
    "vault": f'<path {S} d="M10 30 H54 V54 H10 Z"/><path {S} d="M10 30 C10 16 20 12 32 12 C44 12 54 16 54 30"/>'
             f'<rect {F} x="27" y="26" width="10" height="12" rx="2"/>',
    "trial": f'<path {S} d="M16 6 H48"/><path {S} d="M16 58 H48"/>'
             f'<path {S} d="M20 6 C20 22 30 26 32 32 C34 26 44 22 44 6"/><path {S} d="M20 58 C20 42 30 38 32 32 C34 38 44 42 44 58"/>'
             f'<path {F} d="M24 56 C26 48 30 46 32 44 C34 46 38 48 40 56 Z"/>',
    "boss": f'<path {F} fill-rule="evenodd" d="M32 18 C18 18 12 27 12 37 C12 44 16 48 20 50 L20 58 L44 58 L44 50 '
            f'C48 48 52 44 52 37 C52 27 46 18 32 18 Z M24 29 A5 5 0 1 0 24 39 A5 5 0 1 0 24 29 Z '
            f'M40 29 A5 5 0 1 0 40 39 A5 5 0 1 0 40 29 Z"/>'
            f'<path {F} d="M14 16 L20 4 L26 12 L32 2 L38 12 L44 4 L50 16 Z"/>',
}


def write(icons: dict, out: str) -> None:
    os.makedirs(out, exist_ok=True)
    for name, body in icons.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 64 64">'
               f'{body}</svg>\n')
        with open(os.path.join(out, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
    print(f"wrote {len(icons)} icons to {os.path.normpath(out)}")


def main() -> None:
    write(ICONS, OUT)
    write(ROOMS, ROOMS_OUT)


if __name__ == "__main__":
    main()
