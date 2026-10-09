# First-slice specification snapshot

This self-contained handoff extracts the relevant TARGET records from the local game bible
chapters 02–05, dated 8 October 2026. Numerical mechanics remain prototype tuning targets;
the visual kit does not implement event, progression or persistent reward services.

| Stable entity | Catalog appearance and role | Relevant mechanics |
|---|---|---|
| npc_mara | Coral jacket, whistle; calm lifeguard at Sunshine tutorial pad | q_mara, invitations and safe-return explanation; protected kinematic NPC; interaction 10 studs |
| npc_pip | Blue apron, huge pencil; excited Sunshine shovel salesperson | q_pip trial and upgrades; protected kinematic NPC; interaction 10 studs |
| tool_broadwave | Wide blue shovel, foam-like wave | q_pip demo loan; cert_explorer permanent license; proposed 1,500 coins; 0.8-second charge, 12×8×8 corridor within 12 studs, 8-second cooldown; lock direction at release |
| landmark_spring_vault | Half-buried lid, striped handles; 12×10×8 envelope | Clear three sand anchors, open latch, guide ball through three gates; event_vault |
| event_vault | Spring Surprise, curated first discovery then dig opportunity | 1–4 participants, four-minute maximum active period; solo path and optional helpers; intro-tier reward |
| camp_trophy_stand | Cream pedestal, 2×2 footprint | q_mara first-adventure camp reward; curated placement on 2-stud grid |
| landmark_spring_vault / trophy replica | Display miniature of the first shared discovery | First successful completion; non-sellable display copy; use original landmark ID as entitlement source |

Shared anchors: six ordinary-equivalent hits solo, eight with helpers, 12-stud range,
0.5-second per-player cooldown. Geometry communicates 0/25/50/75/100% progress, and protected
pieces cannot be removed by generic tools. Triangle/square/circle markers supplement color.

The vault ball is the introductory toy payload, not the Core finale's First Beach Ball.
The chosen 7.6-stud diameter and 0.18-scale replica are routine art choices. Ball movement
uses a controlled bounded route and three checkpoints; no unrestricted player knockback.

Digging remains the foundation. Players retain their own avatars, competition is optional,
and permanent possessions are protected. NPCs have blocky silhouettes, expressive simple
faces and restrained details. UI follows the existing chunky dark outlines and beach
palette. Approved player marketing retains the exact classic bacon-hair outfit and flatter
colorful thumbnail style; this kit adds NPC artwork rather than a new player mascot.

Server authority remains required for admission, protected bounds, objectives, helper credit
and idempotent reward receipts. Specialist sand yield is capped to matched ordinary digs
over the 0.8-second charge and actual filled voxels/bag capacity. In events, progress replaces
ordinary sand output. Trophies are permanent non-sellable replicas, not duplicate inventory.

First session: dig/find/scan/sell, Pip's tool trial, Mara's three-anchor mini-vault, ball
return and first camp trophy. Do not expand into all future regions or reset legacy saves.
See INTEGRATION.md for exact factory interfaces, effect design, local validation and pending
Studio/gameplay gates. Original working-copy sources: docs/game-bible/02-future-game.md,
03-future-content-catalog.md, 04-mechanics-economy-and-production.md and
05-roadmap-validation-and-handoff.md; those separate drafts are not part of this asset PR.
