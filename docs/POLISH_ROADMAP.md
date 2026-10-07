# Polish roadmap — 7 October 2026

This is the current priority order approved by Howard. It supersedes the older exhaustive fit/scenery-first order in historical reviews. Read POLISH_HANDOFF.md for saved evidence and repository state; POLISH_RELEASE_GATES.md remains the inventory of unresolved gates. Changing priorities does not close any gate or authorize publication.

## Delivery stages

Howard requested one issue per stage: observe/reproduce it, fix it, verify the focused result, save progress, push and merge its PR, then continue the next issue in a new chat. Do not batch unrelated polish into future stages. The existing first-player changes are the current checkpoint to finish integrating. The next stage is **excavation WAIT/TAP cue readability and timing**: retest the new cue in DigTest, correct any observed issue, and record what was actually verified. Keep other onboarding, contact and UI follow-ups queued separately. Publishing Roblox remains unauthorized.

## 1. First-player experience — next work

Use the existing build/DigTest.rbxl with default-project Rojo on port 34872. Recheck Studio/Rojo state and start fresh Play with current source. Run spawn → equip → dig → scan/excavate → readable discovery → full bag → sell → first upgrade/equip using ordinary input. Keep assisted setup separate from unassisted evidence; do not use /max, scripted digs or teleports to claim completion.

Record confusion, dead time, unclear controls/objectives, reward-name visibility, feedback timing and whether the first upgrade feels meaningful. Prioritize concrete friction found in this run. Check Reduced Motion and focus equipment contact/fit review on visible gameplay problems. Audio listening needs actual listening evidence; do not infer it from scripts or screenshots.

Fresh-player feedback is the next valuable evidence: observe someone unfamiliar with the game without coaching. Record where they get stuck and whether they want to continue after the first upgrade. This is a proposed user-assisted playtest, not permission to contact or recruit people.

## 2. Performance and reliable controls

Investigate existing Studio spikes/memory with pets, rides, discoveries and tide. Record measurements and limitations. Real populated/device profiling remains open. Phone/controller hardware is deferred without asking again until available; neither emulators nor bots close those gates.

## 3. Core digging feel and reward feedback

Refine strike/ground contact, discovery clarity, sell/upgrade timing and sound based on gameplay evidence. Test moving backpacks, pets on slopes and ride boarding/seat/ground contact where they affect this experience. Resolve obvious clipping, floating and obscuring glow before spending time on exhaustive asset angles.

## 4. Acquisition artwork

Prepare faithful icon/thumbnails and actual gameplay captures once the core experience is representative. Check small-size readability and title-safe crops. Do not upload or publish under this roadmap alone.

## 5. Targeted scenery and fit cleanup

Static collection is complete: 199 primary native views and 48/120/240 px; 27 tools/backpacks received R15 static worn/grip inspection. Central scenery families are reviewed at 15/15 depths. Shipwreck barrels and Ancient Ruins lintels passed native support retests. Do not restart these sweeps.

Other pockets/angles, avatar bodies, dynamic fit, normal carving/tide appearance and streaming remain open. Review them selectively around normal gameplay and fix noticeable defects; exhaustive cosmetic inspection has lower priority than onboarding and performance. Existing geometry protection regressions remain required when scenery changes.

## 6. Supporting release assets

Badges and additional ambience have lower priority than the core loop. Audio rights/permissions/loading/listening, actual badge configuration/awards and faithful final store media remain unresolved. Do not invent IDs or claim checks that were not performed.

## Continuation state

PR #9 is merged. Saved base: claude/pensive-meitner-6jx4u4 at f5fe836 before this roadmap documentation. Fetch/check local and remote changes and preserve intervening work. All release gates remain open; no Roblox publication is authorized. Next action is the complete unassisted first-player sequence, not another collection or scenery sweep.
