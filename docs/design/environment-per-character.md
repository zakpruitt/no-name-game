# Environment per character (design proposal)

Zak, 2026-11-07, after Pinwheel (the kebab hurled into a wall) and asking for structure indicators: "spin up a
design agent on how we can incorporate environment more into what the characters are doing. I want to ideally give
each character a few environmental aspects only they can interact with." The game around it is the roguelike in
[kit-grammar.md](../characters/kit-grammar.md): every character fills the same ten-slot card, runs upgrade slots,
passives raise elements and states. Environmental combos are "a fun bit", not a second combat system.

Status: items 0-5 of the build order are built (items 0-4 in round 51, env-pieces lane; item 5, torches_conduct,
in round 52, env-pieces2, as an always-on storm verb rather than a `Kit.has()` upgrade, with the Frost Wall's x1.6
Shatter and a per-room `rebuild` rule in `rooms.gd`: open question 2's answer as data, training rebuilds, real rooms
don't): see
[env-pieces.md](../features/env-pieces.md) for what shipped and where it differs from this page, and
[environment-lore.md](environment-lore.md) for the world behind it. The rest is a
proposal. It builds on what is on dev at c2ba15f (wall splat and `WALL_META`, Meteor Fall's
wall preference, Pinwheel / Slapshot / Ricochet / Collapse throwing into walls and pillars, pillars as R anchors that
shake on landings) and on the round 50 environment lane, in progress in `awaken-environment` and not landed yet:
`scripts/env_target.gd` (one node that knows the room's structures: `add_wall()`, `add_pillar()`, `add_torch()`;
`CTX` per window; the structure indicator; click to choose with `pick()` / `chosen()`; `impact()` beats: pillar
cracks and chunks, wall marks, torch swings) and the pillar slam (H held through the grab's haul next to a pillar, a
route step of H H). If that lane's `docs/features/environment.md` lands with other names, follow its names; the
design here does not depend on them.

## 0. The rules, short

1. **Pieces are nouns everyone shares; verbs are per character.** Every piece has one shared rule that any
   character's hit triggers (a thrown foe breaks a crate for anyone). The exclusive verbs come from the character's
   signature and elements.
2. **Pieces answer to an element, not to a state.** A grate electrifies on a *storm* hit, not on any hit that
   leaves charged. That is what makes them exclusive: the Dragon Prince has no storm, so a grate is floor to him.
   What a piece then *leaves on foes* is always one of the six states, so passives ("+20% molten payoffs") still
   reach it on every character.
3. **No new inputs.** Every exclusive interaction is one of four kinds: a window's **L ending** (the environmental
   ending, the existing convention), a **target preference** of an existing move or ending (Meteor Fall already
   prefers the wall-splatted foe), a **route step** (the pillar slam is the pattern), or a **piece rule** (what an
   element's hit does to a piece). The structure indicator and click to choose are the only UI.
4. **One headline per colour, at most four per character.** One headline for the signature and one per element, at
   most. Everything else is a flourish, and flourishes are run upgrades (`Kit.has()`), not base kit.
5. **A used-up piece stays used up for the room** (a toppled pillar is rubble, a burst barrel is gone). Using the
   room is a decision. The training room rebuilds pieces (section 4).
6. **A piece never makes a slot bigger everywhere.** An environmental ending wins its best situation by the margin
   breaker pairs use (void_arm_check `_breaker_pairs()`: wins there, loses in its worst), no more.

## 1. Environment vocabulary

A room is built from these pieces and nothing else. Art column: **have** = a comic piece in `assets/comic/dungeon/`
today; **kit** = a new comic piece from `vendor_src/shaman_redesign/comic_poc/env_kit.py` (the `comic-asset-kit`
skill), with KayKit's `vendor_src/KayKit-Dungeon-Remastered-1.0` version as the shape reference where one exists.

| # | Piece (tag) | Shared rule (every character) | States | Art |
|---|---|---|---|---|
| 1 | **wall** (`wall`) | Wall splat: a thrown foe that meets it takes `wall_mult` and gets `WALL_META` (Meteor Fall goes for it); Pinwheel, Slapshot, Ricochet and Collapse aim at it; `env_target` marks it per element | none (marks are looks) | have (`wall`, `wall_broken`, `wall_arched`, `wall_corner`) |
| 2 | **pillar** (`pillar`) | Everything a wall does, plus the traversal anchor (`grab_anchors`); shakes on landings within 8 m; the pillar slam route step | **whole** / **cracked** (3 splats) / **toppled** (a rubble line along its fall, 4 m) | have; toppled = the pillar laid down plus `rubble_half` (reuse); a fallen-column piece later (kit) |
| 3 | **torch** (`torch`) | Light; swings when a foe splats on the wall under it (`env_target._swing_torch`) | **lit** / **out** | have (`torch_mounted`) |
| 4 | **brazier** (`brazier`) | Floor fire bowl, 1 m. A thrown foe knocks it over: a 2 m fire patch for 3 s that leaves **molten** on foes in it | **lit** / **out** / **spilled** | kit (no brazier in either pack; `candle_lit`'s flame in env_kit.py is the start) |
| 5 | **barrel** (`barrel`) | A thrown foe breaks it: a splat at half `wall_mult`, staves fly, gone | **whole** / **burning** / gone | have (`barrel_large`, `barrel_small`) |
| 6 | **crate** (`crate`) | A thrown foe, or a breaker landing within 1.5 m, breaks it; in runs it drops a pickup | **whole** / gone | have (`crates_stacked`, `box_large`) |
| 7 | **chest** (`chest`) | Heavy: a wall for splats, never breaks; opens when the room is cleared (run reward) | **shut** / **open** | have (`chest_gold`) |
| 8 | **banner** (`banner`) | Hangs on a wall; a foe splatted through it tears it down (a look) | **hanging** / **torn** / **burning** | have (`banner_patternA_red`) |
| 9 | **grate** (`grate`) | Metal floor tile; drains a pool beside it; otherwise floor | **cold** / **live** / **frosted** | have (`floor_tile_big_grate`; placed by data, not `randf() < 0.08`) |
| 10 | **spikes** (`spikes`) | A foe that lands on it from airborne or a throw takes x1.5 on the landing and stops dead (no skid) | **up** / **down** (a room may cycle them, 2 s each) | have (`floor_tile_big_spikes`) |
| 11 | **rubble** (`rubble`) | Low; foes walk round it; a breaker landing on it throws chunks (`env_chunk`) for a small splash | none | have (`rubble_half`, `floor_tile_large_rocks`) |
| 12 | **pool** (`pool`) | Water, 3-4 m across: foes in it move at 0.8, and molten on them ends (quenched) | **water** / **frozen** / **live** / **steam** (2 s) | kit (a flat inked water piece; no mesh in either pack) |
| 13 | **hook** (`hook`) | Chains and hooks on a wall segment: a wall for everyone | **empty** / **hung** | kit (chains drawn with env_kit.py strokes) |
| 14 | **ledge** (`ledge`) | A walkway along a wall 2.5 m up, nobody stands on it; its face is a wall | none | kit (KayKit `wall_scaffold` / `stairs_walled` as reference) |

Wall and pillar are one family in `env_target` (structures); spikes, pools and ledges are room features; the rest are
props.

States on pieces:

- A piece holds one state at a time, set by an element's hit, and it times out (`live` 3 s, `burning` 1.2 s then
  burst, `frosted` 6 s, `steam` 2 s). `toppled`, gone, `torn`, `open` are permanent for the room.
- A piece's state passes to foes the shared way: a foe on a **live** grate is charged, one in a **spilled**
  brazier's patch molten. The foe's state then pays by the existing rule (`void_element.RULES`).
- The tell is on the piece: the `designed_polish` loops (`arc_crawl`, `tell_molten`) and the frost floor drawn on
  the piece instead of a foe. Reuse, no new sheets for the states.

### How a room is authored

Data, not code:

- `scripts/env_piece.gd` (`EnvPiece`): `PIECES := {tag: {"models": [...], "collider": "box" | "cyl" | "none",
  "size": ..., "wall": bool, "breaks": bool, "states": [...], "first": "lit"}}` and `place(room, tag, at, yaw,
  state)`, which builds the piece with `ComicLook.piece()`, adds it to the groups `env` and `env_<tag>`, sets the
  `env_state` meta, and registers it with `env_target` (walls, pillars, chests, ledges as structures; the rest as
  props). `EnvPiece.near(tree, tag, at, r)` is the `FOES.near()` of pieces. `EnvPiece.hit(piece, el, by)` is the one
  entry every element hit calls; it looks up `RULES_BY_ELEMENT[el][tag]`.
- `scripts/rooms.gd`: `ROOMS := {"training": [{"tag": "pillar", "at": Vector3(-8, 0, -8)}, ...], ...}`.
  `main._build_arena()` keeps building the floor and walls, then places `ROOMS[room]`. Today's four `PILLARS`, three
  torches, three banners and the corner clutter move into `ROOMS.training` unchanged, so the room looks the same
  until a lane adds a piece.
- `EnvPiece.EXCLUSIVE := {hero_id: {tag: [interaction ids]}}`. The structure indicator only marks pieces the current
  hero has a verb for (and walls and pillars, which everyone uses), so the room reads differently per character: a
  grate glows under the heretic's indicator and is plain floor under the prince's.

## 2. Character-exclusive interactions

### The heretic (void tentacle; storm, ice, magma)

Headlines, one per colour:

| Id | Colour | Piece | What happens | Best situation |
|---|---|---|---|---|
| **Uproot** | dark | pillar | Abyss's L ending. Instead of sinking the pinned big foe, the tentacle wraps the nearest pillar within 6 m, tears it out and brings it down on the foe like a club, along the line pillar -> foe: the foe is cratered (buried), everyone within 1.5 m of the 4 m fall line takes 0.6 of it and is buried, and the pillar is rubble for the rest of the room. Word: KRR-RACK-THOOM! | A big foe within 6 m of a pillar with others near the line. In the open there is nothing to tear: L plays a short sky-swing slam for less, and Abyss wins. Costs his R anchor. |
| **Live Floor** | storm | grate | A storm hit on a foe standing on a grate, or Live Wire's pulse reaching one, makes the grate **live** for 3 s: anyone on it is charged every 0.5 s, and Short Circuit's arcs may start from any foe on it (its 12 m reach measured from the grate). | A crowd on or crossing a grate: Live Wire beats Galvanize there; Galvanize keeps the spread crowd off it. |
| **Frost Wall** | ice | grate | Frost Spear (L L H) planted on or within 1 m of a grate raises an ice wall along the grate's far edge, 4 m wide, 2.5 m tall, for 6 s (the `ice_facet` shader, the fitted-block look). It is a real wall: `thrown_foe.clear_from` hits it, it takes splats and sets `WALL_META`, Pinwheel / Slapshot / Ricochet / Meteor Fall aim at it, and the indicator marks it. A splat on it shatters it (Shatter x1.6) and it is gone. | The open middle of a room, where nothing else gives a wall: the heretic's wall endings away from the edge. |
| **Powder Keg** | magma | barrel | A magma hit on a barrel (Molten Palm carrying a foe into it, Undertow's pool reaching it, a molten foe splatted on it) sets it **burning**; 1.2 s later it bursts, 3 m, by the molten Burst rule (x1.5 and a 2.2 m burn) on everyone in it. Molten Palm's carry treats a barrel in its path as a wall (it stops there, half splat, then the burst). | A crowd near a barrel: Molten Palm into it, then Undertow; Meteor Fall dives on the splatted foe as the keg goes. |

Flourishes (run upgrades behind `Kit.has()`):

| Id | Colour | Piece | What happens | Rides |
|---|---|---|---|---|
| `gallows` | dark | hook | Ricochet prefers a hook in its reach over a plain wall: the attacker hangs on it **bound** for 3 s (a hold with no floor), and the next three hits on it are Snaps | slot 9 counter, Ricochet `CB`: target preference |
| `banner_net` | dark | banner | The grab (H, Reap's route step) with no foe in its cone picks a hanging banner: the tentacle tears it down over the foes in front, 4 x 2.5 m; all under it are marked and bound 1 s, so H H gathers them all | route step (H) |
| `brazier_spill` | dark x magma | brazier | Lava Leash yanks a lit brazier within 6 m of a seam into it as it drags: the seams burn 50% longer and Hellseam's crater is x1.25 | slot 8 Lava Leash `XL`: target preference |
| `torches_conduct` | storm | torch, brazier | The charged Arc rule hops through any lit torch or brazier: an arc may jump to a foe 6 m past a lit torch that is within 6 m of the source | the charged state rule |
| `ice_rink` | ice | pool | An ice hit on a pool freezes it into a slide for 8 s: foes slide across it at full speed (no `SLIDE_END` slowdown) and Slapshot's reach over it is 16 m, not 10 | slot 7 Harpoon `EF`, Slapshot: piece rule + target preference |
| `steam_vent` | ice x magma | pool | Steam Burst on or by a pool fills it with steam for 2 s: foes in it take Steam Burst's hit again and cannot strike | slot 8 Steam Burst: piece rule |

### The Dragon Prince (Sunbrand, the thrown sword; dragonfire, radiance; the crown)

His card is not re-cut onto the grammar yet ([dragon-prince.md](../characters/dragon-prince.md) is paused; kit-grammar
section 6 says to re-cut it before he continues), so the slots below are the moves from his draft list and will
move with the re-cut. The verbs carry over:

| Id | Colour | Piece | What happens | Best situation |
|---|---|---|---|---|
| **High Ground** | signature (crown, Skyfall) | ledge | Skyfall (L L H H) within 6 m of a ledge springs off the ledge's face instead of rising in place: twice the height (5 m), blast radius +50%, x1.3, the crown flashes at the apex. Nothing to spring from: Skyfall as now. | The branded foe near a ledged wall. Gives Skyfall a best situation of its own beside Royal Pin's wall. |
| **Felling** | steel (the sword) | pillar | Javelin (L L H) that hits a pillar plants the sword in it (the pillar is **branded**, the beacon on it). Skyfall onto a branded pillar splits it: it falls along his dive line, a 6 m crater line (buried), and the sword comes back with Rightful Return. The pillar is rubble. | A crowd lined up beyond a pillar. His pillar topple is a throw and a dive; the heretic's Uproot is a grab and a club: same noun, two verbs. |
| **Kindle** | dragonfire | brazier, torch | Breath (any dragonfire hit) lights an **out** brazier or torch. A lit brazier within 3 m of a kindled foe adds an ember a second; Ember Flick (L H) through a lit brazier throws its coals forward in a 5 m cone (kindled). Rooms that suit him start with braziers out. | A crowd held by a brazier he lit: Flashpoint at the third ember comes for free. |
| `mirror_pool` (flourish) | radiance | pool | Sovereign Light (hold H) aimed across a pool bends at its centre toward the nearest foe beyond it, humbled on both lines | his beam: target preference |
| `royal_banner` (flourish) | steel | banner | Royal Pin (Dash L H) pinning a foe to a wall with a banner on it brings the banner down over it: branded and humbled 2 s | his dash ender: piece rule |

The overlap is on purpose: pillars, braziers and banners mean different things to the two. A grate, a barrel and a
hook mean nothing to the prince; a ledge means nothing to the heretic (R's sky swing already gives him height).

### A third archetype, sketched only (to show the card generalises)

**The Anchor**, a chain-and-anchor brawler (signature: an anchor on a chain; its state bound). Not designed; only
what the room would mean to it:

| Piece | Its verb | Slot |
|---|---|---|
| two pillars | **Clothesline**: the chain strung between the two pillars nearest the crowd as a tripwire; foes running through are launched (airborne) | gather (H H): target preference |
| crate, barrel | **Flail**: the anchor hooks the piece and swings it as a wrecking ball; it breaks on the first foe | pin (hold H): L ending |
| ledge | **Drop Anchor**: dropped from a ledge, it hauls the pinned foe up the wall face and slams it down | a big move: L ending |

A plant summoner would read the same pieces as soil: rubble and grates root vines, pools grow them faster, banners
burn. Same nouns, new verbs, no new slots.

## 3. Where each lives in the grammar

Every interaction has one slot and one kind. **Definer** = wins only here (the reason to take that slot in this
room); **flourish** = more fun when it happens, never the reason.

| Interaction | Character | Slot (id) | Kind | Definer or flourish |
|---|---|---|---|---|
| Uproot | heretic | 5 sig_pin, Overwhelm `OW` (window Abyss) | L ending (`BREAKERS.OW.alt`) | **definer**: big foe by a pillar |
| Live Floor | heretic | 3 big_1, Live Wire `EE` (Grounded / Short Circuit) | piece rule + Short Circuit target preference | **definer**: Live Wire over Galvanize on a grate |
| Frost Wall | heretic | 2 ender_2, Frost Spear `IP` | piece rule | **definer**: wall endings in the open |
| Powder Keg | heretic | 2 ender_3, Molten Palm `EM`, and magma hits | piece rule + Molten Palm target preference | **definer**: the palm's carry toward a barrel |
| gallows | heretic | 9 counter, Ricochet `CB` | target preference | flourish |
| banner_net | heretic | route step (H grab) | route step | flourish |
| brazier_spill | heretic | 8 cross_dark_magma, Lava Leash `XL` | target preference | flourish |
| torches_conduct | heretic | charged rule (`RULES` Arc) | state rule | flourish |
| ice_rink | heretic | 7 dash_ender_l, Harpoon `EF` (Slapshot) | piece rule + target preference | flourish (a definer in pool rooms) |
| steam_vent | heretic | 8 cross_ice_magma, Steam Burst | piece rule | flourish |
| High Ground | prince | 3 big move, Skyfall | target preference (the take-off) | **definer** |
| Felling | prince | 2 plant ender, Javelin, then Skyfall | piece rule + Skyfall target | **definer** |
| Kindle | prince | dragonfire hits, Ember Flick | piece rule | **definer** (brazier rooms) |
| mirror_pool, royal_banner | prince | his beam, his dash ender | target preference, piece rule | flourish |

`env_target.CTX` gains one entry per definer and per aimed flourish: `uproot` (pillars, choose), `frost_wall`
(grates, no choose: where he plants the spear is the choice), `keg` (barrels, the palm's aim), `live_floor` (grates,
no choose), `gallows` (hooks, choose), `high_ground` (ledges, choose), `felling` (pillars, choose). Piece rules with
no aim (torches_conduct, steam_vent) show their state tell, not the bracket.

## 4. Rooms and runs

### Density per room type

Counts for a room the training room's size (32 x 32 m), walls on three sides.

| Room type | pillar | torch | brazier | barrel | crate | chest | banner | grate | spikes | rubble | pool | hook | ledge |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Hall (the default fight) | 4 | 3 | 0-1 | 2-3 | 1-2 | 0 | 2-3 | 2 | 0 | 2 | 0 | 0-1 | 0 |
| Crypt (tight, walls close) | 2 | 4 | 0 | 2 | 2 | 0 | 2 | 1 | 2 | 3 | 0 | 2 | 0 |
| Cistern (wet) | 2 | 2 | 0 | 1 | 1 | 0 | 0 | 3 | 0 | 1 | 2 | 1 | 0 |
| Throne (tall, open) | 2 | 2 | 2 | 0 | 0 | 0 | 4 | 0 | 0 | 0 | 0 | 0 | 2 |
| Armoury (props) | 2 | 2 | 1 | 4 | 3 | 0 | 2 | 1 | 0 | 2 | 0 | 2 | 0 |
| Treasure (after a fight) | 0 | 2 | 0 | 0 | 2 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| Boss | 4 | 4 | 2 | 0 | 0 | 0 | 2 | 2 | 0 | 2 | 1 | 2 | 1 |

Rules: at most 14 pieces with a verb per room (the indicator must stay readable); every fight room has at least one
definer piece for *each* character (a grate or barrel for the heretic; a brazier, ledge or lone pillar for the
prince), so no character gets a dead room; nothing breakable within 3 m of the hero's spawn.

### The training room

It exposes every piece the hero has a verb for, once, each by a dummy:

- `ROOMS.training` keeps today's layout and adds a grate and a barrel by the back-left dummies, a brazier and a pool
  by the back-right ones, a hook on the left wall and a ledge on the back wall's right third. Pieces the current
  hero has no verb for are left out (the heretic's room gets the grate, barrel, pool and hook; the prince's the ledge
  and an out brazier).
- **Pieces rebuild**: a toppled pillar, a burst barrel, a torn banner come back `REBUILD_S` 6 s after the room goes
  quiet, with a drawn dust pop, the way the dummies refill. Restart training rebuilds everything at once.
- Pause menu: **Room: plain / with pieces** (saved), so the plain room stays for string practice.
- The MOVES panel gets an **ENVIRONMENT** page after MIX ELEMENTS: each interaction, its piece, its slot and the
  input that triggers it (from `EnvPiece.EXCLUSIVE`, like `move_list.mix_name()`).
- One bot string per headline, tagged with its slot (`env uproot hold H L`, `env keg L L L H`, ...), so the
  autotest's done line carries `env=N/N` and `agent.sh check` fails unless every headline fired.

### Run hooks

Kit-grammar section 7: upgrades target a slot or a window, passives an element or a state.

- **Flourishes are the unlocks**: `gallows`, `banner_net`, `brazier_spill`, `torches_conduct`, `ice_rink`,
  `steam_vent` are each a `Kit.has()` upgrade a run can offer.
- **Piece upgrades on headlines** (slot upgrades): "Frost Wall stands 10 s and is 6 m wide", "barrels burn 0.6 s
  and burst 4 m", "Uproot swings the pillar twice before it breaks", "Live Floor spreads to touching grates",
  "torches conduct 9 m".
- **Passives reach pieces for free**, because pieces leave the six states: "+20% molten payoffs" raises every keg;
  "charged lasts 5 s" lengthens Live Floor's charge.
- **Room modifiers** a run's map shows on a door (an icon per piece family): "Flooded" (+2 pools), "Powder store"
  (+3 barrels), "Lit" (every torch and brazier lit), "Collapsing" (pillars start cracked). The player picks the door
  that suits the character and the build.
- **A few character-neutral passives on pieces**: "Pieces rebuild between waves", "Breakables drop Awakening".

## 5. Build order

Ranked by payoff for effort. Lane 0 is the foundation and goes first; lanes 1-4 can then run in parallel (different
slots); 5-8 after. Every lane also adds its bot string, a `move_list` row, reruns `python tools/wiki.py`, and adds a
section to `docs/features/environment.md`. The prince's lanes wait for his card re-cut.

| Rank | Lane | Files | Test | Art |
|---|---|---|---|---|
| 0 | **Pieces as data** (`env-pieces`): `EnvPiece`, `ROOMS.training` holding today's layout, groups and `env_state`, `EnvPiece.hit()` called from `void_element.fire()` and `thrown_foe._burst()`, rebuild in training, grates placed by data | new `scripts/env_piece.gd`, `scripts/rooms.gd`; `main.gd` (`_build_arena` places `ROOMS`), `thrown_foe.gd`, `env_target.gd` (props register) | new `tests/env_piece_check.gd`: the room has the same pieces and colliders as before; a thrown foe breaks a crate and a barrel; states time out; pieces rebuild after `REBUILD_S`. `comic_check` still passes | reuse |
| 1 | **Uproot** (Abyss's L ending) | `void_element.gd` (`BREAKERS.OW.alt`, `_uproot`), `env_piece.gd` (topple to a rubble line), `env_target.gd` (`CTX.uproot`), `breaker_alt_fx.gd` (the swing), `comic_fx.gd` (the word), `move_list.gd`, `training_bot.gd` | `void_arm_check` `_breaker_pairs()`: a big foe 4 m from a pillar, Uproot beats Abyss; in the open Abyss beats it; the pillar has left `grab_anchors` after | reuse (pillar laid down + rubble); a fallen-column piece later (kit) |
| 2 | **Powder Keg** | `env_piece.gd` (burning, burst), `void_element.gd` (magma hits call `EnvPiece.hit`; Molten Palm's carry stops at a barrel), `thrown_foe.gd` (a barrel is a half wall), `designed_fx.gd` (the erupt and wall splat sheets, reused) | `env_piece_check`: Molten Palm into a barrel with two dummies 2 m off it: both take the molten Burst; Meteor Fall then picks the splatted one | reuse |
| 3 | **Frost Wall** | `frost_spear.gd` (planted on a grate), `env_piece.gd` (`frosted`, the wall's life), `env_target.gd` (`add_wall` for the ice wall, removed when it shatters), its collider on the walls' layer so `thrown_foe.clear_from` sees it | `void_arm_check`: Slapshot at a Frost Wall in the open pays the wall mult (63 against 14 without); Pinwheel picks it; it is gone after one splat or 6 s | reuse (`ice_facet` shader, the fitted block mesh) |
| 4 | **Live Floor** | `env_piece.gd` (`live`), `void_element.gd` (storm hits, Short Circuit's start), `designed_polish.gd` (`arc_crawl` on the grate) | `env_piece_check`: a dummy on a grate hit by Updraft Lash makes it live 3 s; a second dummy put on it is charged; Short Circuit reaches a dummy 12 m from the grate | reuse |
| 5 | **torches_conduct** (upgrade) | `void_element.gd` (the Arc rule hops), `env_piece.gd` (lit torches), `kit.gd` (the id) | `env_piece_check` with the upgrade: an arc reaches a charged dummy 10 m off through a torch, and not without it; the `--kit=full` autotest prints it | reuse |
| 6 | **gallows** (upgrade) | `counter.gd` (`ricochet_target` prefers hooks), `floor_bind.gd` (a wall hold), `env_piece.gd`, `rooms.gd` (a hook on the training room's left wall) | `counter_check`: a perfect counter 5 m from a hook hangs the attacker bound 3 s | **new**: hook-and-chain wall piece (kit) |
| 7 | **ice_rink** (upgrade) | `thrown_foe.gd` (slide on a frozen pool), `env_piece.gd` (pool states), `rooms.gd` | `void_arm_check`: Slapshot across a frozen pool keeps its speed and reaches 16 m | **new**: pool piece (kit) |
| 8 | **brazier_spill** (upgrade) | `lava_leash.gd`, `void_element.gd` (`_hellseam`), `env_piece.gd` (spilled) | `lava_leash_check`: with a brazier 4 m off the seam, Hellseam is x1.25 and the seam lives 50% longer | **new**: brazier piece (kit), which the prince's Kindle also needs |

Later, once the prince's card is re-cut: High Ground (needs the **ledge** piece, kit, with a wall collider), Felling
(reuse), Kindle (the brazier from lane 8), each with a `prince_check` case.

The new art is one `comic-asset-kit` lane: hook-and-chain wall, pool, brazier (lit / out / spilled), ledge, fallen
column, in env_kit.py, ported with `python tools/comic_glb.py --env`. Chibi but badass holds for props: chunky, few
shapes, oversized flames and chains, no filigree.

## 6. Open questions for Zak

1. Exclusive by **element** (a grate conducts storm, so only a storm character uses it) or by **character**
   outright (each piece names the heroes that can use it)? This page picks element.
2. Should used-up pieces stay gone for the room (tear the pillar down, lose your swing anchor), or rebuild after a
   while in real rooms too?
3. Uproot costs a pillar. Is losing the R anchor the right price, or should it need a **cracked** pillar (three
   splats first), so it is a payoff rather than an opener?
4. Frost Wall puts a wall wherever there is a grate. Too strong for the wall endings, or exactly the point?
5. Flourishes as run unlocks only, or some in the base kit from the start (gallows is the likeliest to be missed)?
6. Room modifiers on doors ("Flooded", "Powder store"): should the player choose rooms to suit the character, or
   should rooms be random and the character adapt?
7. Hazards that hurt the hero too (spikes, a spilled brazier's fire): on, or foes only?
