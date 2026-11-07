# The kit grammar: one archetype for every character

Zak, 2026-11-06: every character should have "a set and fixed amount of combinations", like Smash, so a player can
pick up a new character and "execute some of their combos right away with familiar pathways"; when to use them
differs per character. The game around it is a roguelike: runs upgrade particular combos and passives raise an
element's or a state's damage, so the combos must be stable targets. Also wanted: dash counters "like counters in
Smash". Not wanted: pruning to Smash's four specials; plenty of flashy breakers stay.

Zak approved it ("implement it", 2026-11-07). Section 5 is implemented (round 49): the slot table and the heretic's
card are data in `scripts/kit_slots.gd`, the demotions are behind `Kit.has()`; see `docs/features/kit-slots.md`.
Section 5 says what the heretic keeps, demotes and
drops; section 6 is the empty card a new character fills in.

## 1. The shape of a character

Every character is **one signature plus three elements**. The signature is the control tool that makes the
character feel unique (the heretic's void tentacle: grabs, marks, drags, conducts). The three elements are the
damage colours and the states they leave. Each element owns one state:

| Heretic | Element | State it leaves | Pays off when another element hits the state |
|---|---|---|---|
| signature | dark (tentacle) | **marked** / **bound** | pulled, held, conducted |
| 1 | storm | **charged** | arcs to neighbours |
| 2 | ice | **frozen** | shatters |
| 3 | magma | **molten** | burns, bursts |

Shared, element-free states: **airborne**, **buried**, **wall-splat** (a foe against a wall or pillar). Every
character's moves leave and cash the same state list; only the names and colours change. A new element never
adds a state, it maps to one (a plant character's "rooted" is bound; a blood character's "bleeding" is molten).

Passives and run upgrades hook into this table, not into individual moves: "+ shatter damage" is "+ frozen
payoffs" for every character, "+ storm damage" is element 1 for the heretic and whatever element 1 is elsewhere.

## 2. The slots (same inputs on every character)

Inputs: L light (LMB), H heavy (RMB), Dash (Space), and the breaker window's L / H. Every character fills exactly
these slots. The count is fixed; the moves, elements and best situations are the character's.

| # | Slot | Input | Count | Role (same on every character) |
|---|---|---|---|---|
| 1 | Light string | L, L L, L L L | 1 | The hack and slash. Each hit tinted by an element in order 1, 2, 3 so the string teaches the colours. |
| 2 | Light enders | L H, L L H, L L L H | 3 | One per element, in the string's order. Each **leaves its state** on the foes it hits (launch, slow, carry). |
| 3 | Big moves | ender + H | 3 | One per ender. The element's payoff on its own state, with a **breaker window**. |
| 4 | Air route | L H L, then L H L H | 1 | The one air variant: a climb after a launched foe into the storm-equivalent big move. |
| 5 | Signature | H, H H, H L H, hold H | 4 | The control tool: mark, gather, drag, pin. H H and H L H and hold H each have a **breaker window**. |
| 6 | Dash moves | Dash L, Dash H | 2 | A lunge and a snare off the dash. |
| 7 | Dash enders | Dash L H, Dash H H | 2 | The gather and the skewer. Each has a **breaker window**. |
| 8 | Crossovers | a fixed extension off a mid | ≤ 6 | One per pair of the four colours (signature + 3). Two elements in one move, the first's state cashed by the second. Each has a **breaker window** when it is a finisher. |
| 9 | Counter | Dash into an incoming attack | 1 | Section 4. A **counter breaker** window on a perfect. |
| 10 | Awakening | Q | 1 | The meter; a stronger mode, not new inputs. |

That is 18 to 24 moves per character, plus route steps (Air Slash, Rockslide, Ice Cube, the vault: the hits that
walk from a mid to a crossover; they are not slots and do not count). Breaker windows: slots 3, 5, 7, 8 and 9,
so **at most 3 + 3 + 2 + 6 + 1 = 15 windows**, each with **one or two endings** (L and H). Two endings only when
both have a clear best situation (Zak: "only when it's truly compelling"). Breakers are where characters get to
be plentiful and flashy; the slots are what stay fixed.

Rules of thumb that make the pathways familiar:

- L H is always the launcher. L L H always plants or slows. L L L H always carries or shoves.
- H always marks what it hits. H H is always the gather. hold H is always the single-big-target tool.
- Dash L H always collects a crowd in front of you. Dash H H always pins one.
- The breaker window's H is the payoff you can always take; L is the environmental or situational one.
- The best situation of a slot is the same role everywhere: slot 3's storm move wants a line, the ice one wants a
  stand, the magma one wants a wall. Which move is which is the character.

## 3. States and the matrix

The current `element-matrix.md` is every state x every element. With four colours per character and the shared
states that is a cross product that grows with every character. The fixed version:

- Six states only: marked/bound, charged, frozen, molten, airborne, buried (wall-splat is a position, handled by
  the camera and the throw code, not a state).
- Each state has **one payoff rule**, written once, that any element's hit triggers (frozen: the hit shatters for
  x1.6 and the ice is gone; charged: the hit arcs to every other charged foe; molten: the hit bursts for a burn;
  bound: the hit cannot be dodged and the hold ends; airborne: the hit juggles; buried: the hit is a crater).
