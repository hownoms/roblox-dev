# Store Page & Launch Kit: Dig to the Core! Beach Simulator

Everything here matches `docs/GDD.md` and `src/shared/Config/*` as of launch (15 layers, 43 pets,
51 treasures, 14 shovels, 13 backpacks, codes RELEASE / SANDY / DIGDEEP / 1KLIKES). If Config
changes, update the numbers here before you paste them. Roblox rejects or demotes descriptions with
false claims.

---

## 1. Experience title

**`Dig to the Core! Beach Simulator`** (32 / 50 chars)

- It keeps the three search words players type: **Dig**, **Beach**, **Simulator**.
- A/B alternates (Creator Hub allows one rename at a time, so test for about a week each):
  `Beach Dig Simulator: Dig to the Core` (36), `Dig to the Core! [Beach Simulator]` (34).
- Optional prefix during updates, which most simulators do: `[UPDATE 1] Dig to the Core! Beach Sim` (38).
  Only use it while the update is less than about a week old, and only if it really is an update.

## 2. Description (paste into Creator Hub → Configure → Description)

Roblox allows **1,000 characters** and only shows the first ~2 lines above the fold, so the hook and
the current code come first. The block below is about 900 characters.

```
🏖️ Dig a giant hole at the beach and reach THE CORE! 🌋
🎁 CODES: SANDY (15 min 2x Sand) • RELEASE (exclusive Launch Party Crab pet)

⛏️ Dig through 15 layers: Pirate Cove, Sunken Shipwreck, Fossil Bed, Crystal Caverns, Frozen Abyss, the lost city of Sandlantis, Magma Chamber, the Alien Hive... all the way to the Core, 1,000 m down!
💎 Discover 51 treasures, from bottle caps to the Mythic Beach Ball of Creation
🥚 Hatch 43 pets (Common to Mythic) that boost your digging
🛒 Upgrade through 14 shovels and 13 backpacks
🔁 Rebirth for a permanent sand multiplier
🌊 High Tide (2x Luck) and Golden Hour (2x Coins) events all day
👫 Dig with friends for bonus sand!

👍 Like & ⭐ Favorite! New codes unlock at like milestones.
👥 Join our group for +10% Sand forever and the DIGDEEP code!

📜 UPDATE LOG
🆕 v1.0 (Release): 15 layers, 43 pets, 51 treasures, daily rewards, quests and leaderboards!
```

Rules followed: no "free Robux", no "OP"/"admin" bait, no promises of rewards we don't give, no
off-platform links in the text (Discord and YouTube go in **Social Links**), and the codes and
numbers match Config. When `1KLIKES` is enabled, add `• 1KLIKES` to line 2 and push the update-log
entry down.

**Update log template.** Newest entry goes at the top. Trim old entries to stay under 1,000 characters.
```
🆕 v1.1 "Tide Pool Pets": pet fusing (5 = Golden!), index rewards, 2 new codes!
v1.0 Release!
```

## 3. Keywords / tag ideas (20)

Roblox has no free-form tags, but these words should appear naturally in the title, description,
group name, Discord, video titles and ad copy, because Roblox search matches all of them.

1. dig  2. digging simulator  3. beach simulator  4. dig to the core  5. treasure hunting
6. shovel simulator  7. mining simulator  8. pet simulator  9. hatch eggs  10. rebirth
11. incremental  12. clicker  13. fossils / dinosaur  14. pirate treasure  15. crystals
16. lava  17. aliens  18. deepest hole  19. sand  20. idle tycoon

## 4. Genre

- **Genre:** Simulation
- **Subgenre:** Incremental Simulator. This is where Pet Sim, Mining Sim and Dig It sit, which helps
  the "similar experiences" recommendations.
- Devices: Phone, Tablet, Computer, Console. VR off. Server size 12 (= plots).

## 5. Maturity & Compliance Questionnaire (expected label: **Minimal**)

Answer honestly. These are the expected answers for the game *as built*. Re-check them if the game changes.

| Question area | Answer | Note |
|---|---|---|
| Violence (any, incl. fantasy/cartoon) | **No** | Digging only. No combat, weapons or damage. |
| Blood / gore | **No** | (The "Cursed Skull" and "Dino Skull" are cartoon treasure items, not gore.) |
| Crude humor | **No** | |
| Fear / horror | **No** | |
| Romance | **No** | |
| Strong language | **No** | Chat uses Roblox filtering. |
| Alcohol / drugs / tobacco | **No** | |
| Gambling (real-money) | **No** | |
| **Paid random items** | **Yes** | The *Golden Egg* is a random pet bought with Robux. Odds are shown in the egg UI for every egg (required). |
| Social hangout / free-form user creation | **No** | |
| Free-form voice/text beyond Roblox chat | **No** | |

