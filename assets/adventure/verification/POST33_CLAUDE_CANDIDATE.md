# Actual Claude candidate audit — 9 October 2026

`tools/adventure/audit-claude-candidate.py` creates an ignored git archive of Claude's
`a9fb29b26aec75f8483528157ae3e14c23b6d4e9` production integration candidate and overlays the
current server/client/shared Adventure folders. It never injects a temporary ResolveTool
callback or alters tracked shared boot/remotes/catalogs. Only the fixture assertions are
instrumented. Run with Python; optional first argument selects another reviewed Claude ref.

The actual AdventureBoot.Options has no ResolveTool. With flags enabled and a registered,
equipped, loaded licensed tool, CanUseBroadwave passes, but actual runtime ChargeBegin is
refused and ChargeRelease grants no sand. All three required resolver/charging/runtime-sand
gates are explicitly **blocked**. Direct adapter digging still passes; this is not evidence
that actual licensed gameplay charging works. Claude must wire the authoritative callback.
The script returns a nonzero status for blocked gates even when ordinary specs pass.

Mock results: production wiring off37/on42/client20/rejoin13; entry off16/on69; runtime38;
input278; return73; Broadwave24. Zero failed checks. Additional actual runtime assertions verify a
review loan refuses ordinary charging and never grants ordinary sand.

Evidence: `POST33_CLAUDE_CANDIDATE_RESULTS.json` and `POST33_CLAUDE_CANDIDATE.log`.
This is automated headless mock evidence with in-memory stores, not networked Studio,
genuine streaming eviction, live persistence, same-account rejoin or physical-device QA.

Claude owns AdventureEntry and AdventureBoot. His entry packet requests Codex-owned scene
and runtime follow-up: safe production return frame, near boundary and production admission
copy. ReviewSpawn defaults false already landed in PR33. His entrance/return/lighting mocks
pass, while actual lighting, hatch prompts and ceiling/camera views remain Studio gates.