- A character's own element on its own state does the move's thing (storm on charged is Live Wire's pulse), so
  the only per-character cells are those three.
- The current heretic cells that are not one of those rules (Gale Lift, Flash Freeze's steam, Arc Flash's throw)
  become **crossover** moves (slot 8) or breaker endings, which is where most of them already live.

**Status (round 49, matrix-collapse lane): built.** `void_element.RULES` holds the six rules (frozen Shatter x1.6,
charged Arc within 6 m, molten Burst x1.5 + a 2.2 m burn, bound Snap x1.5 with no knockback, airborne Juggle at
7 m/s, buried Crater x1.5); `RULE_OWN` keeps the own-element cells the moves' own (storm on charged, ice on frozen,
magma on molten, dark on bound) and `RULE_SELF` the moves that pay a state in their body (Molten Palm's steam,
Updraft Lash's dig-up, the air string, Tow Line's rip). Every other cell is a Kit upgrade (18 ids: the four charged
ones plus `gale_lift`, `shard_cut`, `frozen_in`, `swallowed`, `firestorm`, `quench`, `flare_up`, `smother`,
`ice_spreads`, `torn_off`, `freeze_aloft`, `meteor_spike`, `torn_loose`, `frozen_dark`); Aftershock was already the
crater, so it is the rule. Gale Lift is not a slot move, so it is an upgrade, not a crossover. Flash Freeze's steam
was never a cell (it is Steam Burst's). "marked" stays the signature's setup, not a paying state. See
[element-matrix.md](../features/element-matrix.md).

## 4. Dash counters

**Status (round 49): built for the heretic.** Backlash and its window's ending Ricochet, `WINDOW` 0.25 s, `PERFECT`
0.1 s, 60 deg; the swinging training dummy; see [../features/counter.md](../features/counter.md).

Smash's counter is a special that, hit during its window, cancels the hit and answers it harder. Here it lives
on the dash, since every character has one and it is already the "get out" button:

- **Trigger:** Space pressed while an enemy's strike is in its hit window (the telegraphed windup already exists on
  every spar foe: `enemy.gd` windup -> strike) and the dash is aimed within ~60 degrees of the attacker. Window
  about 0.25 s before the strike lands to the strike frame; `COUNTER_WINDOW`.
- **What happens:** the dash becomes the counter instead of the lunge. i-frames through the strike, a hitstop
  with a drawn "parry" flash in the signature's colour, the attacker staggered and **marked** (every character's
  counter leaves the signature state), and the character's counter move plays. Nothing else changes inputs.
