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

## Open questions for Zak

1. Is the church-prison the world you want, or should the dungeon be older than the church (it built itself)?
2. Should items change rooms you have already seen (a floor map that updates), or only the next door?
3. Should the Dragon Prince's pieces (braziers, ledges) be in the heretic's rooms as floor and walls, or should each
   character's run draw rooms from its own list?
