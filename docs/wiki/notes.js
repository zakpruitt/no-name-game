// Hand-written wiki text, keyed by the game's ids. Numbers come from data.js
// (generated); this file only says what things *do*. Keep it strict JSON
// after the "window.NOTES =" line: tools/wiki.py parses it to flag ids that
// have no note yet.
window.NOTES =
{
  "moves": {
    "L1": {"input": "L", "name": "Slice", "note": "Opener of the light chain."},
    "L2": {"input": "L L", "name": "Slice", "note": "Second light."},
    "L3": {"note": "Big knockback finisher of the light chain."},
    "H": {"input": "H", "name": "Spin", "note": "Multi-hit spin from neutral; crowd control."},
    "LH": {"note": "Pops enemies up for a juggle. Hits on juggled enemies give bonus style."},
    "LLH": {"note": "Lunging thrust that knocks down everything in a strip ahead and breaks guards."},
    "CH": {"note": "Hold heavy from neutral, creep while charging, release to slam and launch. Breaks shield guards."},
    "DL": {"note": "Long lunging stab out of a dash; flows into L2."},
    "AF": {"note": "Awakened only. Erupts all around and throws six fire waves."}
  },
  "enemies": {
    "minion": {"name": "Minion", "note": "Basic melee. Necromancers can raise its grave."},
    "warrior": {"name": "Warrior", "note": "Big and slow. Poise means light hits don't always flinch it."},
    "mage": {"name": "Mage", "note": "Keeps its distance and casts slow bolts. Dash through them."},
    "rogue": {"name": "Rogue", "note": "Fast flanker that dodges your attacks."},
    "archer": {"name": "Archer", "note": "Aims a long line that narrows and turns red when it locks, then a fast arrow flies."},
    "shield": {"name": "Shield skeleton", "note": "Blocks hits from the front. Hit it from behind, or break the guard with a launch, Ground Breaker or charged slam."},
    "necromancer": {"name": "Necromancer", "note": "Hangs back and raises fallen minions. Kill it and its risen crumble."},
    "bomber": {"name": "Bomber", "note": "Runs in and lights a fuse; the blast also wrecks skeletons. Knock it into a crowd."}
  },
  "boss_attacks": {
    "cleave": {"name": "Cleave", "note": "Red ring around the Warden, then a spin."},
    "slam": {"name": "Slam", "note": "Red landing ring tracks you, then locks; it leaps."},
    "nova": {"name": "Nova", "note": "Purple ring, then a ring of slow bolts. Slip between them."},
    "spikes": {"name": "Spike line", "enraged": true, "note": "Bone spikes run at you, steering; each flags red just before it stabs. Sidestep."},
    "cage": {"name": "Bone cage", "enraged": true, "note": "A ring of bone walls closes in, turning, with one gap. Leave through the gap or dash through a wall."}
  },
  "twists": {
    "hasted": {"note": "Enemies move faster with shorter windups and recovery."},
    "armored": {"note": "Enemies have more HP."},
    "volatile": {"note": "Slain enemies burst after a moment. The burst hurts you; other skeletons are only staggered."},
    "splitting": {"note": "Slain enemies split into small pale-glowing minions (no bones, no further splits)."}
  },
  "screens": [
    {"img": "menu_title", "title": "Title screen", "caption": "Start, Daily run, Bone altar, Settings. Recent runs show on the right once you have some.", "review": "Is the title strong enough, or does it want art behind it?"},
    {"img": "autotest_callout", "title": "Combo callout", "caption": "Landing a named combo shows its name above the hero with a tier sound.", "review": "Is the size right? Are the three sounds distinct but quiet?"},
    {"img": "autotest_finisher", "title": "Cataclysm", "caption": "The Awakened L L L H finisher.", "review": "Does the payoff feel big enough for a full meter?"},
    {"img": "autotest_spikes", "title": "Spike line", "caption": "Enraged Warden attack.", "review": "Fair to sidestep, or too fast?"},
    {"img": "autotest_cage", "title": "Bone cage", "caption": "Enraged Warden attack, with its one-time hint.", "review": "Is the gap easy to find by hand?"},
    {"img": "autotest_shatter", "title": "Shatter", "caption": "Heavy-kill power.", "review": "Should the burst be louder visually?"},
    {"img": "autotest_split", "title": "Splitting twist", "caption": "Small pale-glowing minions.", "review": "Do they read as different from normal minions?"},
    {"img": "autotest_reward", "title": "Reward cards", "caption": "Pick 1 of 3, with reroll.", "review": "Cards are text-heavy; worth icons?"},
    {"img": "menu_path", "title": "Doors", "caption": "Choose your next room.", "review": "Does a two-twist door explain itself?"},
    {"img": "autotest_camp", "title": "Camp", "caption": "Spend bones.", "review": "Are the prices right?"},
    {"img": "autotest_shrine_room", "title": "Shrine", "caption": "The altar rises before the trade menu.", "review": "Enough atmosphere for a quiet room?"},
    {"img": "menu_pause", "title": "Pause", "caption": "Your build, synergies, the move list, room and seed.", "review": "Right amount of detail?"},
    {"img": "autotest_summary", "title": "Run summary", "caption": "Stats, new bests, powers.", "review": "Anything missing?"},
    {"img": "menu_altar", "title": "Bone altar", "caption": "Permanent boons.", "review": "Three boons enough?"},
    {"img": "autotest_slam", "title": "Charged slam", "caption": "Hold heavy, release.", "review": "Is the charge-ready cue clear?"}
  ]
}
