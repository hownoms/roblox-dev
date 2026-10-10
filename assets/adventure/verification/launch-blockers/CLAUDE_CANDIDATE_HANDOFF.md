# Claude handoff: safely provision actual Spring Vault production acceptance

9 October 2026. Baseline merged PR #37 (`c7c660e`). This is an actionable provisioning request, not evidence that production acceptance passed. No other chat has been messaged.

## Blocking state

The inspected, authorized `Expansion1Review.rbxlx` is PlaceId 0 and contains dedicated `AdventureReview` boot with ReviewSpawn and unconditional CanEnter/CanTrial. It lacks production Main, AdventureBoot/Entry, shared HUD and rewards. Its child Play DataModels therefore cannot establish production acceptance. Do not replace prerequisites, inject temporary remotes, fabricate save evidence, or install a resolver into this scene.

Actual merged integration already exists: `default.project.json` maps complete production server/client/shared trees; server Main orders DataService before TrophyService, AdventureSettlement and AdventureBoot, creates production remotes, connects outcome delivery and owns lifecycle; client Main starts AdventureOutcome and AdventureController. AdventureBoot supplies `ReturnFrame = AdventureEntry.SURFACE_RETURN` and, when BroadwaveOrdinary is enabled and bridge exists, `ResolveTool = BroadwaveLicense.ResolveTool`. Neither callback is missing. Old integration fixture patches are unnecessary.

## Deliverable required from Claude

Prepare a reproducible local production-source candidate, named and opened only as the confirmed Expansion1Review, with its approved child test DataModels. Retain the production Main lifecycle, World, full client Main, InputArbiter, BroadwaveEquip, AdventureOutcome, AdventureEntry, actual eligibility callbacks and actual settlement/trophy services. Exclude dedicated AdventureReview/ExpansionReview boot to prevent duplicate worlds/admission. Record exact source commit, build manifest, server/client trees, candidate flags and storage profile before Play. Do not operate production DigTheBeach, publish/upload, or perform live save tests.

The candidate must opt into SpringVault and AdventureRewards through an owner-reviewed server-only candidate configuration before Main starts. Both currently ship false in AdventureFlags; BroadwaveOrdinary also ships false. Keep normal shipped defaults false. Do not mutate cached flag tables during Play as acceptance setup. Enable BroadwaveOrdinary only if testing a legitimately granted permanent license path; it is unnecessary for event/trial loan controls and cannot confer a license.

### Storage isolation is a prerequisite, not a warning after Play

DataService.detectStore currently calls GetDataStore(`PlayerData_v1`) and then Studio GetAsync(`__probe`) before falling back to memory. Studio alone and a changed player-save store name do not prove zero live-save access. DataService performs session UpdateAsync loads/saves when the probe succeeds. Trophy/settlement outboxes use `TrophyPendingGrants_v1` and `AdventureRewardIntents_v1`; they select memory when DataService.IsMock. LeaderboardService respects that marker before acquiring ordered stores. MonetizationService.Init still attempts GetDataStore(`PurchaseHistory_v1`) before it discards the result when DataService.IsMock.

Provide an explicit fail-closed local-only storage mode selected before any service initializes, restricted to Studio plus the authorized unpublished PlaceId-0 candidate. It must prevent real DataStore/OrderedDataStore acquisition and requests across DataService, both outboxes, purchase history and leaderboards, including autosave/removal/shutdown. Production mode must retain normal durability and refuse unsafe candidate mode outside the authorized local scope. This is Claude-owned boot/storage work and has not been implemented by Codex. A store-name prefix alone is insufficient because live writes remain prohibited. If relying instead on platform API rejection, prove the candidate is unassociated and API access denied before Play, account for every store consumer, and label attempted rejected probe calls accurately; do not claim an explicit zero-request profile.

Use real service gameplay mutations into isolated memory and report rewards as local simulation. Memory settlement can verify per-player UI and reconciliation behavior, but cannot close live or cross-server durability gates. It must not imply durable production persistence in evidence.

### Legitimate eligibility through ordinary play

