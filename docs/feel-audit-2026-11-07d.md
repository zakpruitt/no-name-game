# Feel audit 2026-11-07d: impact lane (feel audit 7 follow-up)

Lane `impact` (agent/impact). Fixes for the impact-frame, banner, word and leftover-debris items in
`docs/feel-audit-2026-11-07c.md` and `docs/spar-audit-2026-11-07.md`. The camera is untouched: the six wide endings
(Avalanche, Slapshot, Meteor Shower, Pinwheel, Short Circuit, Uproot) do not get the landing punch, as already decided.

Films (12 fps, `user://` copied out): before `imp_b1` / `imp_b2` / `imp_kill_b2`, after `imp_a1`..`imp_a3` / `imp_kill_a3`.
The kill case is filmed with `tests/impact_film.gd -- --spar=warrior --from=11 --to=11 --tail=1300 --kill-hp=0.6`.
Clips: `Desktop/awaken-combo-clips/48 Impact * (before, after, half speed).mp4` (five).

## Ranked list

| # | Item | Evidence (before) | Fix | Evidence (after) |
|---|------|-------------------|-----|------------------|
| 1 | Kill under the impact frame is hidden; a living foe's bar reads 0 under 1 hp | spar_w L_L_L_H_H 040-042; imp_kill_b2 026-030 (the warrior is at hp 0.6 with an empty bar; it dies in the hang and its own grey frame washes out the kill star) | `enemy_bars.fill_px()`: a living foe keeps a `SLIVER_PX` 4 px sliver, and only the dead read empty. `comic_fx._on_killed`: a kill while `Game.impact.current() > 0` says **K.O.!** on the frame (ComicFx draws above the frame) and re-pops a real-time kill star once the frame clears (at most 260 ms later). No word with reduce_flashing (no frame then) | imp_kill_a3 024-030: sliver at 024-025, K.O.! on the grey frame 026-028, star after |
| 2 | The banner is empty on the impact frame | imp_b1 Maw (H_L_H) 028, Cataclysm 034 | `designed_breaker.Screen._callout_tick` holds the banner back while the frame shows (at most `CALL_WAIT_MAX_S` 0.3 s), then slashes it in from t 0; `_draw_text` draws name + total from the first visible frame | imp_a3 H_L_H 029 (MAW 358), L_H_L_L_H 035 |
| 3 | Name callouts stack on beat words (FAULT LINE + KRUNCH!, BLACK TIDE + SPLOOSH!, words over PERFECT!) | imp_b1 H_L_H 018-023, L_H_L_L_H 021-028, H_H 021-022 | `comic_fx._relay()` each frame and on each new word moves live words off the name callout's rect and the open banner (`comic_number.banner_rect`, which now includes the PERFECT tag): below the block in the top half, above it in the bottom half | imp_a3 H_L_H 018-023, imp_a1 L_H_L_L_H 021-028, H_H 021-022 |
| 4 | Cataclysm's banner over the pile 034-040, dropping only at 042 | imp_b1 L_H_L_L_H 034-042 | Cause confirmed by probe: the dodge (`_foe_under`) sampled scene foes at a fixed `ACTOR_HEAD` 1.8 m, but tumbling foes' models are drawn up to 3.7 m (dummy 2.1 m standing). It now samples `drawn_top(foe)`, the highest visible mesh AABB above the feet (capped 4 m) | probe: drop at +151 ms. Film a3 still dropped at 043 (see Not verified) |
| 5 | Structure bracket at the top-left screen edge | imp_b1 H_L_H 018-025 | `env_target.keep_on_screen()`: the bracket's middle is clamped into `SAFE` (8-92 % x, 16-88 % y) less its half size at the same depth, and an inked wedge `Pointer` on its edge points at the structure | imp_a3 H_L_H 018-025 |
| 6 | Parried cleaver lies about 2 s | imp_b2 counter_D 12-33 | The cleaver itself lay about 0.25 s; the 2 s object was the previous string's Frost Spear (not this lane). The cleaver now skids `BLADE_SKID` 0.7 m along the throw and erodes within `BLADE_SKID_S` 0.3 s of touchdown | imp_a2 counter_D 12-33 |
| 7 | Collapse's stray pebbles | imp_b1 H_L_H 000-017 | Source: env_target's pillar chunks (probe: 12 `env_chunk` meshes alive 1.7 s into the next string, held by its hitstops), not collapse_spit. Chunks fly in real time (`set_ignore_time_scale`), at most `CHUNK_FLY_MAX` 0.7 s, eroding over `CHUNK_FADE` 0.25 s as they come down | imp_a3 H_L_H 000 on: none |

## Checks

- `tests/breaker_spectacle_check.gd` `_impact_lane`: the bar sliver; a kill under `impact.slam` says the kill word and its star waits then pops; a reduce-flashing kill says nothing; the banner is not drawn under the frame, then slashes in with its name (CATACLYSM); a word on the banner and a word on a FAULT LINE callout are relaid off them. PASS.
- Also PASS: `env_target_check`, `counter_check`, `fx_sleek_check`, `cool_pass_check`, `impact_frame_check`.
- The occasional "2 resources still in use at exit" also shows on the baseline (an existing flake).

## Not verified

- Item 4 in film: run a3's pile never rose under the banner band until 043, so the film shows no early drop. The probe run dropped it at +151 ms. Lightning and other effects over the band are not foes and are not counted.
- On HIT frames where the callout and a word appear in the same physics frame (H_L_H 017), they overlap for one frame before `_relay` moves the word on the next.
- The banner now arrives about 0.17 s after the landing (it waits out the frame). It reads well in the films but has not been felt at full speed in hand.
- The kill case is set up by `impact_film.gd` (hp forced to 0.6 in the leap). A natural spar kill under the frame was seen in the audit but not refilmed.

## Decisions for Zak

- The chunk fix (item 7) is in `env_target._chunk`, outside this lane's "bracket placement only": collapse_spit has no pebbles.
- The kill word is "K.O.!" (`comic_fx.KILL_WORD`, 0.7 scale).
- The banner waiting out the frame (item 2) instead of being drawn over it: about 0.17 s later than before.
