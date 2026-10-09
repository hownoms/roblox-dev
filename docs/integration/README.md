# Adventure rewards + camp: joint review packet

Branch `claude/adventure-rewards-integration` (from default `a4167d9`). It merges three Claude
branches: `claude/settlement-outcomes` (fb3f235), `claude/camp-display-action` (8dfd2b1) and
`claude/production-wiring` (6ec6bdf). Nothing here is pushed, uploaded or published, and no
shared boot file is edited in the tree.

## Shared wiring: one patch

`adventure-integration.patch` holds the shared-file edits from all four earlier patches,
already conflict-resolved: `trophy-integration.patch`, `settlement-outcomes.patch`,
`camp-display-action.patch` and `production-wiring.patch`. Apply only this patch; the other
four stay as history. It touches `Main.server.luau`, `Main.client.luau`, `Remotes.luau`,
`DigController.luau`, `InputController.luau`, `tests/run.sh` and `tests/trophy-wired.spec.luau`.
Every adventure flag (`AdventureFlags`) defaults to off.

## Handoffs

| Area | Doc |
|---|---|
| Stage and final settlement, trophy reuse, per-player outcomes, durability | `settlement-outcomes.md` |
| Camp pad display action and preview | `camp-display-action.md` |
| Flags, eligibility, licensed Broadwave, input arbitration, boot | `production-wiring.md` |
| Review of Codex's `codex/spring-vault-gameplay-polish` | `codex-polish-review.md` |
| Adversarial settlement and durability audit, live test plan | `settlement-durability.md` |

## Joint evidence (9 Oct 2026, headless mock store)

Tree: this branch + Codex `d335eab` merged + `adventure-integration.patch`. Every spec passed.

| Spec | Checks |
|---|---|
| util | 8 |
| smoke (live) | 2212 |
| smoke (Studio) | 2179 |
| trophy | 400 |
| adventure-settlement | 275 |
| adventure-outcome | 23 |
| trophy-wired | 35 |
| production-wiring, flags off | 36 |
| production-wiring, flags on | 38 |
| production-wiring, rejoin | 13 |
| production-wiring, client | 20 |
| client | 1500, plus the 7 tutorial scenarios |
| persistence-boot (live and Studio) | pass |
| Codex spring-vault | 22 |
| Codex broadwave-dig | 23 |
| adventure-trophy-contract | 24 |

`rojo build default.project.json` succeeds. Without Codex's branch, the flags-on and rejoin
scenarios print SKIPPED and everything else passes.

## Not verified

- Live DataStores.
- Real cross-server rejoin.
- A real shutdown during settlement.
- Studio visuals of the camp card and ghost preview.
- Real multiplayer, phone and controller input.
- Populated performance.

## Blocking before any flag is turned on

These come from `codex-polish-review.md` and `production-wiring.md`.

1. The review arena's neutral `SpawnLocation` must not exist in production.
2. The runtime must accept the licensed Broadwave tool for a charge, or `BroadwaveOrdinary`
   stays off.
3. The production client hides the Backpack, so equipping the loan or licence needs a control.
4. Players need a surface entry or teleport into the under-slab arena, plus a lighting check
   there.
5. Owner decisions:
   - the permanent first-sale and deposit evidence;
   - who grants the Broadwave licence and under which key;
   - what triggers the kill switch;
   - how far the rewards flag reaches.
