# Roadmap

Autonomous enhancement backlog. Work top-down; one item per commit. Check items
off and add notes/new ideas as you go. Never start tower defense or licensed IP.

## Combat feel
- [x] Weapon slash trails: `weapon_trail.gd` ribbon on both axes; turns orange while Awakened
- [x] Hit sparks → particle bursts; dust puff on dash and landing: `Fx.burst/impact/dust` (CPUParticles3D; GPU version misplaced first burst + compile hitch)
- [x] Brief enemy freeze (per-enemy hitstop) + squash/stretch on hit: `hit_freeze`/`hit_freeze_big` exports; enemies shudder in place, then knockback; launched enemies stretch up
- [x] Dash afterimages: `Fx.afterimage` bakes the current skinned pose into fading ghosts (blue, orange when Awakened); skipped headless
- [x] Perfect-dodge: dash ≤0.15s before a hit lands → slow-mo, +20 Awakening, +style, attacker stunned 1.2s, free re-dash (`perfect_dodge_*` exports)
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
- [x] Fade pillars that block the camera's view of the hero: `main._fade_occluders`; check with `tests/occlusion_check.gd`
- [ ] Toon outline shader pass
- [ ] Juggle counter / air-combo bonus feedback in HUD
- [ ] Settings for screen shake intensity
