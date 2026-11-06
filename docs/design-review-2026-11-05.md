# Design review, 2026-11-05: combos, effects, designs

Zak asked: what is good in the combo system, what is missing, what is not compelling, and the same for the effects
and the designs. His rule, stated today: **every combo should have a good time to use it, and a player who uses
them on purpose should be very strong.** His example: Molten Palm (L L L H) is best as a forward punch that drives a
bunch of foes into a wall for big wall damage, and its breaker Meteor Fall then dive-bombs the largest group (that
Meteor Fall change is decided and being built in another lane; this page treats it as done).

Fixed and not reopened here: the combo system itself, the art direction (chibi, cartoony, badass; sleek comic
effects with thin ink and see-through fills; never more detailed or serious), and Avalanche.

How this was judged: the docs (`combo-breakers`, `void-element`, `element-matrix`, `combo-guide`, `comic-style`,
`art-direction`, `heretic-hero`, `enemy-hit-reactions`, `camera`), both feel audits, ROADMAP rounds 30-41, the
move tables in `hero_moves.gd` / `void_element.gd`, `enemy_types.gd`, `enemy.gd`'s shield and bomber code, and the
film on disk (`combo_clips/<string>/`, 12 strings plus free play, looked at as contact sheets of every HIT frame and
every third frame), plus the foe lineup and room stills in `foe_shots/`. Nothing here was played by hand.

The one-line verdict: **the kit is rich and the grammar is good, but almost nothing in the game asks for one move
over another.** The dummies never fight back, the walls are never in frame, nine foes exist but only spar brings
one in, and the element matrix pays on every cell, so there is no wrong answer and therefore no right one. Most of
what follows is about giving moves a job and giving the room and the foes reasons to pick each job.

---

## 1. The combo system

### Good: keep

- **One grammar for 30-odd moves.** The number of lights picks the weapon and its element (1 axe storm, 2 spear
  ice, 3 hammer magma, 0 dark), right click is the tentacle doing that element's thing, a dash starts the other
  branch. A player can guess a string before reading it. This is the system's best idea.
- **Elements have verbs.** Storm goes up and through, ice turns foes into objects, magma goes down and apart, dark
  pulls in and swallows. This is the right level of rule: short, physical, visible.
- **Dash cancels anything**, and the dash is also an input (Dash L, Dash H). Defence and offence share a button.
- **Breakers are a skill test with a clear shape.** One window rhythm for every breaker (open, sweet, close), a
  PERFECT with a freeze, early presses lock out, a dash calls it off. The timing circle is readable.
- **Crossovers route through existing inputs.** Rockslide, Steam Burst, Storm Pitch and the rest replaced dead ends
  ("this used to restart the chain"), so the tree got deeper without new buttons.
- **States outlast strings** (`ELEMENT_HOLD` 2 s) so a dash into another element improvises. The idea is right:
  set up with one string, cash in with another.
- **The guide never lies.** One routing function feeds the moves, the guide and the checks. The "+ Frozen In"
  pay tag appears only when the payoff is in the move's real hit shape. Keep that discipline.
- **Found combos and the move list** give a collection goal (n / 24 found).
- **Molten Palm into a wall** already exists (`PALM_WALL_MULT` 2.5) and is the best single example of a move with a
  situation. Copy its idea everywhere (section 3).

### Missing

- **A reason to choose.** Against four dummies in a fan every string works, so the best string is the one with
  the biggest number. There are no foes in play, no attacks to avoid, no ranged threats, no armour.
- **Single-target tools.** Almost every move and every breaker is crowd damage. Only Overwhelm (big foes) and Grab
  aim at one foe. There is no "kill that one now" string for an elite, a necromancer or a lit bomber.
- **Gap closers that are about distance.** Dash Stab, Harpoon and Tow Line exist, but no foe keeps distance in play,
  so their job never comes up. Mages and archers (preferred range 7-10 m) and the necromancer (11 m) exist in
  `enemy_types.gd` and never appear.
- **Positional payoffs other than one wall.** Walls pay on Molten Palm and Meteor Fall only. Storm Pitch, Ice Cube,
  Cold Front, Collapse and Backdraft all throw or push foes and get nothing from a wall, a pillar or another foe.
