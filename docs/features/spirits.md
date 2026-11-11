# Spirits

## What it is

A spirit is a small floating creature that carries one element: storm, ice or magma. The heretic holds one at a
time. With none he has the base kit; holding one opens that element's moves. This is a first test of the idea in
the training room, not the run's reward system.

## How it plays

- The training room has three spirits hovering behind the hero's start. Walk up to one: a `[E]` prompt shows.
  Press `E` (gamepad B): the bond prompt opens and the game pauses. It asks "Bond with the STORM SPIRIT?" with the
  name in the element's colour, then lists what comes with it: the combos it opens (input, name, slot tag), their
  breakers (each ending in the colour of the element it lands in) and its passive. **Bond** claims it; **Not now**,
  Esc or gamepad B closes. Once claimed it floats along over his right shoulder.
- Claiming another swaps: the one he held goes back to its spot.
- **No spirit**: the light string (`L`, `L L`, `L L L`), the grab and the dark moves (Reap, Singularity, Drag,
  Overwhelm), Dash Stab, Tow Line, the counter and the Awakening. An element ender's press (`L H`, `L L H`,
  `L L L H`) falls back to the grab.
- **Storm**: Updraft (`L H`), Tempest, the air route and Sky Rend, and Dark x storm.
- **Ice**: Frost Spear (`L L H`), the vault and Deep Freeze, Ice Cube (`Dash L H`) and its step, Impale
  (`Dash H H`) and Backdraft.
- **Magma**: Molten Palm (`L L L H`), Cataclysm and Lava Leash.
- A crossover of two elements (Fault Line, Hailstorm, Steam Burst) needs both, so one spirit never opens it.
- The spirit only follows. It does not fight.

## How it works

- `scripts/spirits.gd` (`Spirits`): `held`, `claim()`, and `allows(id)`: a move is allowed when every element it
  needs (`needs(id)`: a crossover's `pair` from `KitSlots`, else `void_element.ELEMENT_OF`) is dark or the held one.
- `KitSlots.open(id)` asks `Spirits.allows(id)` first, so `hero_moves.void_route()` goes past a closed move exactly
  as it goes past a demoted one. `hero_moves.routed()` asks it for the vault. The combo guide asks `void_route()`,
  so it shows only what the press will do.
- `scripts/spirit_companion.gd`: one node per spirit. `place()` (from `main._start_training`, only when the kit is
  gated) puts the three at `SPOTS`; each scales its model to `SIZE`, bobs, shows its prompt within `REACH`, and
  follows at `RIDE` once claimed.
- `scripts/bond_prompt.gd` (a `menu_screen.gd`): `ask(element, on_yes)` builds the panel from
  `Spirits.offers(element)`. `offers()` walks the card's fill and route steps for the moves `opens(id, element)`
  (closed with none, open with that spirit alone), and takes each one's endings from `void_element.BREAKERS`
  (`names`, then `alt`), so a new move or breaker shows up with no row to add here. A swap adds a line naming the
  spirit he gives up. `place()` makes one prompt for the three spirits.
- The passive line is `Spirits.PASSIVES[element]`; all three are empty, so the prompt says "None yet." Writing a
  line there only changes the text: the effect itself still has to be built.
- Models: `assets/comic/spirits/<storm|ice|magma>.glb`, unrigged Meshy models brought in with
  `python tools/meshy/meshy.py spirit <name> <model.glb>` (it only renames the material to `P_MeshyPaint`).

## Flags

| Flag | What |
|---|---|
| (none) | play: no spirit, the three to claim |
| `--spirit=storm` / `ice` / `magma` | start holding that one |
| `--spirit=all` | the whole kit, no spirits in the room (how it played before) |

Every `-s` test and the autotest run with everything open, so the checks still play all the strings.

## Check

`tests/spirit_check.gd` (`[spirit] PASS`): what each press routes to with none, each one, and everything; what
`offers()` lists for each spirit; and that the prompt pauses, Bond claims and closing claims nothing.

## Not built

- The pause menu's MOVES panel still lists every move, open or not.
- The light string keeps its three element tints with no spirit held.
- No effect when a spirit is claimed beyond its element's sound, and the spirit takes no part in breakers.
- Nobody has tuned the follow spot, size or bob by eye.
- No spirit has a passive yet (`Spirits.PASSIVES`).
- The bond prompt has only been run headless: nobody has looked at its layout on screen.
- Storm's list leaves out the air climb (`L H L`, `AL1`): it has no element in `ELEMENT_OF`, so `opens()` skips it.
