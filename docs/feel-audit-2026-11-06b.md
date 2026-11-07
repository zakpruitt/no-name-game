# Feel audit 4, 2026-11-06 (feel-polish: audit 3's open non-anim items, then the whole game on film)

Zak played the build after [audit 3](feel-audit-2026-11-06.md) ("phenomenal" wind and lightning, loves the ice block,
no ice crystals anywhere) and said "keep improving on whatever you see fit". This lane took audit 3's open items that
are not animation re-keys (6, 8, 9 and the spear vault's missing stop), then filmed every `training_bot.BOT_STRINGS`
string again (32 now, with the Harpoon ring / wall strings and the Galvanize / charged strings) and fixed what was
new and timing, camera, clutter or readability.

Method as audit 3: windowed `tests/string_film.gd -- --dir=feel4_a --from=0 --to=9`, `feel4_b --from=10 --to=19`,
`feel4_c --from=20` (32/32 strings, 0 ERROR lines), one PIL sheet per string (every frame, labelled from INDEX.txt),
headless `--autotest` and `tests/rhythm_check.gd` for the numbers. Before films of strings 5-11 on dev 9d08b44
(`fp_before`), after films on this lane (`fp_after1`, `feel4_*`). Sheets and films are in the session scratchpad
(`scratchpad\fp\`), not committed. Before / after for Zak: `Desktop\awaken-combo-clips\28 Feel *`.

## Fixed (before / after from film)

1. **Meteor Fall's wall splat in the top-left corner (audit 3 item 6).** Before (L L L H H, `fp_before` 033-046):
   the dummy Molten Palm carried to the back wall sat in the corner, half off frame, through Undertow and the whole
   hang. Cause: the hang turned the fight framing off. Fix: Molten Palm cues a foe it carries to a wall
   (`void_element.PALM_CUE_MS` 2600 real ms on `camera_rig.FRAME_CUE`), and `_frame_fight()` still runs in a hang for
   cued foes only, out to `FRAME_CUE_RANGE` 17 m, at `FRAME_CUE_OUT` with the cue lean cap. A foe merely hit still
   leaves him centred in a hang (the calm pass; `camera_feel_check` PASS). After (`fp_after1` 036-046, `feel4_b`
   L_L_L_H_H 036-046): the splatted dummy and its ring sit whole inside the frame, ~1/4 in from the left, through the
   hang and the dive. Left: for ~0.25 s after the splat (Undertow's start, 033-035) it is still at the edge while the
   view eases out. Clip: `28 Feel Meteor Fall splat framed in the hang (left before, right after, half speed).mp4`.
2. **The frost spear's 5 m frost floor (audit 3 item 8).** Before (L L H L H, `fp_before` 018-019): the `ice_frost`
   floor grew to a pale disc of cracks and teeth across a third of the frame under the dummies. Fix (`frost_spear.gd`,
   designed mode): no floor quad; the plant is a ground stamp, a `designed_ink.shock` brush ring 1.25 m out and
   `frost_mark` cracks (`STAMP_MARK` 1.5, ~2.5 m across), gone in about half a second. No crystals. The slow still
   reaches `RADIUS` 6 m; the standing spear is the tell. After (`fp_after1` / `feel4_a` 011-019): a small crack star
   at the spear, a clean floor through the vault and Deep Freeze's wind-up. (`designed_elements.frost_floor` /
   `frost_step` are now unused; fx-elements' file, left in place.)
3. **The spirit echo's fan (audit 3 item 9).** The brown halftone fan audit 3 saw (`feel3_all` L_L_H_L_H 005-010)
   was already gone on dev; what was left was the echo's stroke at the cast's full 3.4-3.9 m reach, lingering through
   the hitstop into the next move's wind-up (Awakened: a gold crescent bigger than his own arc, `fp_before`
   L_L_H_L_H 005, 009-010, and the drawn axe head left at the arc's end 010-013). Fix (`designed_finish.gd` echo,
   `spirit_echo.gd`): drawn at `ECHO_DRAW` 0.62 of the reach (the hit reach is unchanged), the axe head 1.4 m (was
   2.3), the line a thin void-ink stroke, both on real time (`ECHO_REAL` 0.2 s; `designed_fx.slash` takes an
   optional `real` flag), so they are gone before the next hit. After (`fp_after1` L_L_H_L_H 005-011): no crescent
   past the pile, no axe head left behind.
4. **The spear vault (IJ) had no stop.** Before: HIT frame at x1.00 (`fp_before` L_L_H_L_H 016). Fix: the push-off
   on the spear takes `void_element.VAULT_STOP` 0.06 at the freeze scale (eased tail), between Frost Spear's plant
   (IP 0.07) and Deep Freeze (IS 0.1), and `VAULT_SHAKE` 0.2. After: x0.03 on the HIT frame and the next
   (`feel4_a` L_L_H_L_H 015-016). Rhythm: IP -> IJ 386 -> 380 ms, IJ -> IS 317 -> 338 ms. (`hero_moves.MOVES.IJ.stop`
   still reads 0.0 in rhythm_check's table: the vault's stop is in `_fire`, since it hits nobody.)
5. **New: Harpoon's latches had no stop.** Seen on every Harpoon string's Ice Cube frame (`feel4_a` D_L_H_H 023,
   `feel4_b` D_L_H_H_L 023, line_D_L_H_H_H_L 025: EA HIT at x1.00 while the gather's tentacles latch, 10 damage each).
   Fix: the first latch of a gather stops `LATCH_STOP` 0.035; the rest stay quiet (a stop on every latch made EA ->
   XG 200 -> 256 ms). After (`fp_latch` D_L_H_H_L 015-016): x0.03. EA -> XS 200 -> 221 ms, EA -> XG 200 -> 235 ms.

## Numbers (headless, this lane)

```
[autotest] done ... breakers=12/12 perfect_breakers=18 strings=32/32 endings=Grounded,Collapse,Maw,Worldbreaker,Shatterstorm,Avalanche,Abyss,Meteor_Fall,Cataclysm,Flash_Freeze,Black_Ice,Eruption,Anvil,Short_Circuit,Slapshot
[improv] frozen_x_void=3, buried_x_water=3, airborne_x_water=3, molten_x_wind=2, bound_x_wind=1, charged_x_wind=1, charged_x_void=3, charged_x_earth=3, charged_x_water=4
rhythm_check: PASS
```

Galvanize (`spread H L L`): GR -> VR 200 ms, VR -> XC 352 ms; beats GR 120, VR 282, XC 282 ms (rhythm_check: XC hit
125, cancel 401 / 263, end 501 ms, stop 0.030). After it the next press comes 469-662 ms after XC starts (`wait`
strings: XC -> L1 469 / 483 / 648, XC -> GR 662), and the L1 after it starts before the discharge lands
(`feel4_c` spread_H_L_L_wait_L_H 019-023), so it never locks him.

Harpoon's gather (`ring D L H`, `wall alt D L H`): DL -> EF 283 ms both, EF beat 297-304 ms (rhythm_check: EF hit
245, cancel 361 / 303, end 520 ms, stop 0.070). With Ice Cube after it: EF -> EA 310-317 ms, EA -> XS 221, EA -> XG
235 ms. The slowest hand-overs are unchanged: L3 -> EM 435-531 (audit 3 item 7, a re-key), EF -> TW 531.

Effect coverage (`python tests/fx_coverage.py <film> --max=0.40`): feel4_a 33 HIT frames mean 0.071 max 0.162,
feel4_b 43 mean 0.079 max 0.143, feel4_c 60 mean 0.081 max 0.163; PASS (audit 3: mean 0.072, max 0.224).

## Seen on the full film, left open

- **Live Wire's hang with a far foe** (`feel4_c` spread_far_alt_L_H_H 019-026): the lime current to the dummy past
  the tentacles runs off the left edge for the whole hang. Short Circuit's arcs land in frame (audit 3 item 5), but
  the hang does not show who they will go to. Now that cued foes count in a hang, cueing Short Circuit's prospective
  targets at the hang's start would frame them; left, since it leans the camera in every Live Wire hang with a foe
  out of reach, Grounded included (Zak's call).
- **Harpoon / Ice Cube rows at the left edge** (`feel4_a` D_L_H 023-031, D_L_H_H 024-029): the leftmost cube of a
  four-cube row sits on the frame edge in the hang and as Ice Cube bowls it. Small; a `FRAME_CUE` on the bowled cube
  (like Slapshot's `SLIDE_CUE_MS`) is the fix if it matters.
- **Ice Cube during the gather.** On Harpoon strings the Ice Cube press lands while the tentacles are still carrying
  (`THROWN.flying`), so `_ice_cube` finds nobody and the cubes are Harpoon's own; Hailstorm / Steam Burst follow
  normally. Combo-harpoon lane's call whether Ice Cube should wait for the set.
- GALVANIZE's name sits on him through the charge (audit 3, left). Ice blocks read large (2.2 m on a dummy; Zak's
  open question from fx-ice2). L3 -> Molten Palm (audit 3 item 7) needs the re-key.
- No crystals seen anywhere in the 32 strings; no new pose pops.