- **Perfect counter:** pressed in the last 0.1 s. Opens a short **counter breaker** window (slot 9), one ending,
  in the character's signature colour. The heretic's: the tentacle wraps the attacker and hurls it into the
  nearest foe or wall (wall-splat, bound).
- **Not a counter:** a dash with no incoming strike is the dash as now, so there is no cost to pressing it. A
  dash into a strike from behind, or away from it, is a plain dodge.
- **Training room:** the dummies never attack, so counters need a sparring foe (`--spar=` already adds one) or a
  dummy that swings on a timer when he stands in front of it. The second is the cheaper and lets the bot test it.
- Heretic counter name: **Backlash**. Word: KRRAK-SNAP! The tentacle catches the weapon, the flash is violet.

## 5. The heretic against the grammar

**Implemented (round 49).** `KitSlots.HERETIC` holds this table. Storm Pitch is behind `Kit.has("storm_pitch")`
(`Dash H L` is Tow Line, then Slice, without it); `--kit=full` turns it on. It is the only demotion: Rockslide's
buried payoff stays in the base kit, because Fault Line's buried x2 and the buried rule (Crater) need buried to exist. Reap fills the mark slot at H L (his H alone is the grab, a route step). Backdraft (Dash H H L) fills dark
x ice. Impale fills the Dash H H slot but has no window yet. The counter fills slot 9 by its window (`CB`, Ricochet). The
matrix cells are gated by the matrix collapse (section 3). `tests/kit_check.gd` checks the card.

What it keeps, by slot. Everything listed exists today.

| Slot | Keep | Notes |
|---|---|---|
| 1 Light string | Chop, Chop, Chop (axe storm, spear ice, hammer magma) | Already teaches the three colours in order. |
| 2 Light enders | Updraft Lash (L H, storm), Frost Spear (L L H, ice), Molten Palm (L L L H, magma) | Launch, slow, carry. Exactly the three roles. |
| 3 Big moves | Live Wire (L H H: Grounded / Short Circuit), Deep Freeze (L L H L H: Avalanche), Undertow (L L L H H: Meteor Fall / Meteor Shower) | The spear vault (L L H L) is a route step. |
| 4 Air route | Air Slash -> Live Wire air (L H L H: Worldbreaker / Cold Front) | Keep. |
| 5 Signature | Reap (H), Singularity (H H: Collapse), Black Tide (H L H: Maw / Black Ice), Overwhelm (hold H: Abyss) | Mark, gather, drag, pin. Exactly the four roles. |
| 6 Dash moves | Dash Stab (Dash L), Tow Line (Dash H) | Lunge, snare. |
| 7 Dash enders | Harpoon (Dash L H: Shatterstorm / Slapshot), Impale (Dash H H) | Harpoon is the gather; Impale the skewer. Ice Cube (Dash L H H) is a route step into Hailstorm. |
| 8 Crossovers (≤ 6, one per colour pair) | storm x magma: **Fault Line** (L H L L H: Cataclysm / Tempest). ice x magma: **Steam Burst** (Dash L H H L: Flash Freeze). dark x storm: **Galvanize** (H L L, charged state). ice x storm: **Hailstorm -> Meltdown** (Dash L H H H, then L: Eruption) counted as one route. dark x ice: **Backdraft** (L L H, Dash H H L: Anvil / Pinwheel). dark x magma: **Lava Leash** (L L L H L, `XL`: Hellseam) | All six pairs filled. Lava Leash (round 49, dark-magma lane) is magma into dark: off Molten Palm the tentacles drag everyone the palm hit back along the seam into a pile at his feet, paid by the metre (more torn off a wall), and the seam erupts under the pile (molten, bound). Best situation: the palm's foes at mixed ranges, one on a wall; Galvanize keeps the spread crowd, Black Tide the marked anywhere (`void_arm_check` `_lava_leash()`). Its slot is `cross_dark_magma` in `kit_slots.gd` (`XL`). |
| 9 Counter | Backlash (round 49; perfect: Ricochet) | Section 4; [counter.md](../features/counter.md). |
| 10 Awakening | as now | |

