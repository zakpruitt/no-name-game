# Roadmap

Autonomous enhancement backlog. Work top-down; one item per commit. Check items
off and add notes/new ideas as you go. Never start tower defense or licensed IP.

## Combat feel
- [x] Weapon slash trails � `weapon_trail.gd` ribbon on both axes; turns orange while Awakened
- [ ] Hit sparks → proper GPUParticles3D bursts; dust puff on dash and landing
- [ ] Brief enemy freeze (per-enemy hitstop) + squash/stretch on hit
- [ ] Dash afterimages
- [ ] Perfect-dodge: dashing through an attack in its last 0.15s slows time + refunds Awakening
- [ ] Sound: procedural/CC0 SFX for swings, hits, dash, death (check Kenney audio packs on GitHub)

## Enemies
- [ ] Skeleton mage: ranged, telegraphed projectiles, keeps distance
- [ ] Skeleton rogue: fast flanker that dodges
- [ ] Enemy separation/steering so groups surround instead of stacking
- [ ] Elite modifier (bigger, tinted, more poise)
- [ ] First boss

## Roguelike
- [ ] Combo-slot upgrade system: data-driven upgrades attached to move IDs (L1/L2/L3/H/LH/DL)
- [ ] Reward choice screen after each wave (pick 1 of 3)
- [ ] 6–8 starter upgrades (fire wave on L3, lightning trap on dash-cancel, chain on air hits, ...)
- [ ] Run structure: rooms → elite → boss, run summary screen
- [ ] Simple title screen + pause menu

## Polish / tech
- [ ] Toon outline shader pass
- [ ] Juggle counter / air-combo bonus feedback in HUD
- [ ] Settings for screen shake intensity
