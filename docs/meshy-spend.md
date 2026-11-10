# Meshy spend log

Every Meshy task that costs credits, with its id and cost, so lanes share one budget. Check `meshy_check_balance`
before and after a batch and write both here; count the drop, since a top-up can change the total.

## Round of 2026-11-07 (cap 200 across all lanes)

Balance at the start of the heretic-design lane: 1037 (917 monthly + 120 permanent).

| Lane | Stage | Task id | Kind | Model | Credits | Output |
|---|---|---|---|---|---|---|
| heretic-design | 1 | `01a1b996-4d58-76cc-b155-12e0c248ae10` | text-to-image | nano-banana-2 | 6 | direction A, horned hood (chosen) |
| heretic-design | 1 | `01a1b996-4dd2-77df-a8cb-6938871f4f74` | text-to-image | nano-banana-2 | 6 | direction B, crooked monk |
| heretic-design | 1 | `01a1b996-4e31-7136-932c-4a3e149059a7` | text-to-image | nano-banana-2 | 6 | direction C, escaped prisoner |
| heretic-design | 1 | `01a1b996-4e8c-7120-b02b-bc49af0d9295` | text-to-image | nano-banana-2 | 6 | direction D, porcelain mask |
| heretic-design | 1 | `01a1b997-6d12-753a-a848-5bc1b6edb663` | image-to-image, multi-view | nano-banana-2 | 6 | A refined: front / side / back |
| heretic-design | 2 | `01a1ba0d-c56b-7116-a878-241a595054cf` | image-to-3d, smart topology 12k | meshy-t2.5 + meshy-n1 | 15 | heretic v3 mesh, used |

Stage 1: 30 credits (cap 40), balance after 1007. Stage 2: 15 credits (cap 60), balance before 1007, after 992; no
second generation needed. Running total this round (this lane): **45**.

Files: `vendor_src/meshy/heretic_concepts/` and `vendor_src/meshy/heretic_v3/` in the heretic-design worktree (gitignored).

## Meshy foe pipeline, 2026-11-10 (cap 300, Zak)

Balance before: 992. Spent **94**: the clip library once (42) and two foes (26 each).

| Stage | Task id | Kind | Model | Credits | Output |
|---|---|---|---|---|---|
| concept | `01a1c5f0-15a2-77b2-b086-29cb575d2744` | text-to-image, t-pose | nano-banana-2 | 6 | brute concept |
| concept | `01a1c5f0-186c-7530-985c-619940c945ab` | text-to-image, t-pose | nano-banana-2 | 6 | cultist concept |
| model | `01a1c5f0-ebcf-77ac-bab5-8589fe1d7fe1` | image-to-3d, smart topology 12k | meshy-t2.5 + meshy-n1 | 15 | brute mesh |
| model | `01a1c5f0-eecf-7072-aad4-f734730a126a` | image-to-3d, smart topology 12k | meshy-t2.5 + meshy-n1 | 15 | cultist mesh |
| rig | `01a1c5f3-0811-7632-932e-d10258039861` | rigging, 2.2 m | | 5 | brute rig + walk, run |
| rig | `01a1c5f4-0899-70c3-a533-9baf54c7dd58` | rigging, 2.0 m | | 5 | cultist rig |
| clips | `01a1c5f3-c415-7113-b890-66b9ade0e4be` | animation x10 (89, 4, 128, 125, 129, 178, 179, 189, 344, 3) | | 30 | library |
| clips | `01a1c5f3-c56a-727c-8bd0-a39c44f8c372` | animation x4 (156, 138, 224, 231) | | 12 | library |

Files: `tools/meshy/foes/`, `tools/meshy/library/` (committed).
