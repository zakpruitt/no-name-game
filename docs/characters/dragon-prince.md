# The dragon prince (second hero, design draft)

Status: round 42 d, first playable slice built (`--hero=prince`, section 10) on a placeholder body; the open
questions (section 9) are still unanswered, so the slice runs on this doc's recommended defaults, each behind a
named constant. No model or clips of his own yet. Working name **Prince Aurex**, heir to
the Ember Throne; his summoned sword is **Sunbrand** (every one he conjures is a fresh Sunbrand). Names are
placeholders (open question 8).

Zak's brief: "a spellblade younger dragon prince... throwing sword, flying up and smashing into it to explode it
then resummoning a new magic sword... casting dragon abilities like an evoker... lots of royal sword play (think
Excalibur) and maybe some kingly/pride features." Design rule for every move: it has a good time to use it, and a
player who uses it on purpose is very strong.

Same input scheme as the heretic: **L** light, **H** heavy (right click), **Dash**, **hold** (L or H). Same
machinery where it fits: named strings, enders with timed breakers, element states that other elements cash in,
the style rank and Awakening.

## 1. Pitch and personality

Aurex is a teenage dragon prince who fights with a magic greatsword he throws, plants and blows up, then
conjures again with a flourish. Between swords he fights with dragon magic: fire breath, wing bursts and the
claws and tail of the dragon he will one day become. He is royalty and he knows it, and the better he fights the
more regal (and smug) he gets, right up until someone dares to hit him.

The heretic is a hunched, hooded thing that grabs and drags. Aurex is the opposite: upright, open-faced, bright,
always moving up and down (throw, rise, dive), and his rhythm is **set up, cash in, re-arm**, not grab and slam.

How pride shows:

- **Idle:** chin up, sword planted point-down in front of him, both hands on the pommel (the sword-in-the-stone
  pose). Every few seconds he polishes the crown with his sleeve or checks his reflection in the blade.
- **Taunt / flourish:** twirls the sword round his wrist, plants it, flicks his cape. At high Majesty he adds a
  "hmph" and a slow golf clap for himself.
- **Victory (room cleared):** stands on a rubble pile, raises the sword, a small gold sunburst behind him like
  the face of a coin. If he took no hits, the crown sparkles and he winks.
- **Getting hit:** pure offence taken. Eyes go wide, mouth an outraged little "o", the crown tilts. A second hit
  knocks the crown off and he scrambles after it (section 5). A heavy hit sits him on his bottom with stars and
  a puff of smoke from his nostrils.
- **Low health:** still proud; he stands taller, not hunched, but his wings droop and the tail lashes.

## 2. Core mechanic: the thrown sword

The sword is the centre of the kit. Where it is decides what every button does, so the player must always be
able to answer "where is my sword?": a small sword icon by the hero (gold = in hand, an outline pointing at it =
out, cracked = re-forming), and a beacon line over the sword itself.

### The sword states

| State | What it means | Shown as |
|---|---|---|
| **In hand** | sword attacks on L; H is dragon magic or a throw | sword in his grip, gold edge glint |
| **Out**: planted in the floor, planted in a foe (**branded**), or **aloft** (spinning in the air) | his hands are empty; L becomes conjured dragon claws; the sword is a target to recall or smash | glowing sword, a sapphire beacon line up from it |
| (in flight) | 150-250 ms between the throw and the landing; counts as out | spinning blade with a short ink trail |
| **Shattered** | the sword just exploded; a new one is forming | gold shards spiralling back to his hand, a gleam at the sweet spot |

### Recommended rule set: "One Sword" (A)

There is exactly one Sunbrand. Throwing it costs him the sword; getting it back is a choice.

**In hand**
- L: the sword string (fast, wide, the most damage per hit of anything he has).
- H after L presses: the L count picks the H, like the heretic's L count picks the element:
  - after 1 L (L H): **no throw**, a breath flick past the blade (the safe opener).
  - after 2 L (L L H) **Javelin**: straight and fast (about 22 m/s, 9 m range), through the first foe, carrying it
    up to 4 m and pinning it to a wall if one is in range. Sword: in that foe (or the floor on a whiff).
  - after 3 L (L L L H) **Sword in the Stone**: drives it into the floor at his feet; a ring knocks foes back
    2.5 m. Sword: in the floor where he stands.
  - after the launcher (L H H) **Heaven Toss**: thrown straight up over the launched foe, it hangs aloft 900 ms.
- H with no string: dragon breath. Dash L: lunge. Hold H: Sovereign Light (the beam). Hold L: Royal Flourish
  (the parry).

**Out (any kind)**
- L: the **Talon** string, conjured dragon claws: faster than the sword, about 60% of its damage, shorter reach.
  Never a dead state; he is still dangerous empty-handed, just less so.
- H: **the smash**. He beats his wings and rises (about 2.5 m in 300 ms) over the sword, hangs, and dives
  pommel-first onto it. It explodes: big damage in a 3.5 m ring, more from higher, x1.5 if the branded foe is
  pinned to a wall. The dive uses the breaker machinery (`hero_leap.gd`): a window opens in the hang, a press at
  the sweet spot is a PERFECT, a press before the window locks it out and he floats down with the sword still
  out. If he's more than 9 m from the sword, H is breath instead (the beacon greys out to say so).
- Hold L (200 ms): **Rightful Return**, the recall. The sword flies back along a straight line in about 250 ms,
  hitting everything on the line; a branded foe is dragged with it to his feet. Sword: in hand, no re-forming wait.
