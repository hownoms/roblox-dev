# Independent local two-client settlement dependency

Current source was inspected without changes. Studio local simulated players -1 and -2 cannot pass the positive production participant-ID contract.

- src/shared/Rewards/AdventureRewards.luau:262 requires integer UserId in [1, 2^53]; line267 returns BadParticipants. StageDecisions and FinalDecisions both validateContext before creating decisions.
- src/server/Services/AdventureSettlement.luau:448 returns the error report immediately when decisions are nil. No publish/outcome loop executes. OnStage:608 logs refusal; OnCompletion:624 returns false and truthful completion-rewards-unavailable callback text.
- src/shared/Trophies/Rules.luau:269 independently requires positive IDs; TrophyService:509 rejects invalid participants too. Changing only the adventure guard is insufficient.
- src/server/Adventure/SpringVaultService.luau:283 copies real event participant UserIds unchanged. Codex runtime authority/identity boundary should remain unchanged.

Owner dependency: Claude owns settlement/storage/rewards and candidate provisioning. An explicit coordinated policy is required before supporting negative simulated Studio IDs in the strict LocalOnly profile. Production validators must remain strict. No identity spoof, resolver shim, remote input, prerequisite bypass or validator edits were performed.

No in-scope positive-ID two-client alternative was established. Roblox official testing documentation distinguishes Server & Clients simulated local clients from Team Test collaborative sessions. Team Test requires collaborators and existing collaboration context; it is not established within the confirmed unpublished Expansion1Review candidate. Account-backed single-client Test cannot establish multiplayer settlement.

Reference checked 10 October 2026: https://create.roblox.com/docs/studio/testing-modes

This finding explains absent outcome payloads in the actual local two-client run. Runtime gameplay, participant-only neutral completion delivery, cancellation/restoration and consecutive adventures may still be independently verified, but per-player reward-card acceptance remains open.
