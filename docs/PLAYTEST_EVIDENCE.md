# Playtest evidence and issues — 7 October 2026

This log distinguishes observations from simulations. No public-launch gate is closed by packaging.

| Evidence | Result / limit |
|---|---|
| Repository | Clean start `2e58982`; network-enabled fetch succeeded; merged PRs #13–#15 preserved |
| Interrupted client validation | Rerun completed: 1,373 passed, zero failed; local log `build/client-preparation.log` |
| Fresh bundled server tests | 2,158 normal / 2,144 Studio-mode, zero failed; local logs `build/server-preparation.log`, `build/studio-preparation.log`; mocks, not real saves/multiplayer |
| Utility / preflight | 8 passed; zero blocking flags, five missing configuration groups |
| Source validation | Windows-line-ending StyLua check passed; full strict analysis passed with existing IsInGroup/IsFriendsWith deprecation warnings; Rojo source map and candidate build passed |
| Live setup | Existing DigTest, Rojo panel visibly connected localhost:34872, fresh ordinary Play; setup is separate from gameplay |
| Ordinary input | Starter autoequip, Click to Move off pad, mouse digs, natural excavation and readable Tiny Cool Sunglasses Rare/Tiny/Damaged/18-coin reveal; own nameplate hidden during card. No grants, teleports or command-bar code used |
| Unperformed | Audio listening, independent feedback, real persistence/locking/shutdown, physical devices, populated performance approval; do not infer these from passing mocks |

| Issue | Priority / next evidence |
|---|---|
| Quest/Index toasts crossed heading of a subsequent natural excavation | Follow-up presentation issue; reveal card itself was readable. Reproduce and scope a queue fix if it impairs timing instructions |
| Full ordinary sequence, scan HOT and Reduced Motion | Invitation readiness verification pending; prior and current partial runs are not a full sign-off |
| Four-client shared digging/tide/server goal | Invitation readiness verification pending; mock coverage cannot close it |
| No published test experience/account setup | Owner dependency; creation/publication and access need explicit authorization |
| Historical 16.8 ms average / 253.3 ms max heartbeat, 3,006 MB Studio stress | Public reliability gate remains open; no fresh measured spike attribution yet |

Screenshots were inspected inline. No saved screenshot or profiler capture is claimed unless explicitly added to this log. Local build/log files are ignored; the reproducible source and qualified notes are committed.
