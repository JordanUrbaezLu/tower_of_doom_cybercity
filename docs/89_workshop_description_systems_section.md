# 89 — Workshop description: a HOW IT WORKS section

> **STATUS: DRAFTED 2026-09-03, NOT APPLIED.** The section below is ready to
> paste into `zone/workshop.json`'s `Description`. It is deliberately NOT in
> that file yet: the description is outward-facing published copy, and the repo
> copy is the publish source, so anything sitting in it can go live on the next
> upload without a second look. Approve it and it drops in.

## First, a live-vs-repo finding (FIXED)

**The repo copy was NOT the latest, and publishing from it would have deleted
five people's credit.** Fetched the live item page and diffed it against
`zone/workshop.json`: the live description carries a **Testers** block —
UrbsBurger, NINJASNIPER996, brandino.ur, lukertino618, KingKov11 — that the repo
copy did not have, plus a slightly shorter Suno credit line. Someone edited the
description on the Steam page directly and it was never mirrored back.

Both are now restored in the repo copy (6175 → 6267 chars), and a re-diff shows
the two match line for line. **The standing rule that `zone/workshop.json` is
the thing to edit is only safe if the Steam page is never edited in place** —
when it is, the repo silently becomes a downgrade that the next publish applies.
Worth re-fetching and diffing before any publish, which is one curl and a diff.

## Why this section

User 2026-09-03: *"players actually read the description to learn about the map.
I wonder if we can add a section that explains some the systems and concepts"*.

The Workshop comments back this up — the systems questions arrive there rather
than being discovered in play. Actual examples pulled from the thread:

- *"Is there a way to see your current upgrade? Like when you hold Tab"* — the
  answer is the pause menu, and nothing tells the player that.
- *"i just got the mag reload on kill upgrade and it just straight up didn't
  work, nor showed up in the menu"* — a retired domain whose card art was still
  shipping. Fixed since, but it shows people read the cards closely.
- *"the buying another card, where the zombies are NOT paused while you decide"*
  — that is the terminal working as designed, read as a bug because it is never
  stated.

So the section should lead with the things people get wrong, not with a feature
list. Everything in it is verified against the live code, not written from
memory.

## Placement

Immediately after **YOUR GUN IS YOUR BUILD** and before **THE TOWER FIGHTS
BACK** — it explains what the section above just introduced, and it keeps the
enemy/finale build-up unbroken.

## Size

Repo description is **6267** chars with the credits restored; this section is
**~1450**, taking it to **~7700**. Steam's description field has a cap and
7700 is close enough to it that the upload should be checked: if it is
rejected or truncated, cut the PERKS MOVE and TERMINALS bullets first (they are
the two already half-covered elsewhere in the description).

## The section

```
[h2]HOW IT WORKS[/h2]

[b]The card deal.[/b] Every fourth round the world stops dead - nothing spawns, nothing moves - and you pick one of two upgrade cards. Fifteen seconds. Your tactical and lethal grenade buttons move between the cards; hold jump to lock one in.

[b]The luck bar.[/b] Kills, headshots, revives and doors fill it, and it empties after every deal. The fuller it is when a deal lands, the stronger the two cards. Keep it climbing past full and it starts to spark - that is the tower about to hand you its best.

[b]Upgrades are permanent and they stack.[/b] Pause the game at any point to see everything you own and exactly what each level is doing. If you are ever unsure what a card did, it is in there.

[b]Tier cards.[/b] Pack-a-Punch your class gun and climb, and a TIER card starts appearing in deals - take it and you move up your class's weapon ladder. Floor 10 unlocks the second gun, floor 30 the third; the card tells you when you are not high enough yet. A promotion resets the upgrades tied to your GUN. The ones tied to YOU - damage reduction, luck, sprint, health, headshots - come with you.

[b]Upgrade terminals.[/b] They sell you a card mid-climb, and this is the one that catches people out: [b]nothing pauses[/b]. The horde keeps coming while you read your two options and hold to choose. That is the price.

[b]The perks move.[/b] Eight of the nine machines pick new spots when the map loads and shuffle again every few rounds. Only Quick Revive stays put, down at the base. There is no route to memorise.
```

## Fact-check (every claim above, against the live code)

| Claim | Source |
|---|---|
| every fourth round | `TOD_UPG_EVERY_N_SHIP` = 4 |
| world stops, nothing spawns | `menu_freeze` + `level.tod_upgrade_pause` |
| fifteen seconds | the deal timeout fed to `wait_for_choice` |
| tactical / lethal move, hold jump locks | v16.57 offhand pair + `+gostand`, the only lanes advertised since v16.83 |
| luck fills on kills/headshots/revives/doors, resets each deal | `_tod_luck.gsc` |
| past full it sparks | OVERCHARGE at 150, bar art zap-animates (v14.9); the band is invisible by design, the spark is the only tell — so it is described as a tell, not a number |
| pause menu lists owned upgrades | `tod_upg_sync` → `CoD.TodOwned` → pause panel |
| floor 10 / floor 30 | `TOD_TIER2_FLOOR` / `TOD_TIER3_FLOOR`; the locked card carries the badge |
| gun-scoped reset, class-scoped kept | `domain_survives_tier` — DR, LUCK, SPRINT, SPRINTFIRE, SPRINTARMOR, BACKARMOR, VITALITY, HEADSHOT, SCAVENGER (assault) |
| terminals do not pause | `station_spawn` path — no `tod_upgrade_pause`, 15 s timer, world live |
| 8 of 9 perks scatter, QR pinned at base, reshuffle every 4 rounds | `_tod_perk_scatter.gsc` |

**Deliberately NOT claimed:** the perk cap (removed v16.80, so there is nothing
to explain), the overcharge threshold as a number (it is meant to be invisible),
and the Endless Spire grant details (the description already covers the Spire
and the grant changed in v16.36).

## To apply

1. Paste the section into `zone/workshop.json` `Description` at the placement
   above, keeping the BBCode.
2. Re-fetch the live page and diff first if any time has passed — the Steam page
   has been edited in place at least once (see the finding at the top).
3. The description ships with the Workshop upload, not with the `.ff`, so it
   needs no build.