Result should be **Minimal** (all ages), with the paid-random-items disclosure shown on the page.

## 6. Badges (10) — art in `marketing/badges/`

Award them with `BadgeService:AwardBadge` from the server-side code that already tracks depth, hatches and rebirths.
Paste the badge ids into config once created. **This is a code task for the gameplay team; badges
are not wired yet.**

| # | File | Badge name | Description (shown on page) | How to earn (trigger) |
|---|---|---|---|---|
| 1 | `01_welcome.png` | **Welcome to the Beach!** | Grab a shovel and start digging! | First join (after the first successful dig) |
| 2 | `02_first_pet.png` | **New Best Friend** | Hatch your very first pet. | First egg hatch |
| 3 | `03_pirate_cove.png` | **Arrr, Pirate Cove!** | Dig down to Captain Sandbeard's loot at 110 m. | `MaxDepth >= 110` (Pirate Cove) |
| 4 | `04_fossil_bed.png` | **Dino Digger** | Uncover the Fossil Bed at 200 m. | `MaxDepth >= 200` |
| 5 | `05_crystal_caverns.png` | **Crystal Clear** | Reach the glowing Crystal Caverns at 330 m. | `MaxDepth >= 330` |
| 6 | `06_frozen_abyss.png` | **Underground Ice Age** | Brr! Reach the Frozen Abyss at 410 m. | `MaxDepth >= 410` |
| 7 | `07_magma_chamber.png` | **Too Hot to Handle** | Survive the Magma Chamber at 585 m. | `MaxDepth >= 585` |
| 8 | `08_alien_hive.png` | **Close Encounter** | Discover the Alien Hive at 780 m. | `MaxDepth >= 780` |
| 9 | `09_the_core.png` | **I Reached the Core!** | You dug 885 m to the golden heart of the planet! | `MaxDepth >= 885` (The Core) |
| 10 | `10_first_rebirth.png` | **Born Again** | Rebirth for the first time. | `Rebirths >= 1` |

