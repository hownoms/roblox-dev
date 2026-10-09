# Spring Vault discovery continuation — 9 October 2026

Separate `codex/spring-vault-discovery` worktree from fetched default `7df3a73`, merged PR34. Integration, POST33 and prior gameplay/runtime evidence were read before changes. Agents independently handled runtime feedback, scene presentation and targeted presentation regressions.

## What players get

The arrival panel shrinks from 330px (390px with equipment) to 192px and sits clear of chat. It offers the current action, a short next objective and optional controls. Desktop equip/stow remains accessible separately; touch retains scrollable 48px controls. Start has a server-derived countdown, Ready appears when useful, and route/hauling controls follow the actual step. Motion and particles remain available through Options. Returning to Mara can expose Join even after starting Pip's optional trial.

Mara and Pip face arrivals and have short purpose labels; the review spawn is within Mara's talking range. The vault's latch and shaped anchors face the approach in both covered/open states. Route pads and sparse noncolliding floor cues explain the channels; the selected route is stronger. Decorative geometry does not participate in queries, while solid boundaries and the fixed ball contact sphere retain authority.

The objective names the next unfinished shape and its scoop count, distinguishes Pip's wave from scoops, and distinguishes ball attachment from walking. Completed anchors and cleared practice targets stop offering work. Only the nearest currently relevant prompt is enabled. Late server prompts after scene rebuild cannot compete with the selected local prompt. Cleanup disables retained prompts.

Latch, route, attachment and recovery confirmations survive their action broadcast. Gate confirmation persists briefly, the next gate alone gets a label, and reached gates change marker color. These presentation cues cannot grant progress.

## Evidence and practical limits

Only confirmed `Expansion1Review_AutoRecovery_0.rbxl`, PlaceId0, and its child Play DataModels were operated. Existing R15 player avatar was preserved. Production DigTheBeach was untouched; review ends in Edit. No publication, uploads or live save tests.

Baseline observation found Mara obscured by the large card, the vault back facing arrivals and irrelevant actions offered before joining. Iterative captures are saved as `discovery-before-anchors.png`, `discovery-after-anchor.png`, `discovery-after-hauling.png`, `discovery-final-trial.png`, and `discovery-final-arrival.png`. The final arrival capture shows the centered panel; intermediate anchor/hauling/trial captures precede its final centering and equipment placement.

Assisted local single-client requests used actual Intent remotes, current attempt IDs, range checks and paced cooldowns. They cleared three anchors6/6, opened the latch, selected Right, attached with speed10 and validated gate1. Afterward only the ball's Release prompt and gate2 label were enabled. An omitted attempt ID was refused; several observations outlasted invitation readiness and are not counted as progress. This was a presentation regression run, not a repeat of two-client checkpoint recovery or accepted trial Q aiming.

An actual Studio mouse click equipped the existing loan and another stowed it. Final Options clicks set Motion:low/Puffs:off. The final centered Join/Start/Ready mouse probe delivered no requests beyond Sync and is **not** UI-flow acceptance; the accepted progression above used assisted requests. Raw observations and limitations are in `DISCOVERY_STUDIO_TRACE.json`. Uncoached discovery and reliable full mouse-flow acceptance remain open. No physical controller/touch was available; emulation, genuine streaming, populated-device performance and live persistence are not established here.

## Checks

API-aware mocks: state22, runtime47, return73, input278, scene66, presentation44, Broadwave24, trophy contract24 pass. Presentation tests include phase/nearest/cleared-target prompt filtering, late prompt replication, optional-trial/Mara Join, contextual controls, route/gate cues, persistent gate feedback and accessible reduced-motion/particle settings. Existing input checks cover equip/stow, cancellation, teardown and primitive mesh refusal fallback. Changed-file formatting, mapped strict adventure analysis, whitespace, review build and production build pass. Mocks are not hardware, populated timing or deployed integration acceptance.

## Dependencies

Claude still owns authoritative ResolveTool and ReturnFrame injection, shared boot/remotes/arbitration, AdventureEntry, rewards, persistence, trophy storage, camp UI and catalogs. None were edited or shimmed. Loans still cannot grant ordinary digging. Smooth geometry remains client-local with primitive refusal fallback; server-created EditableMesh Content and uploads remain absent. Keep this PR draft and unmerged pending review.
