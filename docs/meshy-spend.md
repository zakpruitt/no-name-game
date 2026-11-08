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
