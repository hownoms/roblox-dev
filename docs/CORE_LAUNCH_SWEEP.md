# Core launch sweep — 11 October 2026

Base: `claude/pensive-meitner-6jx4u4` at `f10c832`. Classification follows
`GO_LIVE_PLAN.md`. Order: 1.5 first, then 1.6. No publishing performed.

## Launch blockers

**1.6: paid developer-product grants could be acknowledged without being saved.**
The receipt processor ignored `DataService.SaveAsync`'s false result, recorded
delivery, and returned `PurchaseGranted`. If the server died before a later save,
Roblox would no longer retry the missing paid reward. A second crash window between
saving the reward and recording separate purchase history could grant twice on replay.

A focused regression reproduced the failed-save acknowledgment before the fix.
The fix saves `PurchaseReceipts` alongside rewards, requires a successful save,
and retries applied grants without applying them again. Legacy history remains
supported. The marker survives rejoin and rebirth. No other blocker was confirmed.

## Evidence and limits

1.5: default-project candidate built; client suite passed 1,679 checks. All seven
tutorial scenarios passed (89 checks). These cover chat docking, reveal/toast
suppression, edge-arrow placement/hiding, Reduced Motion, full-bag guidance,
unaffordable-upgrade recovery and tutorial resume.

In a fresh local Studio session, ordinary clicks/Click to Move and the visible Auto
Dig control progressed through digging, discoveries sufficient to unlock Index,
40/40 bag, sell, first upgrade and equip. First sale yielded 48 coins; Garden Trowel
cost 30 and equipped at 18 coins. Reduced Motion switched on through Settings;
scan guidance and later digging/full-bag/selling remained usable. No scripted grant,
dig, teleport or save reset was used to claim the playthrough. The session exposed
paid controls, so it is not a free-account or phone hardware sign-off. The exact
card/sale overlap and facing-away edge-arrow cases have automated coverage but
were not fully reproduced through ordinary input.

The isolated file has PlaceId 0 and in-memory saves: it cannot prove real DataStore
persistence. Expected placeholder warnings belong to separate Phase 1 owner/Claude
work. Tool errors from attempted module inspection are not game-script failures.

1.6: isolated tests exercise all eight passes, all six products through the real
RewardsService, duplicate replay, save/rejoin, rebirth marker preservation and
shutdown saving coins, sand, finds and receipts. Failure tests cover failed player
save, failed history write, fresh processor after rejoin and legacy history.
Server smoke passed 2,212 checks; Studio fallback smoke passed 2,179 checks.
Strict typecheck has no errors (two existing deprecation warnings); Rojo build passes.
Live API-enabled Studio persistence is pending an existing test place. Mock results
do not claim real purchases, real cross-server rejoin or live shutdown.

## Post-launch — no fixes

- Chat overlaps Shop in the local candidate. Closing chat restores access and the
  upgrade works; it does not meet the plan's blocker rule.
- Two existing deprecated-API warnings (`IsInGroup`, `IsFriendsWith`), with no
  reproduced script error or normal-play failure.
- All existing post-launch items remain deferred. Frozen expansion, Broadwave,
  trophies and camp source was not changed.
