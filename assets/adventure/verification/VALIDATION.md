# Adventure validation — 9 October 2026

Dedicated Studio: Expansion1Review.rbxlx, id82642668-be2c-4e4a-b778-96542ee53b84.
DigTheBeach.rbxlx was not modified. Final review returned to Edit. No upload/publication.

## Automated checks

- 16 strict pure progression tests, including100 complete lifecycles, pass.
- Solo and crew work6/8;0.5-second per-user cooldown; repeated/unknown targets; NaN/inf work;
  sequential gates; penultimate/final60 admission lock; readiness timeout; disconnect90 hold;
  absence30 abandonment; meaningful late helper vs spectator; active presence accounting;
  moving-hauler shares vs idle attachment; immutable snapshot separation; non-awarding cleanup.
- Mapped strict analysis of all new adventure/review files: zero errors/warnings.
- New-file StyLua checks and dedicated review/production Rojo builds pass (final build recorded
  during delivery). Existing global formatting has pre-existing Windows differences, so this is
  not a blanket `ALL CHECKS PASSED` claim for tools/check.sh.
- Baseline headless server2199, Studio-mode2166, client1464 and utility8 checks pass;
  persistence boot live/Studio and all seven tutorial scenarios pass.
- Trophy boundary integration checks are recorded below once combined with latest default.

## Assisted Studio checks and observations

The saved STUDIO_TRACE.json contains raw MCP outputs. This used teleports to approach targets,
server review probes for intents and actual Humanoid movement for controlled cargo. It is not
uncoached human play or measured player pacing.

- Adventure constructs and the client UI starts with no script errors.
- Mara opt-in, five-second start, readiness, three anchors, latch, route selection and all three
  ball gates complete. Snapshot phases progress Inviting -> Preparing -> Active -> Resolving.
- Solo final context:65 contribution points,7 validated objectives,3 major stages, Eligible=true.
  Temporary adapter captures the context, logs NO rewards granted, and returns false.
- Wrong-event, unknown/protected target, too-far excavation and repeated instant hits do not
  increase work. Completed targets cannot pay/progress twice.
- Broadwave: early release refused;0.85-second release accepted; three practice targets complete.
  Cancellation removes charge with no release. Equipped loan required. No sand/reward mutation.
- Controlled movement initially outran slow walkers; fixed by temporary10/12 hauling speed with
  restored original speed. Solo route then completes using actual character walking.
- At gate1, reset from validated reset pad returns ball to checkpoint(692,20,-36 bottom pivot),
  retaining gate1 and45 points, never skipping or granting a gate. Three-second delay observed.
- Completion cleanup destroys ball/transient effects, returns participant and restores WalkSpeed16.
  Review arena rebuild retains SpawnLocation and reconnects client prompts.
- Injected three wave/three bounce notifications leave zero transient effect groups after0.5s.
  Effect caps/reduced-motion branches are implemented; crowded visual comfort remains a gate.
- R15 player's own avatar retained; Broadwave equips with RightGrip. Temporary R6 dummy also equips
  with RightGrip and walks; dummy removed. This is basic rig use, not all custom-avatar contact.
- Primitive color cap seams visibly improve over the severe original checkerboard z-fighting.
  Saved closeup shows residual faceting at curved panel edges; exact smooth spherical sectors
  need an owned mesh/art follow-up. No mesh or raster asset was uploaded.

Late-helper fairness has pure/engine state coverage; no second real networked player participated
in this session. Do not interpret synthetic identities as real multiplayer replication evidence.

## Remaining release gates

- Two real Studio clients and real accounts: late helper, observer, leaving/disconnecting,
  repeated attempts and UI isolation. Review intent probes bypass network delivery.
- Production admission/prerequisite and q_mara/q_pip persistence, normalized input arbitration,
  protected region integration, ordinary ability Terrain carving, durable coin/cert settlement.
- Trophy live DataStore save/leave/different-server rejoin and shutdown recovery; headless outbox
  checks are not live-service evidence. Apply/review trophy boot patch separately.
- One protected camp pad/display integration and truthful individual settlement results.
- Actual phone/controller, reduced motion interaction comfort, low-end performance, streaming,
  crowded readability, moving/custom-avatar contact and full100 runtime activity cleanup cycles.
- Independent newcomer observation and actual4-minute pacing; scripted test duration is irrelevant.
- No assets uploaded and no game published; all expansion enablement remains explicit review work.
