# Environment: structure targeting, click to choose, environmental beats

Round 50. Zak: "absolutely love the pinwheel! i think this should maybe be a bit easier to execute though. maybe just
an indicator to click on the structure for combos that require environment! oo, that seems like a fun bit to add in -
environmental combos!"

## What it does

- **Structure indicator.** A combo that uses a wall or pillar marks the structure it would use. The indicator is an
  inked target bracket in the ending's colour (chevrons marching in), a ring of inward chevrons round a pillar's foot,
  and a row of floor chevrons from the pile to the structure (the aim line). It appears when the window or wind-up
  opens and locks with a star flash on the press. It clears when the window closes with no press. When nothing is in
  reach, a dim dashed "too far" bracket goes on the nearest structure.
- **Click to choose.** In a window that can choose, the structure nearest the cursor's ray (or the right stick's
  direction, on a pad) becomes the pick. The window's own L / H press is the trigger, so "click the structure" means
  pressing L / H with the cursor on it. There is no new input. The default is the automatic pick (nearest in reach).
- **Pinwheel is easier.** Impale (Dash H H, `XK`) now has its own window, with the same pair as Backdraft: H Anvil and
  L Pinwheel. Old route: Dash H H, L (Backdraft), then L in Backdraft's window, three timed presses after the dash.
  New route: Dash H H, wait (no press before Impale's cancel), then L in the window. Backdraft keeps its window.
- **Environmental beats.** A thrown foe that hits a pillar cracks it (a drawn crack decal), shakes it and sheds three
  drawn chunks. A foe that hits a wall leaves a drawn mark in its element (crack, scorch, frost glaze, ink splat, bolt
  burn); the room keeps `MARK_CAP` of them and the oldest erodes away. A wall hit near a torch swings the torch.
- **Tentacle pillar slam.** Hold H through H H's grab next to a pillar (within `PILLAR_SLAM_REACH` of its face) and the
  tentacle smashes the foe into the pillar instead of the floor ahead. This is a route step, not a slot.

| Context (`CTX`) | Window / move | Colour row | Chooses | From | Reach |
|---|---|---|---|---|---|
| `pinwheel` | Backdraft's and Impale's window (Pinwheel, L) | wind | yes | the pile | `PINWHEEL_REACH` 10 m |
| `slapshot` | Harpoon's window (Slapshot, L) | earth | yes | the cubes' middle, along the dash | Slapshot's reach |
| `ricochet` | the counter's window | void | yes | the countered foe | `RICOCHET_REACH` |
| `collapse` | Singularity's window | void | yes | the hole | `COLLAPSE_REACH` 9 m |
| `meteor` | Undertow's window (Meteor Fall) | earth | yes (only a structure with palm foes on it) | the meteor's pile | `METEOR_NEAR` 4 m |
| `meteor` (foe mode, round 52) | Undertow's window with the palm foes in 2+ piles (`meteor_piles`): a **foe** | earth | yes (the palm foes) | him | auto: the foe nearest the default `meteor_spot` |
| `palm` | Molten Palm (EM) before its hit | earth | no | him, along his facing | the palm's carry |
| `leash` | Lava Leash (XL) before its hit | earth | no | the wall-splatted palm foes | `LEASH_NEAR` 2.5 m |
| `pillar_slam` | H H's grab with a foe held | void | yes (pillars only) | him | `PILLAR_SLAM_REACH` 4.5 m |
| `avalanche` | Deep Freeze's window (Avalanche, round 51) | water | yes | the cubes' tower | `AVALANCHE_REACH` 9 m |
| `overwhelm` | the charged hold (Overwhelm, round 51): a **foe** | void | yes (foes in `OVERWHELM_REACH`) | him | auto: the nearest in his aim |
| `abyss` | Overwhelm's window (Abyss, round 51): a **foe**, 2+ pinned | void | yes (the pinned) | him | auto: the biggest pinned |
| `eruption` | Meltdown's window (Eruption, round 52) | earth | yes | the landing (`_brk_zone`) | `ERUPT_REACH` 9 m |
| `tow` | Tow Line (Dash H) before its hit, 2+ snare candidates (`tow_candidates`): a **foe** | void | yes (`TOW_PICK_REACH` 7 m) | him | auto: the one nearest where they're yanked (`tow_auto`) |
| `flash_freeze` | Steam Burst's window (Flash Freeze, round 52): a **foe**, 2+ in the cloud | water | yes (foes in `FF_CLOUD_R`) | the landing | auto: the nearest the landing |

**Foe picks (round 51 cool pass).** Zak: "that environment select is AMAZING! maybe can incorporate that in select
combos where control makes sense." The same bracket goes on a foe where who matters: `context()` returns
`mode: "foe"` with the candidates (`foes`) and the default (`auto`); `resolve()` hands it to `_resolve_foe()`, which
makes each foe a round pick target (`foe_structs()`: kind `"foe"`, id `"foe<instance id>"`, `surface()` treats it
like a pillar) and lets the cursor (`FOE_SNAP` 1.2 m from its edge) or the stick choose among them. The bracket
follows the foe (`_draw_foe`: on its chest, `FOE_BRACKET_*`, grows with its radius; the floor ring under it; the
chevrons run from him to it on the charge). Gameplay reads `ENV.picked_foe(hero, ctx)` (the lock's foe, chosen or
auto) and keeps its own default when it's null (bare test rooms, no env):
- Overwhelm: once the hold is charged, the bracket is on who it will pin; the cursor on another foe switches it, and
  release pins that one even off his aim (`void_element.overwhelm_aim` is the default). The press that takes it is
  the attack starting (`_end`, key `charge:`).
- Abyss: with two or more pinned, the bracket in the hang is on who the deep gives back first and whole (the others
  share, `ABYSS_SHARE`); the default is the biggest (`void_element.abyss_first`).
- Flash Freeze (round 52): with two or more in the steam cloud, the bracket in the hang is on the shell his landing
  breaks first; the chain runs from it to the nearest unbroken shell each link, harder each, so the pick decides who
  takes the last link (`frost_shell.shatter(first)`). Eruption's pick is a structure (the wall or pillar it hurls into).
- Meteor Fall (round 52): with the palm foes in two piles or more, the bracket is on a foe of the pile he dives on;
  the cursor on a foe of another pile moves the dive there (`meteor_spot` keeps the picked foe's `METEOR_PILE_R`).
- Tow Line (round 52): the bracket is on who the line is yanked toward; only a cursor / stick choice changes the throw
  (`foe_chosen(by, ctx)`: the lock's foe when chosen, else null): the chosen foe is the anchor, snared where it stands
  (`TOW_ANCHOR_MULT`), and the rest are yanked into it.

## Files

- `scripts/env_target.gd`: the node (group `env_target`) that main.gd adds before the player. Registry
  (`add_wall`, `add_pillar`, `add_torch`), pure geometry (`surface`, `nearest`, `along`, `under_ray`, `along_stick`),
  `context()` (which ctx is live from the hero's state), `resolve()` (the auto pick, then the cursor / stick
  choice), the drawing (`_draw`, `_tone`), and the beats (`impact()`, `_pillar_hit`, `_wall_hit`, `_mark`,
  `_chunk`, `_swing_torch`). Its statics `pick(hero, ctx, from, reach)` and `chosen(hero, ctx)` are what gameplay asks.
- `tools/vfx_gen/gen_environment.py`: the sheets `env_bracket` (sprite, 8 frames: pop, 3-frame loop, lock star,
  lock break, dashed "too far", plain "available"), `env_ring` (ground), `env_chevron` (ground), `env_chunk` (sprite)
  and `env_mark` (ground, 6 frames: crack, scorch, frost glaze, ink splat, bolt burn, pillar crack). Output in
  `assets/vfx/designed/`. All are designed sheets on the palette ramp, with no polygons.
- `scripts/main.gd` `_build_arena`: registers the back, left and right walls (the near side is open floor on screen
  and is not registered), the torches and the pillars (`PILLAR_R`).
- `scripts/void_element.gd`: the `XK` breaker (Anvil / Pinwheel, `LEAP_AFTER_IMPALE`, `pause`). `pinwheel_target()`
  asks `ENV.pick` first and falls back to its raycast. `_slapshot` aims at `ENV.chosen(hero, "slapshot")`.
  `_collapse` throws non-heavy foes into the picked structure (`COLLAPSE_WALL_MULT` 1.6, `COLLAPSE_WALL_SPEED`),
  and keeps the old radial throw when no structure is picked. `meteor_spot` keeps foes near the chosen structure.
- `scripts/void_grab.gd`: the pillar slam (`_decide_pillar`, `PILLAR_SLAM_DAMAGE` 16, `PILLAR_SLAM_GAP`,
  `holds_for_slam()`, `pillar_slam_on()`, `pillar_slams`).
- `scripts/counter.gd` `ricochet_target`: through `pinwheel_target(..., "ricochet", RICOCHET_REACH)`; a chosen wall
  wins outright over a nearer foe.
- `scripts/camera_rig.gd` `_frame_fight`: in a hang, the indicator's structure (state "target") counts as a cued foe
  (`ENV_TARGET_Y`), so the bracket on the back wall is in view (it sat on the frame's top edge, half off).
- `scripts/thrown_foe.gd` `_burst`: a wall splat with no foe struck calls `ENV.impact()`.
- `scripts/training_bot.gd`: the `pillar` layout and token (by `main.PILLARS[0]`), the strings `pillar H hold`
  (the pillar slam) and `wall alt D H H` (Impale's window, Pinwheel), and the `[env]` line.

## How it works

1. Each physics frame (the node runs before the player), `context(hero)` reads the hero's state: a breaker leap in
   phase 0 with a ctx's ending on offer, or an attack before its hit. It returns {ctx, from, reach} or nothing.
2. `resolve()` takes the auto pick (`nearest`, or `along` for Slapshot and the palm), then `_choice()`: the test
   override (`test_cursor`, `test_stick`), the right stick when the mouse is not active, or the mouse ray through
   the camera (sampled at `CURSOR_HEIGHTS`, within `CURSOR_SNAP` of a structure in reach).
3. The pick is written on the hero as `PICK_META` {ctx, id, chosen, ms, key} every frame while live. The ending lands
   after the press (on the dive), so `pick()` reads this meta if it matches the ctx and is within `PICK_FRESH_MS`.
   With no env node in the tree (bare test rooms), `pick()` returns `{"none": true}` and callers keep their raycasts.
4. `_draw()` places the bracket (on a pillar's centre at `PILLAR_BRACKET_Y`, or `WALL_OUT` out of the wall face at
   `BRACKET_Y`), the floor ring round a pillar, and up to `CHEV_MAX` chevrons along the aim. `_process` steps the
   frames in real time (pop, loop, lock), so hitstop and slow motion do not freeze them.
5. When the context ends, `_end()` plays the lock if the press took it (leap phase 1, the move's hit, or
   `pillar_slam_on()`), and otherwise clears the indicator.
6. Beats: `thrown_foe._burst` (a wall splat, no foe struck) and the pillar slam call `impact(hero, at, dir, el)`,
   which finds the structure within `HIT_NEAR` and plays its beat.

## Invariants

- Gameplay never depends on the indicator being drawn. The pick lives in `pick()` / `chosen()`, which work headless.
- `pick()` with no env must return `{"none": true}`, so void_arm_check's bare rooms keep the raycast numbers.
- The press stays the trigger. A window still opens and fires with the cursor anywhere; the cursor only switches
  the target, and only to a structure within the move's reach.
- Impale's window is one of the 15 the grammar allows (`kit_check`). `pause` means a press before XK's cancel is
  still Backdraft (L), so the old strings keep working.

## Tuning

`env_target.gd` top: the reaches (`COLLAPSE_REACH`, `METEOR_NEAR`, `LEASH_NEAR`, `PILLAR_SLAM_REACH`), the choice
(`CURSOR_SNAP`, `STICK_CONE`, `PICK_FRESH_MS`), the look (`BRACKET_*`, `PILLAR_BRACKET_*`, `WALL_OUT`, `RING_PAD`,
`CHEV_*`, `FAR_ALPHA`, `FAR_ROW`) and the beats (`HIT_NEAR`, `MARK_CAP`, `CHUNKS`, `CHUNK_*`, `TORCH_*`,
`MARK_FRAME`). `void_element.gd`: `LEAP_AFTER_IMPALE`, `COLLAPSE_WALL_MULT`, `COLLAPSE_WALL_SPEED`. `void_grab.gd`:
`PILLAR_SLAM_DAMAGE`, `PILLAR_SLAM_GAP`.

## Extending

- A new move that uses a structure: add a row to `CTX`, a branch in `context()` that returns its `from` and `reach`,
  and have its gameplay ask `ENV.pick(hero, ctx, from, reach)` (with its own fallback when `none`).
- A new structure kind (a breakable crate, a ledge): register it with an `add_*` and give `surface()` its shape.
- A new room: call `add_wall` / `add_pillar` / `add_torch` for what it builds; nothing else changes. Since round 51
  rooms are data (`scripts/rooms.gd`) and `env_piece.gd` `place()` registers each piece (pillars, torches, and props
  through `add_prop`, a structure of its own kind that only a ctx with that `kinds` sees); see
  [env-pieces.md](env-pieces.md).
- Round 52 (env-pieces2): CTX `conduct` (torches conduct): in the storm windows (a breaker with `wire` or Short
  Circuit as its alt) and during Live Wire / Galvanize, `_conduct_ctx()` builds structures of kind `torch` from the
  conducting torches (`env_piece.conducting_torches()`), mode `torch` in `resolve()` takes the nearest, and `_draw()`
  puts the bracket on the torch's flame (`TORCH_BRACKET_SIZE` 1.8, `TORCH_BRACKET_UP` 0.55, no floor ring). Torches
  are still not in `structures`, so no other pick sees them. A room's rebuild rule is `rooms.gd` `ROOM_RULES`.

## Testing

- `tests/env_target_check.gd` (in `agent.sh check`): geometry and picks in a built room, the too-far case, the cursor
  and stick choice, `pinwheel_target` / Ricochet / Meteor with a lock, a live Pinwheel window drawing the bracket and
  aim line, Impale's window offering Anvil / Pinwheel, the beats (chunks, marks capped, torch swing), the pillar
  slam held and not held, and the foe picks (`_foe_picks`: the charged hold's bracket on the foe ahead, drawn on it,
  the cursor switching it, Overwhelm pinning the chosen one; Abyss's window, the cursor picking who comes up first).
- Film the foe picks: windowed `tests/target_film.gd [-- --dir=name --fps=24]` (the cursor stand-in moves mid-hold
  and mid-window) to `user://<dir>/target/`.
- The autotest prints `[env] shown= switches= locks= pillar_slams= pillar_hits= chunks= marks= torch_swings=`.
- Film: `tests/string_film.gd -- --from=N --to=N` on the strings `wall alt D H H` and `pillar H hold`.

## Gotchas / open questions

- The bot plays with the mouse inactive, so `switches=0` in the autotest. The cursor switch is checked in
  env_target_check through `test_cursor`.
- The palm's indicator shows the too-far bracket whenever he palms away from every wall. This may be noise; Zak's call.
- Meteor Fall's choice only takes a structure with palm foes near it, so the cursor can't send it to an empty wall.