**Demote** (keep in the game as upgrade or unlock content, out of the base kit, so a new character is not
measured against them): **Storm Pitch** (Dash H L: a second dark x storm move beside Galvanize; it becomes an
upgrade to Tow Line, "Tow Line hurls them") and **Rockslide** (L H L L: the step before Fault Line stays as the
route step, but its own buried payoff is an upgrade; round 49 put the payoff back in the base kit, since Fault Line's
x2 and the buried rule need the buried state). The `charged` state's four payoffs (Overload, Superconduct,
Arc Flash, Conduct) collapse into the one charged rule in section 3 (the hit arcs to every other charged foe)
plus **Arc Flash kept as a crossover-grade payoff** if dark x magma needs a home; the other three are upgrades.

**Drop** from the base kit: nothing else. The heretic is over the grammar by two moves and three matrix cells;
the rest of the growth today was breaker endings and effects, which the grammar does not cap beyond two per
window.

Counts after this: 1 + 3 + 3 + 1 + 4 + 2 + 2 + 6 + 1 counter = 23 moves, 14 of them with a window,
21 endings today, the counter's Ricochet and Lava Leash's Hellseam the newest (room for Impale, Avalanche, Flash
Freeze, Collapse, Abyss, Hellseam and the counter to gain a second one only when one is compelling).

## 6. The character card (fill this in for every new character)

```
Name:               Signature (control tool, colour, its state = marked/bound):
Element 1 (state charged-equivalent):   Element 2 (frozen-equivalent):   Element 3 (molten-equivalent):

1  Light string      L / L L / L L L     : three hits, tinted 1 / 2 / 3
2  Light enders      L H / L L H / L L L H : launch / slow or plant / carry or shove
3  Big moves         + H                 : one per ender, window; endings (H always, L if compelling)
4  Air route         L H L -> L H L H    : climb, then the air big move; window
5  Signature         H / H H / H L H / hold H : mark / gather / drag / pin; windows on the last three
6  Dash moves        Dash L / Dash H     : lunge / snare
7  Dash enders       Dash L H / Dash H H : gather crowd / pin one; windows
8  Crossovers        <= 6, one per colour pair, each named by the pair; windows on finishers
9  Counter           Dash into a strike  : name, word, what the perfect's window does
10 Awakening         Q                   : what the mode changes
Best situations:     one line per window: "L wins when ..., H wins when ..."
```

The Dragon Prince (`dragon-prince.md`, paused) is the first test of the card: his sword forms are his elements
and the crown is his signature; his slice should be re-cut onto these slots before it continues.

## 7. What the roguelike hooks into

- Run upgrades target a slot (slot 3 ice: "Deep Freeze freezes 2 m wider") or a window ("Tempest lifts big
  foes too"), never a route step.
- Passives target an element or a state ("+20% frozen payoffs", "charged lasts 5 s"), so they carry across
  characters.
- Demoted moves are the natural first unlocks: Storm Pitch returns as a Tow Line upgrade, the charged cells as
  Galvanize upgrades.
- The training room's guide and the bot strings should be keyed by slot name so each character's autotest is the
  same list (`strings` per slot, `endings_n` per window).

## 8. Open for Zak

1. Three elements plus a signature per character, or should the signature be the fourth element outright (it is
   for the heretic, where dark is both).
2. The dark x magma crossover: built as Lava Leash (L L L H L: Hellseam, round 49). Keep it in the base kit, or
   move it to an unlock.
3. Counter on Dash (this page) or on a held H like Smash's down-B. Dash keeps the inputs at three buttons.
4. Which demoted heretic moves, if any, you would rather keep in the base kit. Storm Pitch is the one most
   likely to be missed.
5. Whether the matrix collapse (one rule per state) loses a cell you like: Gale Lift and Flash Freeze's steam
   move to crossovers, Arc Flash's throw and Superconduct and Conduct become upgrades.
