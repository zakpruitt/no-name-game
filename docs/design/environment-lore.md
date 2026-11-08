# Environment lore: why the dungeon answers to the heretic

Zak, 2026-11-07, on environmental aspects only one character can use: "feel free to flesh out that idea / lore too,
potentially influencing the world more later with items". This page is the world behind
[environment-per-character.md](environment-per-character.md) and what shipped in
[env-pieces.md](../features/env-pieces.md). It is a direction, not a spec.

## The world, in one paragraph

The dungeon was built by the church that cast the heretic out, as a prison for what it could not burn. Every room was
made to hold one of the four powers he stole: grates of cold iron to bleed off the storm, barrels of lamp pitch kept
for the pyres, pillars sunk deep enough to pin anything to the floor, cisterns to drown the fire. A prison built to
hold a power still has to touch it, so every piece is half a conductor. When the heretic walks in with the stolen
power in his arm, the room remembers what it was built against: the grate takes his storm and carries it, the barrel
was always waiting for a spark, the pillar was never meant to come out of the floor, and the tentacle does it anyway.
Other prisoners answer to other pieces. The Dragon Prince was jailed for his crown, not for the four powers, so the
grates are floor to him and the braziers are his.

## What this means for the rules

- **A piece answers to an element because of what it was built to hold.** That is the "exclusive by element" rule
  (`env_piece.EXCLUSIVE`) in the world's terms: a storm-trap conducts storm, a pyre store burns.
- **Pieces are shared, verbs are not.** Anyone can break a crate. Only the one the room was built against gets its
  verb.
- **Used up is used up.** A toppled pillar is rubble because the prison is being taken apart, one piece at a time.
  The training room is the church's drill hall and rebuilds itself; real rooms will not.

## The rooms so far (round 57)

Each training room is one place in the prison, and its pieces say what it was built to hold
([rooms.md](../features/rooms.md) has the rules and numbers).

- **The drill hall** (plain, and "with pieces"): where the wardens drilled. Swept bare, or stocked with one of
  everything the prison is built from, each set by a dummy.
- **The flooded cistern** (ice and dark shine). Dug under the hall to drown the stolen fire. Its channel was never
  drained, cold iron still bars the sluice, and the drowned were hung on the chains above it. The water remembers
  being one body: ice on any pool runs the whole channel, and a cube struck down it does not stop until the far wall.
  The hooks over the water are the gallows' home; nothing in the cistern burns.
- **The forge hall** (magma and storm shine). Where the church cast its cold iron. The pitch for the pyres is still
  stacked between the fires, so one spark walks the whole line and knocks the braziers into the floor; the plates of
  its floor were bonded to carry the forge's current, so storm on one is storm on all of them.

The Dragon Prince would read both differently: the cistern is a room with nothing of his in it (pools are his
`mirror_pool` flourish at most), the forge is his (braziers to Kindle, kegs he can only break). That is the proposal's
"no dead room" rule seen from his side: a run's room list should weigh which character is playing.

## Items that change the world (later)

Kit-grammar section 7: upgrades target a slot or a window, passives an element or a state. Items add a third kind
of target: the room.

- **Room modifiers on doors.** The map shows each door's room with an icon per piece family: "Flooded" (+2 pools),
  "Powder store" (+3 barrels), "Lit" (every torch and brazier lit), "Collapsing" (pillars start cracked), "Cold iron"
  (+2 grates). An item can add a modifier to the next door ("Sapper's Map: the next room is a Powder store") or turn
  one ("Dowsing Rod: Flooded rooms are Frozen instead"). The player picks the door that suits the build.
- **Pieces that remember the run.** A piece the heretic used carries a mark into later rooms of the same floor:
  "Scorched Iron" (every grate you made live starts live in the next room), "Keg Ledger" (each keg you burst adds a
  barrel to the next room), "Fallen Column" (each Uproot leaves a fallen pillar, a wall in the open, in the boss room).
  The run's upgrades show up as the room, not only as numbers.
- **Relics that rewrite a rule.** "Warden's Key": chests open mid-fight and throw their gold as a splash. "Rusted
  Chain": hooks hang everyone, not only Ricochet's target (the gallows flourish for the whole room). "Cinder Saint":
  braziers re-light themselves for the prince, every 10 s.
- **Character-neutral world items.** "Pieces rebuild between waves", "Breakables drop Awakening", "Rubble gives the
  first breaker of a room +20%". These are the run's way to make any room better without picking a side.

### How items could alter rooms (the roguelike hook; design only)

Round 57 made a room data (`rooms.gd` `ROOM_DEFS`: layers of piece placements, `flourishes`, `links`, `rebuild`).
That is the surface an item writes to. Four kinds, each one key on the room:

- **Add a layer.** "Sapper's Map": the next room also places the forge's powder line. "Dowsing Rod": the next room
  gets an aqueduct along its back wall. An item is a small placement list, the same shape as a room's own.
- **Turn a rule on.** "Cold Iron Bond": every room `links` grates (the forge's plates everywhere). "Water Table": every
  room links pools. "Rusted Chain": every room has the `gallows` flourish. These are the room keys a run's item flips
  for the rest of the floor, rather than a `Kit.has()` upgrade on the hero: the hero did not change, the prison did.
- **Change a piece's state.** "Lit" (every brazier and torch starts lit), "Damp Powder" (barrels start out: a keg needs
  two magma hits), "Collapsing" (pillars start cracked). One `state` field per placement already exists (`place()`).
- **Keep what was used.** "Fallen Column": a room you toppled a pillar in keeps it down as a wall in the open for the
  boss room. This needs the rebuild rule to carry across rooms: a run writes the used-up pieces of one room into the
  next one's layers.

Item-made pieces follow the same "no dead room" rule: an item never takes the last definer piece of a character out
of a room.

## Open questions for Zak

1. Is the church-prison the world you want, or should the dungeon be older than the church (it built itself)?
2. Should items change rooms you have already seen (a floor map that updates), or only the next door?
3. Should the Dragon Prince's pieces (braziers, ledges) be in the heretic's rooms as floor and walls, or should each
   character's run draw rooms from its own list?
4. **Hazards and the hero.** For now kegs, live plates and spilled coals hurt foes only (round 57, the orchestrator's
   call, so the new rooms are about using the room, not dodging it). Should a run's harder rooms make them hurt him
   too (a keg at full damage, a live plate charging him), or should the hero always be the one the prison answers to?
5. Should a showcase room (the cistern, the forge) be a door a run offers by build ("this room suits your ice"), or
   random, with the room list weighted by character only?
