// Hand-written wiki text, keyed by the game's ids (data.js has the names, inputs, words and numbers).
// "moves": what state a move leaves and its best situation. "endings": each breaker ending's best situation.
// Sources: docs/features/void-element.md, combo-breakers.md ("Breaker pairs"), counter.md, kit-grammar.md.
// Keep it strict JSON after the "window.NOTES =" line: tools/wiki.py parses it and names ids with no note.
window.NOTES =
{
  "moves": {
    "L1": {"state": "", "best": "The opener. Every string starts here, so the colours teach themselves: storm first."},
    "L2": {"state": "", "best": "The second beat: the spear hurls ice ahead."},
    "L3": {"state": "", "best": "Big knockback to close a plain string, or the hammer's lead-in to Molten Palm."},
    "EC": {"state": "airborne", "best": "A crowd in front of you. The kit's only knock-up, so it starts every air route."},
    "IP": {"state": "slowed (frost)", "best": "Foes coming at you: plant it and fight on the frost. Sets up the vault, Deep Freeze and Impale."},
    "EM": {"state": "shoved, wall-splat", "best": "A group with a wall within 10.5 m behind it: the wall hits x2.5 and piles them for Meteor Fall."},
    "EE": {"state": "charged", "best": "A crowd the tentacles can hold (up to 5 within 8 m). Lightning runs through the whole hang, press or not."},
    "IS": {"state": "frozen", "best": "A stand: everyone on the frost within 6.5 m of the spear freezes into a cube."},
    "EV": {"state": "bound", "best": "Straight after Molten Palm: the lava chases whoever the palm shoved (up to 18 m) and holds them for the meteor."},
    "EW": {"state": "charged", "best": "Foes already up after Updraft Lash and Air Slash: the air big move."},
    "VR": {"state": "marked", "best": "A crowd in front: the mark is what Black Tide drags and Galvanize reaches furthest for."},
    "VS": {"state": "pulled in, burning", "best": "Something in the tentacle's hand and foes nearby: the hole drags small ones in and slows big ones."},
    "VD": {"state": "pooled", "best": "Marked foes anywhere in the room: however far off, they are dragged into one pool."},
    "OW": {"state": "bound", "best": "One big foe. It pins what the rest can't hold (big ones are slowed)."},
    "DL": {"state": "", "best": "Closing distance: a lunge off a dash or off a swing."},
    "TW": {"state": "bunched", "best": "Foes along your dash's path: it yanks them into each other for Impale or Storm Pitch."},
    "EF": {"state": "frozen", "best": "A crowd all round you (up to 5 within 8 m): they are set down frozen in a row ahead. Aim the row at a wall for Slapshot."},
    "XK": {"state": "skewered (frozen)", "best": "After Frost Spear: Tow Line's bunch is thrown onto the spear and freezes round it. With no spear, it plants one."},
    "XF": {"state": "airborne, charged", "best": "Off Rockslide: the buried come up hardest. Then pick Tempest for a crowd, Cataclysm for a few."},
    "XS": {"state": "airborne", "best": "Frozen foes (Ice Cube just bowled): every cube goes off in steam and scalds the rest."},
    "XC": {"state": "charged", "best": "A spread-out crowd round you, Reap's marked from further (11 m) and harder. The more it links, the harder each zap."},
    "XG": {"state": "frozen, airborne", "best": "Frozen foes you want up in the air: the whirlwind carries the cubes and he climbs after them."},
    "XM": {"state": "molten", "best": "Hailstorm's cubes in the air: the hammer bursts the ice and brings them down burning, into Eruption."},
    "XW": {"state": "frozen kebab", "best": "Impale's kebab: hauled back up to him for Anvil (open floor) or Pinwheel (a wall or pillar near)."},
    "XL": {"state": "molten, bound", "best": "Molten Palm scattered them at mixed ranges, one splatted on a wall: paid by the metre dragged, torn off a wall hardest."},
    "XT": {"state": "charged", "best": "Upgrade. Tow Line's bunch hurled along your aim, lightning jumping off them at everyone they pass."},
    "GR": {"state": "", "best": "Route step. Yanks a foe to him; something too big drags him to it."},
    "AL1": {"state": "airborne", "best": "Route step. Up after the launched foes with the axe."},
    "IJ": {"state": "", "best": "Route step. Vaults over the planted spear, any time while it stands."},
    "XR": {"state": "buried", "best": "Route step. The hammer drives everyone into the floor together, double on those the gale had up."},
    "EA": {"state": "frozen", "best": "Route step. Freezes the nearest and bowls it; everyone it passes freezes too."}
  },
  "endings": {
    "Grounded": "The tentacles hold the crowd: everyone held is slammed down with lightning under each.",
    "Short Circuit": "The room is full past the tentacles' reach: the charge arcs out to up to 8 foes nobody held, within 12 m.",
    "Worldbreaker": "A launched group you want planted: slammed into the floor, magma erupting under each.",
    "Cold Front": "The same group, frozen solid and hurled at the others as cubes.",
    "Avalanche": "Every cube Deep Freeze made: the tentacles pick them up and slam them together in the middle.",
    "Meteor Fall": "The palm piled them on a wall: he dive-bombs the biggest group, the splatted ones take x1.3 (3 on a wall: 628 vs Meteor Shower's 336).",
    "Meteor Shower": "The palm scattered them: a fireball on every foe it hit, wherever it went (4 scattered: 310 vs Meteor Fall's 175).",
    "Collapse": "The hole is full: it falls in on itself and throws everyone clear, into walls.",
    "Maw": "Everyone dragged into the pool: jaws come up and shut on them.",
    "Black Ice": "The same pool, frozen over with them in it; his landing shatters it.",
    "Abyss": "One big foe pinned by Overwhelm, on open floor (197 vs Uproot's 71): it sinks through the floor and black spikes throw it back up.",
    "Uproot": "A pillar within 6 m of the pinned foe (244 vs Abyss's 170): the tentacle tears it out and clubs the foe with it; the pillar is rubble.",
    "Cataclysm": "A few foes (two: 209 vs Tempest's 144): lightning, then a strike and the earth under each.",
    "Tempest": "Four or more: the twister takes the crowd up and bolts blast each out, harder the more it holds (five: 666 vs 524).",
    "Flash Freeze": "The steam freezes on the held as he dives, and the landing shatters it again.",
    "Eruption": "Meltdown's burning, in the air: the floor goes up under each, the burning hardest.",
    "Anvil": "Open floor (406 vs Pinwheel's 152): the hammer drives the kebab into the floor, a crater each.",
    "Pinwheel": "A wall or pillar within 10 m (519 vs Anvil's 406): the kebab whirled in a twister and hurled into it.",
    "Shatterstorm": "Anywhere: thunder shatters every cube where it stands. The reliable one.",
    "Slapshot": "The row aimed at a wall: cubes slide and shatter on it for the most in the kit (wall 63 each vs thunder 30 vs no wall 14).",
    "Ricochet": "A wall or a crowd near the attacker: hurled into it, x2.5 on a wall, and held there. In the open it lands for its base.",
    "Hellseam": "The pile Lava Leash dragged in: it craters harder the further each was dragged, and the seams erupt back out along every drag."
  }
}
