# Final merged production candidate acceptance — 10 October 2026

Fetched Claude's merged default `2d4f0cc` and integrated it into the isolated
`codex/spring-vault-input-parity` branch. Final gameplay source played: `ed5dba7`.
The source includes Claude's actual candidate storage, controller startup and q_pip grant,
plus Codex's prompt parity, stable controls, external outcomes, arena-only panel and truthful
trial copy. No Claude-owned source or tests were edited; no other chat was messaged.

## Scope and provisioning

Only confirmed `Expansion1Review.rbxlx`, Studio `52e353d8-247c-42e4-8c49-76cef91dc3da`,
PlaceId 0 and GameId 0, and its child Client/Server were operated. Actual production
`DigTheBeach.rbxlx` was untouched. Source was frozen during install/play. `manifest.json`
records every served source hash and candidate config; `install.json` records installed
commit `ed5dba73a33eaf9a9dc8ff7f8cf8a6104bcad3c1`, 223 instances and parked review roots.
Only Claude's candidate installer/config was used: actual Main, services, entry, eligibility,
ResolveTool, shared controls and settlement. No resolver, eligibility shim or review boot.

The installer could not apply streaming-radius/integrity/stream-out properties or Lighting
Technology through plugin permissions (`install.json`). StreamingEnabled was applied, but
this run does not establish production streaming settings or lighting fidelity. HttpEnabled
was temporarily set by the installer to fetch localhost sources and restored to false.

Every runtime-VM profile snapshot shows `StorageMode=LocalOnly`, `Profile.Mode=LocalOnly`,
`Storage.Acquired={}` and `Storage.Refused={}`. The storage-probing old review boot was parked
and never ran. Persistence and reward statuses are memory simulation, not durable live saves.

`plugin-context-diagnostic.json` is deliberately named: an early require from Studio plugin
context read a separate module cache and returned Unavailable. It is not server-state
acceptance. Subsequent observations ran in a temporary, read-only server Script using the
actual production runtime cache. It recorded source-produced data, inventory references,
event snapshots and incoming Intents; it never issued gameplay requests or wrote saves.

## Ordinary input verified

Inputs were Studio MCP keyboard/mouse injection, reaching normal production controls.
Walking used assisted Humanoid navigation; camera positioning was assisted for digging
and the trial. This is coached local single-client evidence, not physical or uncoached play.
The Studio account's existing game-pass entitlements applied, including 2.5x sand and
Sell Anywhere. No entitlement or save field was changed by the tester.

1. Fresh ordinary profile had no entry/trial eligibility. Mouse holds on the sand dug and
   uncovered finds; minigame timing expired naturally, producing damaged finds. T used the
   real scanner. Sell-button clicks earned coins and sale evidence; the excavated Tiny
   deposit variant earned catch-up entry. No cert/license/prerequisite was seeded.
2. G opened Shop; the normal 30-coin Garden Trowel buy button purchased/equipped the shovel.
   E held 0.7 seconds at the hatch entered the pocket. An earlier short 0.35-second attempt
   did not meet its 0.5-second hold requirement and is not a refusal check.
3. E at Pip, shared Z equip, Q held 1.3 seconds toward the marked patch, then three paced E
   interactions completed the trial. The actual q_pip handler issued the license and a
   licensed Broadwave. Trial copy made no false review/no-license claim.
4. Mouse End trial restored speed 16, removed the loan and re-equipped the **same** Garden
   Trowel instance. Shared Z equipped and stowed the licensed Broadwave on the beach;
   production's equip control was present, fallback hidden, and adventure panel hidden.
5. Mouse Join then Begin (including a second click 100 ms later at the same position) sent
   Start/Ready, entered Active and sent no accidental Leave. E cleared each of three anchors
   six times, opened the covered latch, selected Left and attached to the ball. Assisted
   navigation carried it through all three gates. The first run had two honest recovery
   detaches: an off-channel point and a premature lateral turn; E reattached normally.
6. First completion granted +6 excavation, +6 vault, +48 final coins and first-clear
   trophy/stand/cert_crew in memory. Automatic return restored the exact original shovel,
   speed 16 and removed the loan, leaving licensed Broadwave stowed.
7. Re-entered and completed the **second consecutive adventure in the same server**. Its
   rebuilt latch and route interacted normally. Three gates, 65 points, second clear and
   +60 coins were observed (71 -> 131). The second final card showed +48 without a duplicate
   trophy/stand/certification. Screenshot: `second-adventure-result.jpg`.
8. A third run checked active hauling cancellation: before Leave, Attached=true/speed10;
   clicking Leave produced surface return, speed16, Loan=false and the same original shovel
   equipped. It granted no third final clear. Ordinary digging afterward increased total
   sand 32.5 -> 55 and bag sand to 22.5 without auto-equipping Broadwave.

Evidence: `trial-complete.json`, `trial-exit-and-shared-stow.json`,
`run1-navigation-recovery.json`, `run1-completion-and-return.json`, `run2-completion.json`,
`run2-auto-return.json`, `hauling-before-leave.json`, `hauling-after-leave.json`,
`final-profile.json`, `intent-log.json`, `per-player-outcomes.json` and saved screenshots.
`OriginalGarden=true` compares object identity held by the read-only observer, not just name
or ToolId. Both completed runs have distinct event-instance IDs and final receipt IDs.

Outcome observation is the actual connected player's card/payload. The first final included
trophy/stand/certification; the repeat included none. Zero-coin ball_return payloads occurred,
but the production card did not show a misleading empty grant. Two-player refusal/bystander
delivery is covered by mocks and prior evidence, not a fresh multiplayer Studio run here.

## Cleanup and launch gates

Stopped Play, ran Claude's uninstaller and confirmed dedicated review restored, candidate
and backup absent, StreamingEnabled=false, HttpEnabled=false and Studio Edit. Temporary
observers vanished with Play. `uninstall.json` records restoration. No place file save,
publication, asset upload, live save test or default-branch merge was performed.

Previously blocked safe candidate provisioning, actual startup adoption and legitimate Pip
license acquisition are resolved. This single-client merged journey closes the two-adventure,
Pip exit, shared equip/stow, exact restoration, hauling Leave, automatic return and own-player
result checks. It does not close physical devices, a new two-client late-helper/refusal run,
real streaming radii/stream-out, same-account rejoin, uncoached discovery or populated
performance. Reuse accepted aiming and two-client recovery evidence; geometry/authority were
unchanged. Live/cross-server persistence remains a separate owner-approved launch gate.

Remaining coordination: 11 obsolete Claude settlement-test expectations; production settings
integration for reduced motion/particles; tutorial guide marker versus arena panel; local
outcome "Saved" wording (the candidate banner explicitly labels memory simulation). Owner
decisions include permanent sale evidence, trial-only entry, trial-exit destination,
kill-switch trigger, reward scope and remaining q_pip reward/certification policy.
No production flag should be enabled on the basis of this local run alone.
