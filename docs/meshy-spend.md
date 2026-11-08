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

Stage 1: 30 credits (cap 40). Balance after: 1007. Running total this round (this lane): **30**.

Files: `vendor_src/meshy/heretic_concepts/` in the heretic-design worktree (gitignored).