Start with unmodified normal new-player data. CanEnter requires loaded data and either Certifications.cert_rookie or both server-recorded sale evidence and an excavated deposit variant. No merged server grant path currently writes cert_rookie; do not seed it. The available honest path is dig normally, sell sand through the production sell UI/interaction, scan with T / L2 / production scan button and uncover a deposit normally. Confirm the actual server-produced SellTimes quest Progress >= 1 (or Claimed) and a FindVariants key ending in a variant other than Normal/None. Scanner use itself is not the eligibility record. Current catch-up rules do not distinguish scanner-located from accidentally uncovered deposits and sale quest evidence can later reset; record those limits.

Earn coins and purchase a priced shovel through production Shop UI; CanTrial accepts a known owned shovel with Price > 0 and rejects the free starter. Do not write OwnedShovels, Quests, FindVariants, ToolLicenses or Certifications from a test script. ToolLicenses.tool_broadwave has no merged grant path; permanent ordinary Broadwave acceptance remains blocked until the owner implements its legitimate quest/certification grant. Event/trial loans must remain incapable of ordinary sand yield.

## Ordinary input acceptance sequence once safely provisioned

1. At the surface hatch `AdventureEntry.ENTRANCE = (-124, SURFACE_Y, 76)`, use its E prompt (0.5-second hold, 10-stud UI range; server checks 16 studs). New ineligible players should receive truthful refusal and stay on the surface. After real eligibility, enter normally; server arrival is pocket origin + (-10, 3.5, 24), near Mara.
2. Walk to Mara and use Talk, then mouse/touch/controller Join and Begin. The normal Begin callback must emit its own Start/Ready; do not call remotes directly. Talk to Pip after genuine shovel purchase; shared `Dig_Broadwave` button or Z/R1 equips/stows the loan. End trial, return to main adventure through Mara. Capture the original shovel and exact restored tool identity.
3. Through ordinary movement and prompt/control input, clear triangle/square/circle anchors, open latch, select route, attach ball, move through all gates and reach ending. Any injected input, automated navigation or emulation must be labeled; assisted movement does not establish uncoached acceptance.
4. Verify shared production HUD is the equip authority and review fallback is absent. Equip/stow via actual button and Z/R1; retain Q/L1 cancellation and digging arbitration. Check Leave during trial/active hauling and automatic completion return at `SURFACE_RETURN` beside the hatch, restoring speed and the original shovel when still owned/current. Preserve R15, fixed 7.6-stud ball contact sphere and client-local visuals/fallback.
5. Capture actual AdventureOutcome per player: accepted/refused/pending/duplicate as provided by real settlement, distinguishing local memory from durability. Compare earned contributions and final reconciliation; never infer everyone was rewarded from global completion copy.

Acceptance evidence must include loaded candidate identity, source/config/storage manifest, before/after screenshots, ordinary input sequence and authoritative snapshots without test Intent requests. Existing accepted trial aiming and two-client recovery are reusable unless implementation changes risk regression. PR #36 mouse/E plus assisted navigation remains dedicated review evidence only. PR #37 production shared equip/restoration remain unverified through actual production controls.

## Additional actual integration blocker: initial streaming startup

`src/client/Controllers/AdventureController.luau` lines 47-100 starts SpringVaultClient and BroadwaveEquip only inside begin(remotes, scene); withScene waits for the first Workspace.SpringVaultAdventure scene. A legitimate licensed player outside streaming distance who has never visited the arena may therefore have no production Broadwave equip/control adapter despite receiving the remotes and issued tool. Runtime handling of later stream-out does not repair this initial startup dependency. Claude owns this adapter: decouple production licensed tool equip/input startup from arena availability while retaining real scene-dependent adventure presentation, arbitration and cleanup. Do not inject a fake scene or resolver. Verify ordinary controls before the first arena visit and again after returning/stream-out once a legitimate license grant path exists.

## Remaining gates

Safe actual-production-source candidate provisioning is the first blocker. Production entrance/shared HUD/per-player outcomes and PR #37 restoration need actual input verification after that. Real uncoached/hardware flow, populated performance/streaming and live cross-server durability remain separate open gates. This handoff neither grants publication/live-save authorization nor requests changes to Codex-owned runtime.