- **Defence beyond the dash.** Perfect dodge staggers the attacker (1.2 s) and refunds meter, which is good, but
  nothing follows it up. There is no counter, no parry, no "this string is safe, that one is risky".
- **Risk.** The breaker hang, the longest strings (6-8 presses) and the charge all carry no danger because nothing
  attacks. Long strings should cost exposure and pay more; short ones should be safe and pay less.
- **Light-only identity.** Slice, Hurl and Triple Chop are spirit damage with echoes. Triple Chop (L L L) is the
  only named ender that does nothing special.

### Not compelling

- **The element matrix pays on every cell, so no cell is a decision.** 24 state x element cells, 15 of them new;
  most new ones are "x1.5 and a crater" (Aftershock, Swallowed, Smother, Meteor Spike) or "x1.5 and a launch"
  (Torn Loose, Firestorm). If any follow-up pays, the player stops thinking about which one. A matrix teaches when
  some cells are big, some small and a few bad.
- **Breakers converge on one ending.** Grounded, Worldbreaker, Cataclysm, Eruption, Anvil, Collapse, Maw, Abyss and
  Black Ice all end with the pile cratered and a total. In film every landing is the same cream impact frame, an ink
  circle, a word and a three-digit number (`L_H_L_L_H` 033, `line_D_L_H_H_H_L` 047, `L_L_H_D_H_H_L` 047, `freeplay`
  081). The leap differs; the result does not.
- **Duplicates.** Two moves called Live Wire (L H H, L H L H) with near-identical breakers (Grounded: lightning under
  each; Worldbreaker: magma under each). Steam Burst (Dash L H H L) does what Molten Palm already does to any frozen
  foe. Updraft Lash, Fault Line, Hailstorm and Backdraft are four launchers.
- **The three-element strings ask for set-up the room never gives.** Hailstorm lifts one foe unless the dummies
  stand in a line (the bot needs a `line` token). Impale wants a standing frost spear. They are long, impressive,
  and only work in a staged spot. That is fine for a payoff string, but nothing tells the player which spot.
- **Vault hits nothing.** It could be the kit's only escape (up and over), but nothing threatens him, so it reads as
  a pause in a string.
- **Reap only marks.** Its mark matters only for Black Tide; on its own it is a plain crescent.
- **The counter is meaningless in training.** The film shows 90, 300, 418 HITS at SSS for whole sessions. Nothing
  drops the chain, so rank stops being feedback within a minute.

---

## 2. Every string and breaker

"Today" is what the film and code show its best use to be with what exists now. "Proposed" is the job that would
give it a time to be used. Overlap marks name the moves competing for the same job.

### Lights, dash, grab

| Input | Name | Element | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| L | Slice | spirit | Axe swing, spirit echo | Opener | Safe poke: fastest recovery in the kit, cancels on whiff. Keep |
| L L | Hurl | spirit | Second swing, echo cast | none: it is just damage | Keep as a step; it is a route, not a move |
| L L L | Triple Chop | spirit | Overhead ender, big echo fan | none: it is just damage | **Armour break**: the overhead chop breaks a shield from the front and strips a warrior's poise for 2 s. The plain string gets a job |
| Dash, L | Dash Stab | spirit | Lunge, brakes in front of a foe | Starting the dash branch | **Gap closer to ranged**: dash through a bolt (i-frames) and stab the mage; a perfect dodge into it crits (counter) |
| H | Grab | dark | Yanks one foe to him; too big drags him to it | Pull a straggler | **Single-target pick**: pull the necromancer, the archer, the lit bomber out of the back line. Already right; foes just need to stand back |
| H during R swing | Snatch | dark | Carries a foe on a pillar swing | none: rarely seen | Pillar throw: let go into a wall or a crowd. Only if pillars become walls (section 3) |

### Storm (axe)