- Dash: still his dash; the sword stays where it is.
- After 6 s out, the sword comes back by itself (no hit), so he can't be stuck clawing forever.

**Shattered**
- The new sword forms in his hand 700 ms after the blast.
- **Royal Draw:** L at the gleam (450 ms after the blast, a 120 ms window) draws it out of the air with a forward
  slash that hits: a PERFECT resummon that gives Majesty and empowers the next sword move (x1.3, longer reach).
  Too early does nothing; the 700 ms form still happens.
- H while shattered: breath (he is not helpless while it forms).

### Risk, payoff, positioning

- **Throwing is a commitment.** Out, he has claws only: shorter reach, no beam. A missed Javelin plants the sword
  9 m away in the floor; now he walks there, recalls it (a line hit, but he's empty-handed until it arrives), or
  smashes it from range (the 300 ms rise happens in the open).
- **Smashing is the payoff and the second commitment.** His biggest damage, but it shatters the sword (700 ms
  swordless, 450 with the Draw) and he lands where the sword was, not where he was.
- **Recall is the safe cash-in.** Less damage, keeps the sword, and the return line is a weapon. **Stand so the
  crowd is between you and the sword**, then recall through them.
- **The sword is a zone.** A planted sword is a bomb the foes don't respect: plant it, kite the crowd over it,
  smash. A sword in a foe moves with the foe (a carried bomb). A sword in a foe pinned to a wall doesn't move,
  and the wall throws the blast's back half at the crowd (x1.5, the wall payoff).
- **Up and down.** Smashes and Heaven Toss put him 2-4 m up. Rising under archers is a risk; rising out of a
  melee crowd is an escape.

### Alternative B: "Armory"

Every throw leaves a sword behind and a new one forms in his hand at once. Up to three can be out; the smash
blows up all of them in a chain (nearest first, 120 ms apart), each smaller.

- Good: constant swordplay, no empty-hand state, a great chain-explosion picture.
- Bad: throwing costs nothing, so the right play is "throw always"; the position decision shrinks to "where do my
  three bombs go"; the claw kit loses its reason to exist.

### Alternative C: "Tethered Blade"

The sword is on a chain of gold light and never leaves him; H yanks him to it or it to him.

- Good: simple, never lost, great mobility.
- Bad: it's the heretic's tentacle again (grab, pull, slam), and nothing explodes.

### Recommendation

**A, One Sword**, with B as a **reward**: at Majesty tier 3 he carries a **spare sword** (section 5), so a throw
at tier 3 leaves him armed and a smash can blow up two swords. Most of the time a throw costs something; the
player who keeps his crown on earns the Armory.

## 3. Dragon magic

Evoker flavour: short, punchy breath and wing spells, a few with hold-to-empower release levels, all ending back
on the sword. The magic is what he does **between** sword beats: H with the sword in hand, L and H while it's
out, and the shatter gap. It never takes over a whole string.

- **Dragon Breath (H, neutral):** a short fire cone (60 degrees, 4 m) in 350 ms; **kindles** what it touches.
  His safe opener into a crowd in front, and his cover while the sword re-forms.
- **Empowered Breath (hold H, sword out or shattered):** release levels like an evoker's empowered spells.
  Level 1 (by 350 ms) a wide 5 m cone; level 2 (by 750 ms) a 9 m cone that pushes; level 3 (by 1150 ms, he
  glows and the camera nudges in) **Dragonroar**, a dragon's head of fire that roars 12 m in a line and leaves a
  burning stripe for 2 s. Held 500 ms past level 3 it fires itself. A hit while charging cancels it.
- **Sovereign Light (hold H, sword in hand):** the same three levels for the sword's light-blade. Level 1 a gold
  crescent wave (6 m); level 2 a 10 m beam that pierces; level 3 a screen-length beam that leaves foes
  **humbled**. Big damage, but he stands still for the whole charge. The Excalibur moment.
- **Wings:** every rise (the smash, Heaven Toss, Wingbeat) uses them. While up, holding H hovers him for up to
  800 ms to choose the dive moment and target (sword out: onto it; no sword: a plain wing-dive stomp).
  **Wingbeat (Dash H):** a back-hop on a wing blast that knocks the nearest foes back 3 m and lifts him 1.5 m:
  his panic button and his way up.
- **Conjured limbs:** the Talon string (empty-handed L) is a flame-and-gold dragon claw over his own hand: two
  rakes and a grab-throw. **Tail Sweep** (H H) is a huge conjured tail that spins round him and launches. Ink
  outlines filled with flat flame (section 7), so they read as magic, not body parts.
- **Dragon form (his Awakening activation):** **Ascension**: for 1.5 s he becomes a squat chibi dragon drawn in
  flame outline, roars (the burst, the same knockback as the heretic's), then shrinks back, keeping glowing
  horns, bigger wings and a breath puff on every sword ender for the buff. A burst, not a mode: the kit stays
  the sword.

### Elements and colour identity

Three damage types, each with a colour, an effect language and a state:

| Type | Colour (`fx_palette`) | Moves | State it leaves |
|---|---|---|---|
| **Steel** (the sword) | `gold` (already in the palette) | the sword string, throws, recall | **branded**: the sword is planted in it (one foe at a time) |
| **Dragonfire** (breath, claws, tail) | new `dragonfire`: crimson deep, flame-orange body, gold light, white hot (redder than `earth`'s magma orange) | breath, Talon, Tail Sweep, Wingbeat | **kindled**: embers, stacking to 3 |
| **Radiance** (light-blade, blasts) | new `royal`: sapphire deep, sky-blue body, white light (the accent) | Sovereign Light, the smash's blast, Royal Draw | **humbled**: on its knees 1.2 s, takes x1.25 |

Sapphire keeps him from being all orange: it's the magic inside the sword (the summon, the rune line on the
blade, the beam's core) and his eyes. Gold is the metal and the crown; dragonfire is the breath.

His states crossed with his types, the same shape as [element-matrix.md](../features/element-matrix.md) (an
`IMPROV`-style payoff with a tell and a word per cell):

| State | steel | dragonfire | radiance |
|---|---|---|---|
| **kindled** | **Searing Edge**: sword hits burn x1.3 and spread one ember to the nearest foe | stacks; at 3, **Flashpoint**: it bursts and hits round it | **Sunburst**: the blast ignites the embers, x1.5 and a second ring |
| **branded** | recall drags it to him (the move's own) | **Heat the Blade**: breath on it makes the sword glow; the next smash x1.4 | the smash centres on it (the move's own), x1.5 at a wall |
| **humbled** | **Coup de Grace**: the first sword hit x2, ends humbled | **Brimstone**: breath gives 3 embers at once | refreshed, no bonus |
| **airborne** | the air string (Wing Slash), Starfall | **Firefall**: breath from a hover drops them burning, x1.3 | **Skewer Light**: a level 2 beam pins them in the air 600 ms |

If the two heroes ever share a room, or the prince gets the heretic's elements as upgrades: kindled counts as
**molten**, humbled as **bound**, branded as **skewered**, airborne as airborne. One matrix, not two.

## 4. Royal swordplay

Big clean arcs: the hilt high, the blade turned flat to the camera at the end of each swing so the silhouette
reads as a cross or a sunburst from above. Nothing hacks; everything cuts and poses.

- **Stances, light version:** each sword ender leaves him in a short **pose** (High Guard after Crown Cleave, Low
  Guard after the Stone plant, Point Forward after a lunge). Starting the next string from a pose within 400 ms
  gives it a faster first swing (x1.2) and Majesty. No stance-switch button: a reward for the rhythm strike,
  pose, strike.
- **Flourishes:** Royal Draw and Rightful Return end in a one-handed twirl; a smash lands him on one knee, and he
  stands as the new sword forms.
- **Sword in the Stone (L L L H):** the plant. It stays as his zone; idle near it and he leans on the pommel.
  **Pull from the Stone** (hold L within 1.5 m of it) is a rising draw that launches the foes round it: a second
  payoff for the plant besides the smash.
- **The beam:** Sovereign Light (hold H, sword in hand; section 3).
- **Guard and parry, Royal Flourish (hold L, sword in hand):** a 500 ms twirl in front of him. A melee hit or
  projectile landing in its first 200 ms is **parried** ("TING!", a short freeze, the attacker staggered 0.8 s,
  projectiles knocked back). After 200 ms it's a taunt: hits land, but finishing it untouched with a foe within
  4 m gives Majesty (showing off on purpose, in danger).
  - After a parry, L is **Insolence**, the regal counter: a thrust and an over-the-shoulder flick, x2, ends in a
    pose. H is **Kneel**: the flat of the blade bonks the foe's head and it's humbled.
  - Risk: a whiffed parry is 500 ms of twirling in front of whatever was swinging. Big telegraphed windups (the
    Warden's cleave, the mage's bolts) are the targets.

## 5. Pride: the kingly mechanic

### Option 1: Majesty (a tiered meter and a crown that falls)

A small three-tier meter that fills in seconds, not over a fight like Awakening. It fills from style: a move
unlike the last two, a PERFECT smash or Royal Draw, a parry, a flourish finished near foes, a blast that hits 3+,
a string started from a pose.

| Tier | Title | Gives | Looks |
|---|---|---|---|
| 0 | Princeling | nothing | plain circlet |
| 1 | Prince | +10% damage | the circlet glints, the cape swings fuller |
| 2 | Heir | +20%, throws pierce one more foe, blast radius +25% | crown grows two points, sword edge gold |
| 3 | King | +30%, the **spare sword** (a second Sunbrand at his hip: rule set B for one throw), a Decree ready | full crown, gold rim light, sparkles on the sword |

A hit drops **one tier** and tilts the crown. A hit at tier 1, or a heavy hit at any tier, knocks the crown off:
it bounces 2-3 m away and lies on the floor. Walk over it (he jams it back on, huffy) to return to tier 1 at once;
leave it and it re-forms on his head after 6 s at tier 0.

- Risk: chasing the crown through a crowd. Reward: a clean player lives at tier 2-3, which is most of his power.

### Option 2: Decrees (spend Majesty)

The same meter, but tiers do nothing by themselves; Majesty is spent on **Decrees**, spoken commands (L + H
together; open question 4): "KNEEL!" (every foe in 8 m humbled), "BEHOLD!" (the next smash x2, the camera pulls
out), "BEGONE!" (a radial knockback that wall-splats).

- Risk: low, nothing breaks. Reward: strong, deliberate crowd control, but it's an ability bar, not pride.

### Option 3: Pride stacks (all or nothing)

No tiers: every 4 s untouched gives a stack (max 5), each +8% damage and a bigger crown. Any hit takes them all.

- Risk: very high. Reward: simple, but it punishes long fights where a hit is unavoidable, and there's nothing
  to do with it except not get hit.

### Recommendation

**Option 1, Majesty with the falling crown, plus one Decree as the tier 3 cash-out.** At King the player can
keep tier 3 for its buffs and spare sword, or spend it all on "KNEEL!" for a room-wide humble and then Coup de
Grace or Kingsfall the kneeling crowd. Both are right at different times: keep it against a few big foes, spend
it when a crowd closes in.

**Beside Awakening, not instead of it.** Awakening stays the shared slow meter (style rank fills it, same `Game`
code), and his activation is Ascension (section 3). Awakening is the fight's arc; Majesty is the last ten seconds.
One clash to fix: the heretic's Awakened look is gold (`hero_awaken.AWAKEN_COLOR`), which is Aurex's everyday
colour, so his Awakened tint should be white-hot dragonfire with sapphire rims (open question 5).

## 6. Move list

Sword: **H** in hand, **O** out (floor / foe / aloft), **S** shattered. Breakers open the slow-motion window like
the heretic's (H dives; L is the alt where listed).

| Input | Name | What it does | Sword | Best when | Leads to |
|---|---|---|---|---|---|
| L L L | **Royal Chain** (Slash, Riposte, Crown Cleave) | three wide gold arcs, the last an overhead with a light flare; ends in High Guard | H > H | a group in front, nothing set up yet | breaker **Judgement**; L L L H |
| *breaker off Crown Cleave* | **Judgement** (H) / **Royal Descent** (L) | H: from the top of the leap he hurls the sword into the pile and dives onto it: it detonates (throw, fly, smash in one). L: plunges sword-first and keeps the sword, smaller | H > S / H > H | H on a big pile at high Majesty; L when archers are about and he can't be swordless | Royal Draw after H |
| L H | **Ember Flick** | a slash and a breath puff past the blade: kindled | H > H | opening on a fresh foe | L H L, L H H |
| L H L | **Searing Edge** | two fast cuts that eat kindled (x1.3 each) | H > H | after anything that kindled | L L L |
| L H H | **Heaven Toss** | Tail Sweep launches the foe; he throws the sword straight up over it, aloft 900 ms | H > O | one tough foe; starts the air game | Wing Slash, Starfall |
| L H H L | **Wing Slash** | wings up after the foe, two claw rakes in the air under the hanging sword | O > O | keeping a juggle up while the sword hangs | Starfall |
| L H H H (or L H H L H) | **Starfall** | flies to the aloft sword and kicks it down through the airborne foe into the floor, then dives after it: a crater blast (**route 1**) | O > S | an airborne foe over a crowd: the crater hits everything under it | breaker **Meteor Crown**; Royal Draw |
| *breaker off Starfall* | **Meteor Crown** (H) | he catches the shards in the air and rides them down as a falling ring of eight swords | S > S | the crowd bunched round the crater | Royal Draw |
| L L H | **Javelin** | straight throw through the first foe, carried 4 m, pinned if a wall is in range: branded | H > O (foe) | foes in a line, or one near a wall | Skyfall, Rightful Return |
| L L H H | **Skyfall** | rises 2.5 m and dives pommel-first onto the branded foe: blast, x1.5 if it's pinned to a wall (**route 2**) | O > S | the foe is pinned to a wall, or was carried into the crowd | breaker **Coronation**; Royal Draw |
| *breaker off Skyfall* | **Coronation** (H) / **Abdicate** (L) | H: a second rise; a ring of shards forms round the zone and he slams them in. L: kicks off the blast up and back 6 m and lands with the sword already re-formed | S > S / S > H | H for damage on a crowd; L to get out with a sword in hand | |
| L L L H | **Sword in the Stone** | drives the sword in at his feet, 2.5 m knockback ring; Low Guard | H > O (floor) | surrounded: buys space and leaves a bomb in the middle | Kingsfall, Pull from the Stone, Talon Fury |
| L L L H H | **Kingsfall** | rises highest (3.5 m) and drives into the stone sword: the biggest blast (5 m), throwing foes outward into walls (**route 3**) | O > S | he kited the crowd back over the stone; walls close by for splats | breaker **Sundering**; Royal Draw |
| *breaker off Kingsfall* | **Sundering** (H) | the floor cracks in a gold cross from the crater; four light pillars erupt along its arms | S > S | foes thrown outward by the blast | |
| Dash L | **Lunge Royale** | a long point-first thrust that brakes on the first foe; Point Forward | H > H | closing on one foe | Royal Pin |
| Dash L H | **Royal Pin** | the lunge, then the sword hurled point-blank through the foe: it flies up to 6 m and pins it to the nearest wall (**the wall payoff**, route 4 with Skyfall) | H > O (foe, wall) | a foe 3-6 m off a wall | Skyfall x1.5, Rightful Return (rips it off the wall) |
| L L L (sword out) | **Talon Fury** | conjured claw: rake, rake, grab and throw over the shoulder | O > O | the sword is out as a bomb and he wants to keep it there | the smash, recall |
| H | **Dragon Breath** | short fire cone: kindled | any | a crowd in front, or covering the shatter gap | H H, Heat the Blade |
| H H | **Tail Sweep** | conjured tail spins round him and launches | any | surrounded with no plant ready | Wing Slash, the air string |
| Dash H | **Wingbeat** | back-hop on a wing blast: knockback 3 m, up 1.5 m; hold H to hover | any | escape, or getting up for a hover and a dive | any smash, Firefall |
| hold H (in hand) | **Sovereign Light** | light-blade release, levels 1-3 (crescent / piercing beam / screen beam: humbled) | H > H | foes in a line at range, or a boss's punish window | Coup de Grace |
| hold H (out / shattered) | **Empowered Breath / Dragonroar** | levels 1-3 (wide cone / long pushing cone / dragon-head line, burning floor) | O, S | holding ground while the sword waits as a bomb or re-forms | Flashpoint |
| hold L (in hand) | **Royal Flourish** | 200 ms parry, then a taunt twirl; then L **Insolence**, H **Kneel** | H > H | a big telegraphed windup or a projectile | Insolence, Kneel |
| hold L (out) | **Rightful Return** | recall along a line, hitting all on it; drags a branded foe to him | O > H | the crowd is between him and the sword | Royal Chain, Royal Flourish |
| hold L (by the stone) | **Pull from the Stone** | rising draw out of the floor, launches everything within 2 m | O > H | the crowd came back round the stone and he wants the sword, not the blast | Wing Slash |
| L at the gleam (shattered) | **Royal Draw** | draws the new sword out of the air with a slash: PERFECT resummon, Majesty, next sword move x1.3 | S > H | after every smash: it's the skill check | any sword string |
| L + H (King) | **Decree: KNEEL!** | spends tier 3: every foe in 8 m humbled 1.2 s | any | a crowd closing in at tier 3 | Coup de Grace, Kingsfall |

Counts: 16 strings (Royal Chain, Ember Flick, Searing Edge, Heaven Toss, Wing Slash, Starfall, Javelin, Skyfall,
Stone, Kingsfall, Lunge Royale, Royal Pin, Talon Fury, Dragon Breath, Tail Sweep, Wingbeat), the casts, parry,
recall, pull and Draw, and five breakers (Judgement, Meteor Crown, Coronation, Sundering, plus Royal Descent and
Abdicate as alt endings). Throw, fly, smash, resummon routes: Judgement, Starfall, Skyfall, Kingsfall, and Royal
Pin into Skyfall at a wall.

A good intentional loop: **Ember Flick > Searing Edge > Javelin** into the middle of the crowd > **breath** on
the branded foe (Heat the Blade) > **Skyfall**, PERFECT > **Royal Draw** at the gleam > **Royal Chain** from
the pose. Every press is a choice, four payoffs land, and the crown stays on.

## 7. Look

### Body

- Chibi: head a third of his height, big amber eyes with sapphire pupils, a short sturdy body, big hands and
  boots. About 1.9 m in the GLB (shorter than the heretic's 2.05 m; he's young), but horns, crown and sword give
  him the same area at the game camera.
- **From above (the view that counts):** two swept-back horns with a crown between them, two small folded wings
  at the shoulders, a thick tail, and the sword: as long as he is tall and wider than it has any right to be.
  The sword is the one oversized signature part.
- **Face:** open, young, cocky: big eyebrows (they do the acting from above), a smug half-smile, one fang.
  Expressions: smug (default), delighted (PERFECT), outraged (hit), focused squint (charging), wink (victory).
  Drawn as decals over the face like the heretic's grin (`heretic_rig.gd` `GRIN`), so they read from 13 m up.
- **Palette (four plus an accent):** crimson-red scales (horns cream), gold (crown, crossguard, pauldron), cream
  (tabard, cape lining), deep navy (cape, boots), and the **sapphire** accent (eyes, the blade's rune line, the
  wings' membrane glow). Cream and gold read on the indigo floor; the navy needs the paper rim like the
  heretic's body.
- **Clothes:** a short tabard over a tunic, one pauldron, a half-cape on the left shoulder only (so the wings
  show), big boots. No buckles, crests or patterns (they turn to speckle).

### The sword and the magic, in thin ink

- **Sunbrand:** a broad simple greatsword: a wide flat blade with one sapphire line down the middle, a gold
  crossguard shaped like spread wings, a round pommel. Flat gold body, light edge, 2 px ink, nothing engraved.
- **Summon:** gold shards swirl in on a sapphire spiral line, snap together, an ink star at the tip, on twos.
- **Planted sword:** a thin sapphire beacon line straight up and a halftone gold ring on the floor; it pulses
  faster while he hangs over it.
- **Blast:** a flat gold star with a sapphire core, eight thin ink rays, a halftone floor ring, shards as flat
  gold diamonds flying out.
- **Breath:** flat flame tongues in `dragonfire`, ink only on the outer edge, halftone dots inside the cone; no
  particles or glow sprites.
- **Conjured claws, tail, dragon form:** ink outlines filled flat (`comic_flat.gd`), dragonfire body with gold
  light, the way the heretic's spirit axes are spectral: a ghost limb, not a second body.
- **Words (5):** **SHWING!** (summon, Royal Draw), **KRA-BLAMM!** (the smash), **FWAROOO!** (breath,
  Dragonroar), **TING!** (parry), **HMPH!** (flourish, taunt, Majesty up). None is in `comic_fx.gd`'s `WORDS`,
  `MOVE_WORDS` or `BREAKER_WORDS` today.

### Three silhouette variants

1. **Horned Heir:** big swept-back horns, a small crown sitting between them, small folded wings, half-cape, thick
   tail. From above the horns and crown make a clear "W" at the head and the wings two triangles at the
   shoulders. The crown can tilt and fall without taking the horns with it.
2. **Crowned Hatchling:** a dragon-skull helm with the crown built in, no visible horns, a long tail, tiny wings.
   Cuter and less human, but a helm hides the face (the hood taught us a hidden face loses the acting), and a
   crown fixed into a helm can't fall.
3. **Sky Knight:** big open wings as the signature, no cape, slim tail, small horns, a circlet. Reads well from
   above, but big wings cover the sword swings from the camera, fight every clip, and are the hardest thing to
   rig (the tentacle problems, twice).

**Pick 1, Horned Heir.** The sword stays the signature part, the horns and crown carry the head from above, and
the wings stay small enough to fold.

### A Meshy prompt for later (do not generate yet)

Following [meshy-pipeline.md](../features/meshy-pipeline.md) and the art-direction template: "chibi cartoon"
first, arms out in the text (no `pose_mode`), gaps between parts, **no weapon** (the sword is its own mesh; a
fused weapon leaves no grip), wings and tail clearly apart from the body. Under 800 characters:

```
Chibi cartoon game hero, a proud young dragon prince, full body, standing straight with both arms held out
away from the sides, hands open. Huge head about a third of his height, big bright eyes, smug grin, two large
swept-back cream horns and a simple gold crown between them. Short stocky body, oversized hands and boots. Red
scaly skin. Two small folded red wings on his back, clear gap from the arms. A thick red tail behind, clear gap
from the legs. Short cream tabard, one gold shoulder plate, navy half-cape on the left shoulder hanging apart
from the body. Bold simple shapes, large flat colour regions, only 4 colours: red, gold, cream, navy. Cartoony
and playful but badass. No small ornaments, no patterns, no text, no weapon.
```

Rig notes in advance: the tail wants its own chain traced from the tip (the tentacle method in
`heretic_rig.py`), each wing a two-bone chain with the membrane weighted along it, the half-cape a few spring
chains (the skirt's), and the crown a separate mesh on the head bone so it can tilt and come off. Budget: 30
credits for the model and 10 for a retexture, under the 200 cap.

## 8. Build

### Clips (about 45)

| Group | Clips |
|---|---|
| Locomotion | Idle (pommel pose), Idle_Ready, Run_F, Run_Stop, Dash, Hurt (outraged), Hurt_Big (sits down), Death, Victory, Crown_Pickup |
| Sword | Slash, Riposte, Crown_Cleave, Searing_Edge (2 cuts), Lunge, Throw_Javelin, Throw_Up, Plant, Pull_Stone, Recall_Catch, Royal_Draw, Flourish, Insolence, Kneel_Bonk, Charge_Beam (loop), Release_Beam |
| Magic | Breath, Charge_Breath (loop), Release_Roar, Talon_1, Talon_2, Talon_Grab, Tail_Sweep, Wingbeat |
| Air | Rise, Hover (loop), Dive_Pommel, Land_Kneel, Wing_Slash_1, Wing_Slash_2, Starfall_Kick, Air_Fall |
| Pride | Taunt (self-clap), Crown_Tilt (additive, head only), Decree (point and shout), Ascension (in / out) |

The heretic's clips are hand-keyed headless (`chibi_keys.py`); the same route applies (skill
`blender-rig-animate-character`).

### Reuse vs new code

| Piece | Reuse | New | Size |
|---|---|---|---|
| A second hero at all | `player.gd`'s state machine, `hero_input.gd`, `combo_guide.gd`, `move_list.gd`, the checks' shape | `player.gd` assumes the heretic (`_void`, `void_route()`): a hero selector (`Game.HERO`), `prince_moves.gd` with the same `MOVES` / `COMBOS` / route shape, a `prince_route()` | **L** (the real first cost) |
| Thrown sword entity | `frost_spear.gd` (a planted, timed weapon in the floor), the Harpoon tip's line hit, `thrown_foe.gd` (carry, wall pin) | `sunbrand.gd`: held / flight / floor / foe / aloft / shattered, recall path, beacon, auto-return | **M** |
| The smash | `hero_leap.gd`'s leap, window, dive and PERFECT, with `at_spot` aiming (it already dives onto a spot) | the spot is the sword; a smash that uses the window without being an ender's breaker | **S-M** |
| Summon and Royal Draw | `breaker_cue.gd` / `breaker_prompt.gd` timing rings | the gleam window, the shard return | **S** |
| Hover and rise | `hero_moves.hop()`, `air`, `climb`, `AIR_MAX_HEIGHT`, `air_home()` | hold-H hover with a cap, dive target | **S** |
| Empowered casts | State.CHARGE (`VOID_ELEMENT.CHARGED`, hold H) | release levels by hold time, a level ring, cone and line hit shapes | **M** |
| States and cells | `void_element.IMPROV`, `improvise()`, `comic_improv.gd` tells | three types, four states, his table | **M** |
| Majesty and crown | style rank, `Game.add_awakening`, the HUD meter | tiers, the crown as a falling prop, pickup | **S-M** |
| Parry | perfect-dodge timing (`perfect_dodge_*`) | the hold-L parry window, the two counters | **S** |
| Model, rig, clips | the Meshy pipeline, `heretic_rig.py` chain tracing, `chibi_keys.py` | wings, tail, crown, sword mesh, 45 clips | **L** |
| Effects | `comic_flat.gd`, `comic_fx.gd` words, `fx_palette` | `dragonfire` and `royal` palettes, breath cone, blast star, summon spiral | **M** |

### First playable slice, in order

Built so far (round 42 d, section 10): 1, most of 2 (Royal Chain, Javelin, Skyfall, an automatic re-form; no Royal
Draw), recall and the Talon claws from 3, and Dragon Breath from 4 (no kindled).

1. **Hero switch on a placeholder body:** the heretic's model with a box sword, the prince's route and moves
   table behind a flag (`--hero=prince`). Proves a second hero can exist without touching the heretic. L.
2. **Royal Chain, Javelin, Skyfall, Royal Draw** on the training dummies: one throw, one smash, one resummon.
   That's the whole fantasy in four moves; if it isn't fun here nothing else will save it. M.
3. **Recall and Talon Fury** (the empty-hand state), so a throw has a real cost and a real alternative. S-M.
4. **Dragon Breath, kindled, Heat the Blade**: the first magic and the first cash-in. M.
5. **Stone, Kingsfall, Royal Pin**: the zone and the wall payoffs. M.
6. **Majesty and the crown.** S-M.
7. Then the model, rig and clips, and the rest of the list.

## 9. Open questions for Zak

1. **One Sword or Armory?** Recommend One Sword with the Armory as the tier 3 reward. The fork: should a throw
   ever cost him the sword?
2. **The smash: H any time the sword is out, or only from strings and breakers?** Recommend any time: it's his
   signature; the 9 m reach and the 300 ms rise are its cost.
3. **Royal Draw: timed or automatic?** Recommend timed (PERFECT with a reward, the 700 ms auto form as the
   floor): every smash becomes a two-beat skill check, like a breaker.
4. **The Decree's input:** L + H together, or automatic at tier 3? Recommend L + H: one more input, but a
   deliberate one, and nothing else uses the chord.
5. **His Awakened colour:** gold is his everyday colour. Recommend white-hot dragonfire with sapphire rims for
   him, gold stays the heretic's.
6. **Does the crown really fall (a prop to chase) or just dim?** Recommend really: it's the funniest, most
   readable thing in the kit, and chasing it is the risk Majesty needs.
7. **Second hero now as a pick, or a swap inside a run later?** Recommend a pick in the training room first
   (flag, then a menu), no in-run swapping until both kits are tuned.
8. **Names:** Aurex and Sunbrand are placeholders. Keep them, or name him yourself? (Recommend a short
   two-syllable name the callouts can shout.)

## 10. Built: the first slice (round 42 d)

> **Removed 2026-11-08.** The code described below (`scripts/prince/`, `tests/prince_check.gd`, `prince_film.gd`,
> the `--hero=prince` flag and the hooks in shared files) was cut in the cleanup pass (`docs/cleanup-2026-11-08.md`);
> it lives in git history before that date. This section stays as the record of how the slice was built, so a
> second attempt starts from it rather than from nothing.

Launch: `godot --path . -- --hero=prince` (training room, the dummies). Without the flag the game is exactly the
heretic as before (`Game.hero` defaults to `"heretic"`; main.gd loads the prince script only when asked).
Check: `godot --headless --path . -s tests/prince_check.gd` (in `agent.sh check`). Film: windowed
`godot --path . -s tests/prince_film.gd [-- --dir=name]` (30 fps to `user://prince_film/`, INDEX.txt per frame).
Clip: `awaken-combo-clips/13 Dragon Prince core loop.mp4`.

### What plays

| Input | Move | Sword | What it does in the slice |
|---|---|---|---|
| L L L | **Royal Chain** (Slash, Riposte, Crown Cleave) | H > H | three gold arcs, the Cleave a big overhead (tier 1 callout) |
| L H | **Ember Flick** | H > H | a slash plus a breath puff at 0.6 of Dragon Breath |
| L L H | **Javelin** | H > O | throws Sunbrand straight (22 m/s, 9 m): it bites the first foe on its line (16, carried by the knockback) and stays in it, riding along; a whiff or a wall plants it in the floor |
| H (sword out, within 9 m) | **Skyfall** (the smash) | O > S | rises 2.5 m in 0.3 s over the sword (it keeps tracking a branded foe), hangs 0.14 s, dives in 0.13 s (invulnerable on the dive); the sword explodes: 34 in 3.5 m, knockback and launch; "KRA-BLAMM!", tier 3 callout, big hitstop and camera kick; 0.3 s on one knee (dash cuts it) |
| (after the blast) | re-form | S > H | a new sword forms in his hand 700 ms after the blast ("SHWING!", a sapphire star and a gold hoop) |
| hold L (sword out) | **Rightful Return** | O > H | the sword flies back in 0.25 s along a line, hitting all on it (9 each); the foe it was in is hit and dragged toward him. The press starts a Talon, the hold (0.2 s) turns it into the recall |
| L (sword out or shattered) | **Talon** string (Talon Fury on the third) | O > O | conjured claws: two rakes and a heavy, about 60% of the sword, shorter reach, orange arcs |
| H (in hand, no string; or out of reach; or shattered) | **Dragon Breath** | any | a flat dragonfire cone, 60 deg x 4 m, two ticks of 6 ("FWAROOO!") |
| L L L H | (placeholder) | H > H | breathes (`PRINCE_MOVES.LLLH_FALLBACK`) until Sword in the Stone exists |
| Dash | dash | any | the heretic's dash; the sword stays where it is |
| (6 s out) | auto-return | O > H | the sword flies home with no hits |

Where it lives: `scripts/prince/prince.gd` (extends player.gd; his own `_physics_process`, states, hits, the smash
phases, the callout, `guide_rows()` and `move_sections()`), `prince_moves.gd` (MOVES / COMBOS in the heretic's shape,
`route()`, the MOVES panel's `SECTIONS`), `sunbrand.gd` (the sword: HELD / FLIGHT / PLANTED / RETURN / SHATTERED,
bite, recall line, blast, re-form timer, beacon and floor ring), `prince_fx.gd` (the placeholder dressing and his
effects). Shared files got one-line hooks only: `Game.hero` + the `--hero=prince` parse (game.gd), the script pick
(main.gd), `player.guide_rows()` if the hero has it (combo_guide.gd), `player.move_sections()` if the hero has it
(pause_menu.gd), and `prince_check` in agent.sh's list.

Look (placeholder): the chibi heretic's body with its toon bands multiplied crimson / gold (`PRINCE_FX.TINT_*`), a
five-point gold crown with a sapphire gem and two big cream horns swept back on the head bone, the heretic's weapon
meshes hidden, and a built Sunbrand (wide pale-gold blade with a sapphire line, winged gold guard, navy grip, round
pommel, inked) on the right hand along the axe's line. Out in the world it is the same mesh, point down, with a
thin sapphire beacon line and a pulsing gold floor ring (faster during the smash's rise). The weapon trail follows
the sword. The tentacle, hood and the heretic's glowing eyes and grin still show: it is his body.

### Assumptions on the open questions (each a named constant)

1. **One Sword** (`PRINCE_MOVES.ONE_SWORD = true`): a throw costs the sword until smash, recall or the 6 s
   auto-return (`SUNBRAND.AUTO_RETURN`). The Armory flag exists but nothing reads it yet (it needs a second sword).
2. **The smash any time the sword is out** (`PRINCE_MOVES.SMASH_ANY_TIME = true`), within `prince.SMASH_REACH`
   (9 m) and only while the sword is planted (not mid-flight or returning); otherwise H is breath.
3. **Royal Draw not built**; the re-form is automatic at `SUNBRAND.REFORM_TIME` (0.7 s). `PRINCE_MOVES.ROYAL_DRAW`
   is the flag for the timed press when it lands.
4. Decree input: not reached (no Majesty).
5. Awakened colour: not touched; he uses the shared Awakening (gold rim, the heretic's numbers). His dash ghosts
   and hit tint are sapphire (`prince._fx_color()`).
6. The crown: a fixed mesh on the head bone; it doesn't tilt or fall (no Majesty).
7. **A pick by flag** in the training room (`--hero=prince`), no menu, no in-run swap.
8. **Names kept:** Prince Aurex, Sunbrand (`PRINCE_MOVES.HERO_NAME` / `SWORD_NAME`, unused in text so far).

Also assumed: the smash is called **Skyfall** whatever the sword is in (floor or foe; the doc names the floor one
Kingsfall only after Sword in the Stone); its blast is flat 34 (no "more from higher", no wall x1.5); the Javelin
doesn't pierce, pin to walls or carry the foe a set 4 m (the bite's knockback carries it); the smash has no timed
window yet (no PERFECT, no lock-out).

### Stubbed or missing (the next slices)

1. **The smash's window and Royal Draw:** a `hero_leap`-style window in the hang (PERFECT, early lock-out, float down
   with the sword still out) and the timed L at the gleam (450 ms, 120 ms window, x1.3 next sword move).
2. **Javelin's wall pin and carry** (thrown_foe), x1.5 at a wall; Royal Pin (Dash L H); Lunge Royale (Dash L).
3. **Sword in the Stone (L L L H) and Kingsfall, Pull from the Stone**, Heaven Toss and the air string (Wing Slash,
   Starfall), Tail Sweep (H H), Wingbeat (Dash H), hover on hold H.
4. **States:** kindled (breath), branded as a state other moves read, humbled; Heat the Blade, Searing Edge.
5. **Charged casts:** Empowered Breath / Dragonroar and Sovereign Light (hold H levels).
6. **Royal Flourish** parry (hold L in hand), Insolence, Kneel.
7. **Majesty, the crown that falls, the Decree**; his Awakened colour and Ascension.
8. **The sword icon by him** on the HUD (the beacon is the only "where is my sword" cue now); the pause panel's
   "n / m combos landed" line still counts the heretic's COMBOS.
9. Breakers: Judgement, Coronation, Sundering, Meteor Crown.
10. Model, rig and the 45 clips (section 8); until then he plays the heretic's clips (Ab_L1, KayKit Dualwield slice,
    Ab_L3, Ab_L2 hurl, Ab_LH rake, Spellcast_Shoot / Raise, Jump_Start / Idle), so the poses are the heretic's.
11. His effect materials aren't in `warmup.gd`'s shader list yet (`--collect-shaders` with `--hero=prince`): the
    first breath / blast may hitch once.

### Refactor that would make a second hero cleaner

prince.gd extends player.gd and overrides `_physics_process`, so he inherits the heretic's `_ready` (tentacle, void
arm, rig, axe trails, spirit motes) and then hides or replaces them. The clean split: a `hero_base.gd` with the body
(collision, run / dash / hurt / death, Awakening, take_hit, the callout, `_play`), and the heretic and the prince each
adding their kit (void_grab / void_arm / heretic_rig vs sunbrand / prince_fx). The readers that assume the heretic
(`combo_guide` via `HERO_MOVES.combo_options`, `pause_menu` via `MOVE_LIST`, `HERO_FX.combo_callout` via its
COMBOS, `comic_fx` MOVE_WORDS / BREAKER_WORDS, `fx._blow_element`) would read the hero's own tables through a small
interface (`guide_rows()`, `move_sections()`, `combos()`, `words()`) instead of the duck-typed hooks used here.
Not done now: player.gd is hot and another lane is editing around it.
