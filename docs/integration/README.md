# Spring Vault production integration: joint review packet

> **Latest (10 October 2026):** `claude/adventure-player-flow` is merged into default on owner
> instruction. It connects the player journey end to end. Read `player-flow.md` first: Studio
> evidence, fixes, the merge record, and the current blockers. Codex should look first at the
> fallback prompts that require line of sight, the buttons that reflow under the cursor, and the
> last line of B1.

> **Pip license (claude/svc-pipquest):** completing Pip's trial now grants the permanent
> Broadwave license under `BroadwaveOrdinary`, and rides can no longer be called from the pocket.
> See `pip-quest-license.md`.

Branch `claude/spring-vault-production-integration`, 9 October 2026. It starts from default
`520575d` and is now merged with default `7df3a73`, which contains Codex's PR #33 and PR #34.
**Every `AdventureFlags` flag is still `false`.** Nothing was uploaded or published, no flag was
enabled, and no live save test was run. On owner instruction the branch was merged into default as `1c0bd10` without a PR. The open
gates below still apply before any flag is turned on.

## What changed since the last packet

1. **The shared wiring is applied in the tree** (commit `3e216f5`). This is
   `adventure-integration.patch`, which used to be held back. Main now boots `TrophyService`,
   `AdventureSettlement` and `AdventureBoot`. `Remotes.luau` gains `PlaceCampItem`,
   `RemoveCampItem` and `AdventureOutcome`. The client starts the outcome card, the camp display
   and `AdventureController`, and Q goes through `InputArbiter`. With the flags off,
   `AdventureBoot.Start` returns immediately and no adventure module is required. The `.patch`
   files in this folder are kept as history only. Do not apply them again.
2. **Surface entry, safe return, pocket lighting, and no review spawn** (`claude/svi-entry`; see
   `adventure-entry.md`):
   - a hatch on the surface at (-124, 1024, 76) with a "Go down" prompt, checked against
     `CanEnter` on the server;
   - a return pad inside the pocket;
   - lifts back to the surface after Leave, a fall, or the kill switch;
   - a dark backdrop box and 6 shadowless PointLights;
   - every SpawnLocation under the scene is destroyed, including after a rebuild.
3. **Licensed Broadwave and an equip control that works with the hidden Backpack**
   (`claude/svi-equip`; see `licensed-broadwave.md`):
   - `AdventureBoot.Options` supplies `ResolveTool = BroadwaveLicense.ResolveTool`. It returns
     only the equipped tool that this server issued, and only after `CanUseBroadwave` passes.
   - The loan still never reaches ordinary digging.
   - New `UI/BroadwaveEquip` control: an on-screen button, Z, or gamepad R1. It is labelled
     "Broadwave (loan)" for the loan and "Broadwave" for the licensed tool.
   - Ordinary digging pauses while a Broadwave is in hand.
4. **`ReturnFrame` is wired** (`651d1c9`). The runtime now returns players to
   `AdventureEntry.SURFACE_RETURN`, not to the frame where they joined inside the arena.
5. **Settlement durability audit, 9 fixes** (`claude/svi-settle`; see
   `settlement-durability.md`):
   - The most serious fix: `DataService` no longer overwrites a newer save when its own session
     lock is missing or stale.
   - The outbox `Ack` no longer deletes intents that a newer server version wrote.
   - The broadcast completion text is neutral.
   - Watchers get their real refusal reason.
   - The display or drain no longer wedges a grant.
   - Retries happen within the session.
   - A final outbox write is attempted after a failed leave save.
6. **Camp display lifecycle and ownership, 8 fixes** (`claude/svi-camp`; see
   `camp-lifecycle.md`):
   - The camp follows the real deck part when the deck is rebuilt or retagged.
   - `SetEnabled(false)` clears the pad and the queue.
   - Placements that can't be built never hold the pad.
   - Prompts are rate-limited.
   - A player who has left is never reassigned the pad.
   - The client re-renders when a prompt's `Enabled` changes.
7. `TrophyService` had two strict `pcall` type errors where the camp and settlement work met.
   Both are fixed (`dc9f6b5`).

## Branches and commits (all pushed to origin)