| Input | Name | Element | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| L H | Updraft Lash | storm | Sweep, gale gathers, launches, he rises | Launch a crowd | **The launcher** (keep the kit's main one). Anti-rogue: launched foes can't dodge |
| L H L | Air Slash | storm | Axe in the air | Juggle | Air extender; fine as a step |
| L H H | Live Wire | storm | Tentacle on each foe, lightning ticks through the hang | Hold up to `SEIZE_MAX` at once | **Interrupt many**: the hold cancels every windup in reach, so it is the answer to a crowd all swinging at once. Safe, low damage |
| L H H, H | Grounded | storm | Slam with lightning under each | Payoff of Live Wire | **Stun payoff**: leaves everyone stunned 1.5 s (a setup breaker), not more damage |
| L H L H | Live Wire (air) | storm | Live Wire from the air | Same as ground | **Rename** (e.g. "Thunderhead") and make it the air hold that keeps them up. Overlap: Live Wire |
| L H L H, H | Worldbreaker | storm + magma | Slam with magma under each | Same as Grounded | **Air payoff that bounces**: foes come back up off the slam so the string can go on (an extender breaker). Overlap: Grounded, Cataclysm |
| L H L H, L | Cold Front | ice | Held foes frozen and hurled at other foes as cubes | Spread crowd | **Anti-spread**: cubes seek the foes farthest from him and splat on walls. Overlap: Ice Cube |

### Ice (spear)

| Input | Name | Element | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| L L H | Frost Spear | ice | Plants a spear; frost floor slows | Set up Deep Freeze | **Zone / defence**: drop it in a doorway or in front of a rush (rogues, bombers); slowed foes can't flank. Shrink the floor so its edge means something |
| L L H L | Vault | ice | Up onto the spear | none: hits nothing | **Escape**: i-frames on the way up, a short hop off the far side. The only "get out" move in the kit |
| L L H L H | Deep Freeze | ice | Spear goes off, everyone on the frost frozen | Freeze a crowd on the field | Crowd freeze (setup). Keep |
| L L H L H, H | Avalanche | ice | Cubes lifted and crushed together | Payoff of Deep Freeze | Unchanged (not to be touched) |
| Dash, L H | Harpoon | ice | Spear tip through a line, reels them in frozen | Line of foes | **Anti-ranged line pull**: drag an archer line into melee. Overlap: Tow Line, Black Tide |
| Dash, L H H | Ice Cube | ice | Freezes nearest, bowls it through others | Line of foes | **Bowling / wall shot**: aimed, the cube bonus-splats on a wall or bursts a bomber it hits. Overlap: Cold Front |

### Magma (hammer)

| Input | Name | Element | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| L L L H | Molten Palm | magma | Fist shoves a strip of foes 6 m through lava; a wall splats x2.5 | Crowd near a wall (rarely in reach: see section 3) | **Wall drive** (Zak's example). Make the wall reachable and the splat loud. Overlap: none, it is the model |
| L L L H H | Undertow | magma | Wells drag foes waist-deep where they landed | Hold the shoved | **Pin against the wall**: the splatted stay bound against it (bound + wall = bigger Meteor Fall) |
| L L L H H, H | Meteor Fall | magma | (decided) dives onto the largest group | Biggest pile | **Dive-bomb the largest group**: the crowd-finder breaker. Its gather and wall beats are gone |

### Dark (no weapon)

| Input | Name | Element | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| H H | Singularity | dark | Slam the held foe, a hole pulls small foes in, slows big | Gather a crowd | **Vacuum**: the crowd-gatherer. Overlap: Black Tide, Tow Line |
| H H, H | Collapse | dark | Hole falls in, everyone near thrown clear | Payoff of Singularity | **Get off me**: the breaker that clears space, throwing outward into walls (wall splats). The panic button when surrounded |
| H L | Reap | dark | Crescent through everyone ahead, marks them | Before Black Tide | **Tag**: wide, long reach; mark lasts long enough to matter. Keep, but it only becomes good once foes are spread |
| H L H | Black Tide | dark | Drags every marked foe across the floor into a pool | Marked foes far apart | **Anti-ranged vacuum**: the answer to a back line of mages, archers and a necromancer at 10-14 m. Overlap: Singularity |
| H L H, H | Maw | dark | Jaws shut on everyone in the pool | Payoff of Black Tide | **Payoff**: biggest damage on the pool. Keep |
| H L H, L | Black Ice | dark + ice | Pool freezes, landing shatters | Same as Maw | **Setup**: leaves them frozen (don't shatter on landing), so a magma or dark follow-up cashes in. Maw = payoff, Black Ice = setup, one pair, one choice |
| hold H | Overwhelm | dark | Pool and tendrils under the nearest in the cone; works on big foes | One big foe | **Elite pin**: the only move that holds a warrior, shield or Warden. Keep it as that |
| hold H, H | Abyss | dark | Sink through the floor, spikes throw them back | Payoff of Overwhelm | **Execute**: single-target, highest damage in the kit on one foe; weaker on crowds |
| Dash, H | Tow Line | dark | Latches foes along the dash, yanks them together | Bunch a line | **Herd**: the dash that gathers a line into one spot. Overlap: Harpoon, Singularity |

### Crossovers

| Input | Name | Elements | What it does | Best situation today | Proposed identity |
|---|---|---|---|---|---|
| L H L L | Rockslide | storm into earth | Air string comes down with the hammer, craters and buries everyone near | After a launch | **Spike down**: bring an air juggle back to the floor; buried foes can't act (pins rogues) |
| L H L L H | Fault Line | earth into storm | Cracks run to everyone in reach, gale launches each; buried x2 | Spread crowd | **Reach**: hits everyone in `FAULT_REACH`, the farthest-reaching launcher. Overlap: Updraft Lash (launcher) |
| L H L L H, H | Cataclysm | storm + earth | Held, then craters, sky strike under each | Payoff | **Payoff** for the long storm string. Overlap: Grounded, Worldbreaker |
| Dash, L H H L | Steam Burst | ice into magma | Every frozen in reach goes off in steam | Frozen foes near | **Radius cash-out**: every frozen foe in the room, not only the strip (Molten Palm already steams a strip). Big when there is ice, a weak shove when there isn't: the risky payoff. Overlap: Molten Palm on frozen |
| Dash, L H H L, H | Flash Freeze | magma into ice | Steam refreezes on the held, landing shatters | Payoff | **Setup loop**: they land still frozen, so another magma move steams them again. Overlap: Black Ice |
| Dash, H L | Storm Pitch | dark into storm | Bunched foes hurled along his aim, lightning jumps in flight | After Tow Line | **Aimed throw**: wall splat and bowling into other foes; throw a bomber into a crowd. Overlap: Ice Cube, Cold Front |
| Dash, L H H H | Hailstorm | ice into storm | Whirlwinds lift every frozen foe, he climbs | Frozen line | Step of the long string; keep |
| Dash, L H H H L | Meltdown | ice, storm, magma | Hammer in the air, ice bursts, all driven down molten | Lifted cubes | **Long investment**: the highest damage on a frozen crowd, six presses of exposure |
| Dash, L H H H L, H | Eruption | magma | Floor goes up under everyone near; molten x more | Payoff | Payoff of the long string. Overlap: Cataclysm, Anvil |
| (L L H,) Dash, H H | Impale | dark into ice | Bunched thrown onto the spear, frozen and skewered | Spear standing | **Spear trap**: plant the spear at a choke, herd onto it. Ties the spear's zone job to a payoff |
| (L L H,) Dash, H H L | Backdraft | ice into storm | Gale blows the spear apart, hauls everyone back and up | After Impale | Launcher step; keep. Overlap: launchers |
| (L L H,) Dash, H H L, H | Anvil | earth | Hammer craters each held foe, fanned out | Payoff | **Spread payoff**: one crater each, fanned across his aim. Overlap: Cataclysm, Eruption |

### Overlap summary

| Job | Competing moves | Proposal |
|---|---|---|
| Launch a crowd | Updraft Lash, Fault Line, Hailstorm, Backdraft | Updraft Lash = the launcher; Fault Line = reach; Hailstorm = frozen only; Backdraft = after a spear. Say so in the move list |
| Pull to him | Harpoon, Tow Line, Black Tide, Grab, Backdraft | Harpoon = line, Tow Line = herd on the dash, Black Tide = from anywhere (marked), Grab = one |
| Gather in one spot | Singularity, Tow Line, Black Tide | Singularity = near, Black Tide = far |
| Crater the pile (breakers) | Grounded, Worldbreaker, Cataclysm, Eruption, Anvil, Maw, Collapse, Abyss, Black Ice | Give each a different **end state** (stunned, bounced up, frozen, thrown to walls, one foe executed) instead of a different crater |
| Throw a foe into others | Ice Cube, Cold Front, Storm Pitch | Ice Cube = one aimed, Cold Front = spread, Storm Pitch = the bunch |
| Steam the frozen | Molten Palm, Steam Burst, Meltdown | Palm = strip, Steam Burst = everyone in range, Meltdown = in the air |
| Two Live Wires | L H H, L H L H | Rename the air one |

---

## 3. What "intentional play makes you strong" needs

Ranked by value for effort. S = an afternoon, M = a lane-day, L = a round.

1. **Foes that fight in training (M).** The single biggest gap. A "drills" page in the pause menu: preset
   situations with live foes at training damage, each built to ask one question. "Shield wall" (three shields
   facing him: Triple Chop or a launch breaks them), "back line" (two archers and a necromancer at 10 m behind
   minions: Black Tide or Harpoon), "rush" (rogues: Live Wire holds them, Frost Spear slows them), "bomb squad"
   (bombers among minions: throw a lit bomber into the crowd), "against the wall" (a crowd near a wall: Molten Palm
   into Meteor Fall). `spar.gd` already spawns one live foe; this is the same with a list.
2. **Walls in reach and a wall rule for everything (M).** The room is 32 m across (`ARENA_HALF` 16, `TILE` 4,
   `HALF_TILES` 4); the camera at 13 m shows far less, and the walls are in no frame of the film. Molten Palm shoves
   6 m, so its x2.5 splat needs a foe already within ~6 m of a wall. Make "any big knockback into a wall splats
   and bounces back" a foe rule (`enemy.gd`, the `_walled` check `meteor_wall` already has), let pillars count, and
   either shrink the room (6 tiles) or add low inner walls. Wall hits should be the loudest non-breaker hit in the
   game.
3. **Foe answers made explicit (S each).** The code already has most hooks: the shield blocks frontal hits unless
   `big` or launched (`_shield_blocks`), bombers' fuses keep burning through launches and their blast hurts other
   skeletons for 40 (`blast_enemy_damage`), rogues dodge half the time, bosses never freeze, heavies don't launch.
   Tie each to a named answer and show it (a guard-break word for Triple Chop on a shield; Storm Pitch's aim
   snapping to a lit bomber; Black Tide's mark reaching a necromancer). Then the move list can say "Triple Chop:
   breaks shields".
4. **Breakers with different end states (M).** Section 2's table: Grounded stuns, Worldbreaker bounces them up,
   Black Ice and Flash Freeze leave them frozen, Collapse throws them outward to the walls, Abyss executes one,
   Maw and Meteor Fall are the big crowd payoffs. A setup breaker should flow into the next string; a payoff
   breaker should end the fight.
5. **Make the matrix uneven and teach two rules (S).** Rule 1: the element you hit with decides what happens
   (storm launches, ice freezes, magma craters, dark eats). Rule 2: the state decides how big. Then make a few
   cells big on purpose (frozen x magma steam, skewered x dark, buried x magma, bound x storm) and let the
   rest pay little. Teach the two rules on one page instead of 24 rows of text, and add the guide's element chips
   (already on ROADMAP).
6. **Risk on long strings (S, after item 1).** The three-element strings and the breaker hang should be where he
   can be hit (or at least where nothing protects him), so a six-press string is a bet and a two-press one is safe.
   Check that the hang is not accidentally safe: `player.take_hit` only skips while `_invuln_t > 0`.
7. **A counter after a perfect dodge (S).** Perfect dodge already staggers the attacker 1.2 s. Make the next
   string's first hit a crit (a gold flash and word), and the dash's follow-up (Dash Stab, Tow Line) reach the
   staggered foe. That makes defence a choice that pays, not just survival.
8. **The counter and rank mean something (S).** Drop the chain when he is hit and after a pause between strings;
   grade a string by what it did (wall splats, a matrix cell, a PERFECT, a guard break) rather than hit count.
   Against dummies, show the rank per string next to `THIS STRING`.
9. **Readable states at a glance (S).** Frozen (cube), buried (crack ring), molten (glow), skewered (stake) read in
   film. Bound and airborne have no tell of their own beyond the pose, and all states share one 2 s timer with a
   fade only in the last 0.4 s. A thin ring that empties round each tell would tell the player how long they have.
10. **Hazards (L).** The octagon floor grates are decoration. Later: grates as vents (magma moves set them off),
    a pit edge (knock-off kills), spike walls (wall splats bleed). Do this after item 2, not before.

---

## 4. Effects

### Good

- **The sleek pass worked.** Thin ink, see-through fills, one palette per element, short lives: hit frames average
  0.09 of the screen (audit 2). Rockslide's boulder, Fault Line's cracks, Storm Pitch's forks and Steam Burst's
  puffs each read as their element in one frame.
- **The impact frame** (cream inverted frame with an ink circle) on breaker landings is the strongest single
  beat in the game: it is unmistakably comic and it lands.
- **Words** are the right voice: KRUNCH!, SKRRRAK!, ZZWANNG!, KRAKA-DOOM! Each move has its own.
- **State tells** are restrained (a crack ring, a stake, a halftone glow) and stay out of the next string's way.
- **Thin lines still hit** on breakers because hitstop and the impact frame carry the weight.

### Missing

- **Wall impact.** The wall splat (`comic_splat.gd`) exists but walls are never in frame, so the game's best
  positional payoff has never been seen. It needs a held frame, a crack on the wall and a bounce.
- **Element in the impact frame.** All 13 breakers land on the same cream frame and black circle. Keep the frame,
  change the ink shape: cracks for earth, a forked bolt for storm, shards for ice, a tooth ring for dark.
- **Light hits feel equal.** Slice, Hurl and Triple Chop all show a yellow star, a number and a word. Triple Chop
  should have one heavier contact (a guard-break look if it becomes the armour breaker).
- **A guard-break and counter look.** Nothing yet says "you answered that correctly". This is where effects can
  teach (section 3, items 3 and 7).

### Not compelling

- **Numbers are the loudest thing on screen.** In every frame of the film the yellow damage numbers (31, 49, 122,
  672) are bigger and brighter than the effects. Every hit has a number, a star and a word, so three layers
  compete at the contact. Cut per-hit numbers on lights to a small size, keep the breaker total big.
- **Yellow-orange stars on every element.** Storm, earth and spirit hits all burst in the same yellow star with
  orange points (`L_H_L_L_H` 017, `line_D_L_H_H_H_L` 036). The element is in the effect behind; the star in front
  should take the element's light colour.
- **Breaker cue rings in the hang** (orange and white hoops on Fault Line, Meltdown, Backdraft) are the biggest
  shapes in those frames and sit over the pile. Fine as UI, but they are the same in every breaker.
- **The echo fan and frost floor**: the brown halftone fan on L2 / L3 and the teal halftone frost floor are still
  large flat areas (audit 2's smaller items; frames `out_face_L_L_L_H_H_D_wait_L_H` 018, `L_L_H_D_H_H_L` 018).
- **Overwhelm's pool** is the last thick colour (ROADMAP round 41, item 6; still open).
- **Per element:** storm reads best (green bands, forks, thin and fast). Ice reads well as halftone crystal but
  its floor is large. Magma reads as orange stars more than as lava: Molten Palm's fist is a blink (round 41 item
  7), and Eruption's slabs disappear under the number. Dark is the busiest: violet tentacles, a violet claw, a
  violet pool and the rogue's violet all share one colour.

---

## 5. Designs

### Hero

- **Good:** the chibi silhouette works from the game camera: hood point, big violet claw, short body (room still,
  `foe_shots/mf2_after_room.png`). The claw becoming each weapon is the kit's identity in one image.
- **Missing:** a defensive pose or counter animation (if item 7 lands), and a visible tell for which weapon is
  "loaded" before right click (the axe aura does some of it).
- **Not compelling:** in piles he disappears. His hood is the same cream as the dummies' bodies, so in every
  crowded frame (`freeplay` 078-087, `line_D_L_H_H_H_L` 036-045) the hero is one more cream blob. The violet claw
  is his marker, and dark effects are violet too. The run is still a hood dragging a claw (round 41 item 8).

### The nine foes

- **Good:** the lineup (`mf2_after_row_game.png`) has real variety and charm: the mage's hat, the bomber's bomb,
  the necromancer's green hood, the warden's bulk. Colour families (legion orange, cult violet, grave green) sort
  a crowd.
- **Missing:** none of them is in the game. Each foe's design should show its answer: the shield's plank says
  "hit me from the side or break me"; the bomber's fuse says "throw me"; the necromancer's staff says "pull me".
  Most already do; they need to be met.
- **Not compelling:** the minion is still the plainest (open item); the rogue's violet is the hero's violet (audit
  2); the warrior's overhead tell hides under its helmet (open). The archer and rogue share a model and differ only
  by cloth colour.

### Dummies

- They are charming, but they are the only thing he fights, they share the hero's cream, and they never move,
  attack or die. Tint them away from cream (red sacking or straw brown) so the hero reads in a pile, and let drills
  (section 3, item 1) replace them for anything but damage testing.

### Room

- **Good:** the dark slate with ink cracks makes every effect read; the four pillars give R swings something.
- **Missing:** anything to use. No wall in camera range, no hazards, no choke. The octagon grates look like they
  should do something.
- **Not compelling:** the room is a stage, not a place to fight. For Zak's wall rule, the room is the main
  blocker (section 3, item 2).

### HUD and move list

- **Good:** the combo guide is truthful, thin-inked and tags crossovers and payoffs. The breaker prompt is clear.
- **Missing:** a one-line "what this string is for" in the move list (the identity column of section 2), the
  matrix taught as two rules, and the guide's element chips.
- **Not compelling:**
  - The guide sits beside the hero over the pile, so in every crowd frame it covers foes (`L_H_L_L_H` 011-021).
  - The counter's 418 HITS / SSS is permanent in training and tells nothing.
  - `THIS STRING n` (the number the player actually wants) is tiny, bottom right.
  - The health bar at the top left has no label or meaning in training.
  - The move list is 50-odd text rows; the MIX ELEMENTS page is 24 more.

---

## 6. Top 10 next changes (ranked)

1. **Training drills with live foes that each ask one question** (shield wall, back line, rush, bomb squad,
   against the wall), because no move can have "a good time to use it" while nothing in the room ever asks.
2. **A wall rule for every big knockback, and walls in reach** (pillars count; a smaller room or inner walls), because
   Molten Palm's wall drive, Zak's own model combo, can't be found in the current room.
3. **Breakers with different end states** (stun, bounce up, stay frozen, throw to walls, execute one), because nine
   breakers ending in the same crater makes the choice between them only a damage number.
4. **Name each foe's answer in code and on screen** (Triple Chop breaks shields, throw a lit bomber, Black Tide
   pulls the back line, Overwhelm holds the heavy), because the hooks exist in `enemy.gd` and nothing teaches them.
5. **Split the overlaps**: rename the air Live Wire, Steam Burst becomes the room-wide frozen cash-out, Black Ice
   leaves them frozen (setup) while Maw is the payoff, because duplicates make the tree look bigger than its choices.
6. **Make the element matrix uneven and teach it as two rules**, because a table where every cell pays has no
   decisions in it.
7. **Make the combo counter and rank react** (drop on a hit or a pause, grade by wall splats, matrix cells, PERFECTs
   and guard breaks), because 418 HITS SSS for a whole session is not feedback.
8. **A counter window after a perfect dodge**, because the dash is the only defence and a payoff for using it well
   is what makes defence part of "intentional".
9. **Tint the dummies away from the hero's cream and colour hit stars by element**, because in every crowded frame
   the hero and the element are lost in cream bodies and yellow stars.
10. **One element shape per breaker impact frame and smaller per-hit numbers on lights**, because the numbers are the
    loudest thing on screen and every breaker lands on an identical frame.
