# Playable journey — 9 October 2026

Fetched default `5897990`, separate `codex/spring-vault-journey` worktree. Agents handled trial runtime, scene presentation and independent input diagnosis/review. Claude-owned production boot, arbitration, AdventureEntry, rewards, saves, trophies, camp and catalogs are unchanged.

## Changes

- Join accepts Mara's invitation; the host presses **Begin** once. Its Activated callback sends Start, waits for the server preparation snapshot and the real scene, then confirms Ready for that same attempt. Server admission/readiness rules remain unchanged. Helpers see **Begin helping**, and nonhosts never see an unusable countdown.
- Pip has **End trial**. Standalone exit restores equipment/entry; successful Join cancels trial and held charge. Leave/scene cleanup prevent heartbeat recreating removed loans. Concurrent practice ends safely if another crew resets the shared scene; uninterrupted independent trials are not guaranteed.
- Ground-facing triangle/square/circle markers identify anchors. The ending remains visible after automatic safe return. Completion never implies accepted rewards; the adapter supplies that message.

## Actual input evidence

Only confirmed `Expansion1Review.rbxlx`, PlaceId0, Studio `5c9a8359-4e4a-40d9-8e99-216f19d6fa27` and its child Play DataModels were used. Old loaded sources were synchronized to the merged baseline first, then final review sources. Studio ends in Edit. No production Studio, publication, upload or live save test.

The previous empty mouse trace does not demonstrate broken Activated handlers. GUI AbsolutePosition omitted the screenshot's 58px inset; controls repacked after snapshots, and immediate/stale-target batches also missed. Fresh single instance-targeted MCP clicks delivered baseline Join/Start. Final mouse Join→Begin delivered Join/Start/Ready and entered Active with Ready=true. Ready is the shipped callback, not a test remote substitution.

Final complete run: mouse Join/Begin; 18 paced E holds cleared anchors and another opened the latch; mouse selected Right and attached; assisted character_navigation at0.5 speed guided through three gates. GateIndex3, 65 points and all stages/objectives were captured. Real mouse Leave during Resolving restored entry/speed16, removed the loan and preserved R15. Trial E Talk→mouse End trial also delivered Leave with Trial absent, Loan=false and Charging=false. No direct Intent remote or probe Intent request was used by the tester. This is injected ordinary input with assisted movement, not uncoached/physical-device acceptance.

An exploratory default-speed navigation pass outran the ball and correctly detached; slower navigation completed. Stale clicks during timeout/repacking missed, including one old Leave probe that hit a new Join. Those are labeled in `JOURNEY_STUDIO_TRACE.json`; `JOURNEY_FINAL_TRACE.json` contains the successful final journey/exit. The final same-attempt guard was mock-tested and synced in Edit afterward.

Saved captures: `journey-before-arrival.jpg`, `journey-after-shapes.jpg`, `journey-after-gate.jpg`, `journey-after-trial.jpg`, `journey-after-ending.jpg`. Shape/gate captures precede final ending-copy refinement. Existing accepted trial aiming/two-client recovery evidence is reused: aim, movement authority and fixed contact geometry were not changed.

## Checks and integration limits

Mocks pass: state22, runtime47, return81, input278, scene81, presentation53, Broadwave24, trophy contract24. Actual merged Claude modules, without fixture patch/resolver: wiring off37/on42/rejoin13/client59; license61; entry off16/on69; settlement275; outcome23. These include in-memory persistence and are not production Play acceptance. Changed-file formatting, strict mapped adventure analysis, whitespace and review/actual production builds pass. Broad repository formatting finds existing CRLF differences; no unrelated churn applied.

Claude's actual AdventureBoot supplies BroadwaveLicense.ResolveTool and AdventureEntry.SURFACE_RETURN; earlier missing-wiring reports are obsolete. Review Play deliberately loads no production eligibility/DataServices/rewards. Production entrance/return, shared HUD and per-player reward UI still need integrated Studio acceptance; live durability/device/populated performance remain release gates. No wiring was injected. Loans cannot authorize ordinary digging; equip/stow, cancellation, reduced motion, client-local smooth geometry and primitive fallback remain intact. Keep PR draft and unmerged.