| Branch | Commit | Merged into this branch by |
|---|---|---|
| `claude/svi-entry` | `b724c05` | `a9fb29b` |
| `claude/svi-camp` | `4df61df` | merge after `a9fb29b` |
| `claude/svi-equip` | `d0777d7` | `b98a1b4` |
| `claude/svi-settle` | `1dfeadf` | `a56a905` |
| default (Codex PRs #33 and #34) | `7df3a73` | merge before `651d1c9` |
| ReturnFrame wiring, obsolete patch removed | `651d1c9` | direct |
| Strict `pcall` typing fix, Codex audit log | `dc9f6b5` | direct |

The pull request is not open yet, because `gh` was logged out. Open it from
`https://github.com/hownoms/roblox-dev/compare/claude/pensive-meitner-6jx4u4...claude/spring-vault-production-integration?expand=1`
and keep it unmerged until the joint review.

## Handoffs

| Area | Doc |
|---|---|
| Settlement, trophy reuse, per-player outcomes (design) | `settlement-outcomes.md` |
| Settlement durability audit, truth table, **live test plan** | `settlement-durability.md` |
| Camp pad display action and preview | `camp-display-action.md` |
| Camp lifecycle and ownership audit | `camp-lifecycle.md` |
| Flags, eligibility, input arbitration, boot | `production-wiring.md` |
| Licensed Broadwave contract, equip control, input audit | `licensed-broadwave.md` |
| Surface entrance, returns, pocket lighting, spawn removal | `adventure-entry.md` |
| Studio review of the real production boot (review flags, in-memory saves, seeded prerequisites) | `production-review.md` |
| Earlier review of Codex's polish branch | `codex-polish-review.md` |
| Raw logs | `evidence/combined-candidate.log`, `evidence/codex-audit-651d1c9.log` |

## Combined candidate evidence (headless mock with in-memory DataStores)

The tree is this branch at `dc9f6b5`, which already contains PR #33 and PR #34. Every spec
passes.

| Spec | Checks |
|---|---|
| util | 8 |
| smoke live / Studio | 2212 / 2179 |
| trophy | 476 |
| adventure-settlement | 275 |
| settlement-durability on / off | 105 / 53 |
| adventure-outcome | 23 |
| trophy-wired (real Main) | 60 |
| production-wiring off / on / rejoin / client | 37 / 42 / 13 / 59 |
| adventure-entry off / on | 16 / 69 |
| broadwave-license (end to end through the real runtime, no SKIP) | 61 |
| persistence-boot live / Studio | pass / pass |
| client | 1679, plus 7 tutorial scenarios (14, 13, 12, 10, 10, 14, 16) |
| Codex: spring-vault / runtime / input / return / broadwave-dig | 22 / 38 / 278 / 73 / 24 |
| adventure-trophy-contract | 24 |

Other checks:

- **Codex's audit:** `tools/adventure/audit-claude-candidate.py 651d1c9` exits 0, with
  `authoritative_boot_resolver: passed` and `licensed_runtime_ordinary_sand: passed`. Both gates
  were blocked on `a9fb29b`.
- **Build:** `rojo build default.project.json` succeeds.
- **Strict analysis:** `luau-lsp analyze` with a sourcemap is clean on every changed service,
  Main and client UI file.
- **StyLua:** clean on the changed files. `tests/client.spec.luau` already had a formatting
  diff before this branch.
- **Mutation runs by the agents:** entry 9 of 9, settlement 10 of 10, camp 17, and licensed
  Broadwave 2 groups. Every one was caught.

## Mocked durability compared with live evidence

Everything above runs on the mock store. A fresh mock "second server" that shares the mock
DataStore shows that intents survive and are applied exactly once. That shows the logic is
correct. It does not prove the following, which all need a private test place with API access,
following the steps in `settlement-durability.md`:

- a real `BindToClose` shutdown during settlement. The mock worst case is 10.4 s for 5 players
  against a 20 s wait.
- a real rejoin on another server, followed by a drain;
- a real session-lock takeover;
- live `UpdateAsync` throttling;
- servers running different versions at the same time.

## Open gates before any flag is turned on

**Runtime (Codex):**

1. **Review copy in production (B1).** After a wired completion the runtime still tells
   contributors "Adventure complete. Review only; no permanent rewards." (text changed by PR #35;
   Mara's line no longer mentions review). The `objectives` entry "REVIEW ONLY - no coins, ..." and
   the client header "SPRING VAULT · Review" say the same. This contradicts the reward card.
   Before `AdventureRewards` is enabled this copy must be production-safe. Exact strings and the
   suggested `OutcomeOwner = "External"` start option (already passed by `AdventureBoot`) are in
   `settlement-outcomes.md`, "Blockers for Codex".
2. **Duplicate equip button. Resolved** (10 October 2026). Codex's PR #37 hides the runtime's
   fallback whenever the production `Dig_Broadwave` GUI exists, and the player-flow merge made
   ours the only control (`production-wiring.md` 4.4). Still open from 4.7: reduced-motion and
   particle preferences, an arena-only panel, a named panel.
3. **Completion message to everyone.** It is broadcast to every player. Request: send it to
   participants only, or per recipient (R2). Our text is neutral for now.
4. **Kill switch and failure cleanup.** Participants are told nothing (R3).
5. **Old findings L1 and M2.** The ordinary refusal still replaces the event hint inside the
   arena. A licensed tool can start and cancel charges anywhere, and each is broadcast to all
   clients.
6. **Scene rebuild.** Confirm the client picks up the rebuilt scene after each run. The mock
   covers this, including the client-side dig pauses: hauling is never carried across a rebuild,
   a respawn, a Leave or a kill switch (`production-wiring.md` 4.3). Streaming eviction is not
   covered.

**Studio and devices (joint):**

7. **Pocket lighting and hatch.** A Studio look at the pocket lighting, the hatch, the return pad
   and the ceiling from player camera angles. Codex's probe in the review place was not a
   production check. This session's probe did not run: the Expansion1Review Studio instance
   closed before it started, and no other place was operated.
8. **Hardware input.** Physical phone, controller and keyboard use of `BroadwaveEquip` (Z and R1)
   and of the charge.
9. **Avatars and network.** Moving R6 and custom avatars, same-account network rejoin, real
   streaming in and out, and populated device performance.
10. **Camp display in Studio.** The card, the ghost preview, a live deck rebuild, and two clients
    holding the prompt at once.

**Live persistence (owner, private test place only):**

11. Every item under "Mocked durability compared with live evidence" above.

**Owner decisions** (unchanged unless noted):

12. Permanent first-sale and deposit evidence. Today the save can produce false negatives for
    veterans.
13. ~~Who grants `ToolLicenses.tool_broadwave`.~~ **Decided (owner):** completing Pip's trial
    (q_pip) grants it once, under `BroadwaveOrdinary` (`pip-quest-license.md`, branch
    `claude/svc-pipquest`). The bible's 150-coin first-clear reward is not implemented.
14. The kill-switch trigger: an admin command or a cross-server message.
15. How far the rewards flag reaches.
16. **New:** should the hatch also admit players who are eligible for Pip's trial but not yet for
    entry?
17. **New:** at the end of a run, should crews be lifted to the beach or stay in the pocket?
18. **New:** should stage pay require being present in the arena (R4 / L5)?