More badge ideas for later updates: *Mythic Luck* (find a Mythic treasure), *Collector* (complete any
layer's Index), *Rebirth x10* (Core Breaker unlocked), *7-Day Streak*, *Sandlantis Explorer* (495 m).
Badge creation costs 100 Robux each after the free daily quota (check Creator Hub's current rule).
Upload all 10 before launch.

## 7. Launch marketing plan

### 7.1 Short-form video (YouTube Shorts / TikTok / Reels)

Format: vertical 1080x1920, 15–30 s, captions burned in, hook in the first 1.5 s. Record in-game
(Studio with the UI on, or a live server). **Show only real gameplay.** Thumbnails and videos with
fake UI or features that aren't in the game break Roblox ad rules and lose player trust.

| # | Hook (first 1.5 s, on screen) | Script |
|---|---|---|
| 1 | "I dug 1,000 m to the CENTER of the Earth 😱" | Speed-ramped dig from beach → each layer banner pops (Pirate Cove, Fossils, Crystals, Ice, Lava, Aliens) → golden Core reveal. End card: game name + "code SANDY". |
| 2 | "What's at the bottom of the beach? 🤔" | POV first dig at the surface → a bottle cap → "keep going…" → pirate chest → dinosaur skull → camera tilts down the hole at the Core glow. Ask "how deep can YOU go?" |
| 3 | "Rating every layer until I hit the Core" | Tier-list style. Stop at each layer for 2 s with a 1-line rating ("Shipwreck: 7/10, spooky"). Comment bait: "which layer is best?" |
| 4 | "I hatched a MYTHIC pet on my first try?!" (only if true, otherwise "How long to hatch a MYTHIC?") | Egg spam montage → rarity reveals → Core Dragon / Galaxy Dragon reaction. Show egg odds on screen briefly (honesty + compliance). |
| 5 | "Noob vs Pro vs 10-Rebirth digger" | Split screen: toy shovel at 20 m, mid-game drill in Crystal Caverns, Core Breaker at the Core. Ends on the rebirth button. |

Posting cadence: 1 per day for the first 2 weeks, all from one account. Reuse the best performer with new
hooks. Title formula: `<hook> #roblox #robloxsimulator #digtothecore`.

### 7.2 Roblox Sponsored ads (Ads Manager)

- **Start small and measure:** about 1,000–2,000 Robux/day for 3 days, Search + Home placement, all devices.
  Use the 1920x1080 thumbnails as the creative (thumb_1 first, then A/B thumb_3).
- Scale only if D1 ≥ 15 % and average playtime ≥ 10 min (Analytics → Engagement). If CTR is low
  (< ~2 %), fix the **icon/thumbnail** first. If CTR is fine but retention is poor, fix the **first 5 minutes**.
- Launch Friday afternoon US time (kids' weekend). Don't spend during an outage or a broken build.
- Run "Thumbnail Personalization" / icon experiments in Creator Hub alongside ads (3 icon variants
  is plenty). Keep the winner for at least 2 weeks.
- Ad creative must show the real game. No fake rewards, no "free Robux", no imitation of other
  games' IP or UI.

### 7.3 Roblox group & Discord

- **Roblox group:** name it e.g. *"Dig to the Core Fans"* or your studio name. Set `GROUP_ID` in
  `src/shared/Config/init.luau` (members get +10 % sand). Pin a shout with the current codes and the
  DIGDEEP code. Group icon: reuse `marketing/icon.png` (any 512x512 works).
- **Discord** (13+ only, linked only through Social Links on the experience page, never from in-game
  text for under-13s). Banner: `marketing/social/discord_banner.png`. Channels: #announcements,
  #codes, #updates, #suggestions, #bug-reports, #pet-flex (screenshots), #general. Enable AutoMod and
  slow-mode, use a verification gate, and get 2–3 trusted moderators before you grow.
- Post every code in #codes **and** the group shout at the same time. Codes are the main reason kids join.
- X / Twitter: header `marketing/social/x_header.png`, avatar = icon. Post clips and code drops.

### 7.4 Influencer outreach

- Target **small-to-mid Roblox YouTubers/TikTokers (5K–200K subs)** who cover simulators. They answer
  more often and their audience matches ours.
- Offer: a private server (enable private servers at 50–100 R$, and give them a free one), a
  creator-only code that gives a cosmetic or boost (not Robux), early access to Update 1, and a
  shout-out in the update log. Use Roblox's official affiliate / creator programs where available.
  If you pay anyone, they must disclose it as sponsored content.
- Pitch template (keep it short): *"Hi <name>! We made **Dig to the Core! Beach Simulator**. You dig
  a hole through 15 layers (pirates, dinosaurs, crystals, lava, aliens) down to the Core. Would you be
  up for a video? We can give you a private server plus a custom code for your viewers. Link: <url>"*
- Track each creator in a sheet: name, link, sent date, reply, video link, CCU spike.

## 8. Pre-launch QA checklist

**Store page & assets**
- [ ] Icon uploaded (512x512 PNG, `marketing/icon.png`) and approved by moderation
- [ ] Thumbnails 1–4 uploaded (1920x1080) in order: hero, pets, treasure, rebirth. Video thumbnail
      added later if available
- [ ] Title ≤ 50 chars, description ≤ 1,000 chars, codes in the description actually work
- [ ] Genre = Simulation / Incremental Simulator; devices Phone/Tablet/Computer/Console
- [ ] Maturity questionnaire done, label = Minimal, paid random items disclosed, egg odds visible in-game
- [ ] Social links: Roblox group (and Discord/YouTube/X, 13+ rules)
- [ ] 10 badges created, ids in config, each one awarded correctly in a test server
- [ ] Game passes and dev products created, ids pasted into `Config/Monetization.luau`, prices as GDD §7
- [ ] `GROUP_ID` set, group bonus tested with a member and a non-member account
- [ ] Private servers enabled (50–100 R$/month)

**Gameplay (from GDD §11)**
- [ ] 1-player and 4-player local server test (Test → Clients and Servers)
- [ ] Phone emulator (iPhone SE size): every UI screen, buttons ≥ 48 px, nothing under the jump button / top bar
- [ ] FTUE: first dig < 15 s, first sell < 60 s, tutorial arrows point to the right things
- [ ] Save/load: earn → leave → rejoin; kick during save; two servers on the same account (session lock); shutdown saves
- [ ] Exploits: spam Dig remote, dig outside own plot or beyond reach, buy with insufficient coins,
      NaN/negative args, redeem a code twice, receipt replay
- [ ] Codes: RELEASE, SANDY, DIGDEEP redeem once each; 1KLIKES disabled until 1K likes
- [ ] Events: High Tide and Golden Hour banners and timers agree across two servers
- [ ] Performance: 12 players digging on a mid-range phone ≥ 30 FPS, server heartbeat ~60
- [ ] Economy playtest: 1 hour on a fresh account, compare against GDD §4 timings
- [ ] Analytics funnel events fire (joined, first dig, first sell, first shovel, first egg, first rebirth)

**Launch day**
- [ ] Publish Friday afternoon (US), set the experience Public, check the live page on mobile
- [ ] Group shout + Discord announcement + first Short posted
- [ ] Start the small sponsored-ads test; check Analytics after 24 h and 72 h
- [ ] Have a hotfix plan: who can publish, and how to roll back (Creator Hub → Places → Version History)
