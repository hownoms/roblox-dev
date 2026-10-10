# Runtime prompt, input and outcome continuation — 10 October 2026

Fetched actual default `d96ac7565ac8d723e80b7392df6046e710b5ad4c` before creating isolated
`codex/spring-vault-input-parity`. Independent agents implemented prompt and controls changes
and reviewed the outcome boundary. No other chat was messaged. Claude-owned source/tests are
unchanged; exact coordination requests are in `docs/integration/runtime-input-handoff.md`.

## Fixes and before/after evidence

- Local prompts now use `RequiresLineOfSight=false`, matching server prompts; Talk remains
  10 studs and other actions 12. `prompt-baseline.log` fails against the original client;
  `prompt-fixed.log` passes 29 checks. Delayed server replication, rebuilt second-attempt
  latch/route callbacks, duplicate suppression and old scene teardown are covered.
- Every contextual control has a stable semantic cell. Leave has its own top-right cell;
  the scroll canvas remains fixed, so scroll clamping cannot move controls under the cursor.
  The panel is taller (348 px, scrollable on short viewports). Cancellation has no debounce.
  `controls-before.log` restores only the old compacting layout and fails; after passes 62
  checks, including production/dedicated-review title labels.
- Runtime reads External outcome ownership (also inferred from a supplied production
  completion callback). It removes review-only reward claims and gives participant-only
  neutral completion feedback. Individual grant/save/refusal cards stay settlement-owned.
  Dedicated adapter wording and production-review isolated-memory labels remain truthful.
  Outcome baseline fails; final 85 checks cover successful/refused/error callbacks and
  noncontributor/bystander delivery. The old header claim was already fixed at default.
  Internal ScreenGui name remains a compatibility dependency, not visible player copy.

## Actual Studio input and limitations

Only confirmed Studio `52e353d8-247c-42e4-8c49-76cef91dc3da`, `Expansion1Review.rbxlx`,
PlaceId 0, and its child Client/Server were operated. Production `DigTheBeach` was untouched.
Read-only inspection found the dedicated review boot, with unconditional admission and
review loans; production Main/entry/shared HUD/settlement were absent. Before-source snapshot
is `studio-before.json`. Only the two changed runtime/client sources were synchronized in
Edit. HTTP was disabled, so sources were transferred directly through the Studio source API;
no HTTP setting was changed. Review ends in Edit. No disk place save, publication or upload.

Injected mouse Join, then two clicks at the same Begin location 100 ms apart delivered
Join/Start/Ready, reached Active, and delivered no Leave. A subsequent separate Leave click
was accepted and removed the loan. Assisted Humanoid navigation moved beside Pip; injected
E Talk followed by mouse End trial removed trial and loan. Trace evidence is
`studio-double-click.json` and `studio-exits.json`. These were ordinary UI callbacks, with
no direct remote/probe Intent request. Probe use was read-only inspection.

This is dedicated-review input evidence, not production acceptance. Two complete consecutive
adventures, exact original equipment restoration, shared production equip/stow, automatic
surface return and individual production reward UI were not verified with actual input.
Second adventure prompt coverage is headless. No screenshots are claimed; evidence consists
of source snapshots, network traces, state observations and regression logs.

## Merged source checks

All targeted adventure specs pass: state 22, runtime 47, input 293, return 111, scene 81,
presentation 62, initial-stream 29, outcome-owner 85, Broadwave digging 24, trophy contract 24.
Actual production wiring off/on/rejoin/client, eligibility entry/invitation, license,
outcome, settlement, production-review and persistence boot specs pass in API-aware mocks.
Client smoke and all seven tutorial modes pass. Logs: `merged-suite.log`, `merged-modes.log`.
The full production settlement-durability on spec has 198 passes and 11 obsolete completion
wording/recipient failures; it is **not** a full-suite pass. Exact owner test updates are
documented in the integration handoff. No production storage source was changed.

Changed-file formatting, whitespace, mapped strict adventure analysis (`analysis.log`, empty
on success) and both actual production/dedicated-review local Rojo builds pass. Bash was
unavailable in the sandbox; equivalent individual specs were run through the local Luau CLI.
Existing aiming/two-client recovery evidence is reused. No aiming, movement authority, avatar,
fixed ball contact geometry, server validation, equipment restoration logic, loan ordinary-dig
exclusion, reduced-motion controls or local geometry fallback changed.

## Remaining gates

The candidate branch still equals default and has no fail-closed local storage mode.
The storage-probing production-review boot was not run as safe acceptance. Claude must
provision isolation before *any* store acquisition/request and legitimate ordinary gameplay
eligibility. Then verify final merged production through the UI for two adventures, Pip exit,
shared equip/stow, exact tool restoration, Leave/automatic return and individual results.
The controller still explicitly requires a scene before starting the client; preference
integration and beach panel behavior remain dependencies. License grants, permanent entry
evidence, kill-switch trigger and reward/entry/return policy decisions remain open.
Physical devices, uncoached play, real streaming/populated performance, same-account rejoin
and live cross-server durability remain launch gates. No live save tests or merge occurred.
