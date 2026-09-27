# 🍩 Steal a Donut

A brainrot-style Roblox game in the style of *Steal an Egg*: sneak down one long lane of increasingly
magical areas, grab donuts from under a sleeping guard's nose, outrun him back to the safe zone, and
put the donuts on your base where they make money — even while you're offline.

Everything (map, guards, donuts, UI) is built from code, so the project works without any uploaded
meshes, images or sounds.

---

## What's in the game

| Feature | Where it lives |
|---|---|
| **3 worlds, 20 areas.** World 1 *Donut Land* (grass → desert → candy → caves → ice → lava → neon city → crystals → cosmic), World 2 *Glaze Islands* (beach → coral reef → pirate cove → jelly jungle → volcano) and World 3 *Dream Dimension* (clouds → toy factory → haunted bakery → clockwork void → donut heaven). Worlds 2 and 3 are reached through portals in the hub, need rebirths, and everyone moves faster there (x1.2 / x1.4) | `src/shared/Areas.luau`, `src/server/MapBuilder.luau`, `src/server/Decor.luau`, `src/server/WorldService.luau` |
| **107 brainrot donuts**, 7 rarities (Common → Uncommon → Rare → Epic → Legendary → Celestial → Secret). Each area's best donut is a 1.5% spawn; Secrets are 0.02–0.1%. Rarer donuts get more effects: sparkles, lights, floating, light pillars, a glowing ring on the ground, orbiting orbs, halos, rainbow frosting, a shimmering aura | `src/shared/Donuts.luau`, `src/shared/Rarities.luau`, `src/shared/DonutModel.luau` |
| **Mutations** rolled on every spawn: Gold x2 (3%), Diamond x3 (1.2%), Mythic x5 (0.4%), Divine x10 (0.12%), Rainbow x25 (0.03%), each with its own look | `Rarities.Mutations` |
| **Sizes**: Small x0.6, Normal, Big x1.8, Huge x3.5, Giant x7. Bigger = more money, but you run 5% / 10% / 16% slower while carrying it | `Rarities.Sizes` |
| **Your own Homer.** Every player has their own sleeping guard on every blanket (drawn by your client) and only ever sees their own. Steal a donut → yours wakes up yelling and chases you; reach safety and he poofs back to his blanket | `src/server/GuardService.luau`, `src/client/Guards.luau`, `src/shared/GuardModel.luau` (hats + auras per area) |
| Reach the safe zone and he gives up; walk into your base (or the portal home in worlds 2/3) to place the donut. Get caught → you drop it and get flung home | `src/server/StealService.luau` |
| **Area events** every ~5 minutes near where players are: Sandstorm (desert), Blizzard (ice), Eruption (lava/volcano), Blood Moon (haunted), Golden Hour, Meteor Shower, Rainbow Rush… Weather effects + boosted mutation luck, and the area's donuts re-roll when it starts | `src/shared/Events.luau`, `src/server/EventService.luau`, `src/client/Weather.luau` |
| **Rebirths**: reset Money, Speed, treadmill, Speed Multiplier and your base donuts for x2, x3, x4… money AND speed forever, and unlock the next world. Keeps passes, items, skins, base expansions and Index rewards | `Config.Rebirth`, `ShopService` (`Rebirth` action), `src/client/UI/Rebirth.luau` |
| **Donut Index with rewards**: claim cash for every donut you've found; Epic+ donuts let you pick a permanent treadmill speed bonus instead (+1% / +3% / +8% / +20%). Shows which mutations you've found | `src/client/UI/Index.luau`, `Rarities.List[].IndexReward` |
| **Idle animations** for the donuts on every base: each has a personality (bouncing, swaying, dancing, looking around, or hovering if it floats), does a twirl / jump / wave / wiggle every few seconds, and blinks. Propellers spin, orbs orbit, tentacles wiggle, capes flutter. All client-side, only near the camera | `src/client/DonutIdle.luau` (limbs are marked in `DonutModel.luau`) |
| Money per second from every donut at your base; upgrades are cheap (+25% for 20 s of income, x1.3 per level) | `src/server/PlotService.luau`, `Config.DonutUpgrade` |
| **Base expansions**: start with 8 stands at the front of your base, buy up to 24 | `Config.Plots` |
| Offline / AFK earnings with a "Welcome back" popup (capped at 12h) | `src/server/PlayerService.luau` |
| Speed stat + treadmill next to every base: 15 tiers (the last ones need rebirths), locked onto the belt while running, "+speed" popups | `src/server/TreadmillService.luau`, `src/client/Treadmill.luau` |
| Shop: Speed Multiplier (x1.25 per level, multiplies), Treadmill, Base Expansion (money); 1.5x–10x Money, 2x Speed and **Teleporter** passes (Robux); base skins (paid with **Speed**) | `src/server/ShopService.luau`, `src/client/UI/Shop.luau` |
| **Teleporter pass**: jump to any unlocked world or the start of any area you're fast enough for | `src/client/UI/Worlds.luau`, `WorldService` |
| Four top-500 leaderboards next to the shop (Money earned, best Speed, Rarest donut incl. mutation, Time Played) | `src/server/LeaderboardService.luau`, `src/client/UI/Leaderboards.luau` |
| Podium outside each base showing the owner's rarest **or** top-earning donut | `src/server/PlotService.luau` |
| **Base raids** (like Steal a Brainrot): hold "Steal" for 15 s on another player's donut while they're outside their base | `src/server/RaidService.luau` |
| **Item shop**: Slap Hand, Donut Bat, Mega Hammer, Banana Peel, Launch Pad, Base Lock, each with its own model and sound effects | `src/server/ItemService.luau`, `Config.Items` |
| Soundtrack player with volume/on-off in Settings; songs that fail to load are skipped and reported in Output | `src/client/UI/Settings.luau`, `Config.Music` |
| Saving with session locking, autosave, safe shutdown and automatic upgrade of old saves | `src/server/DataService.luau` |

---

## Getting it into Roblox Studio

**Option A — just open it.** Double-click `StealADonut.rbxlx` (in this repo) to open it in Roblox Studio,
then press **Play**. The whole map is already in the file, so you can see and edit it before playing.

**Option B — Rojo (recommended if you'll keep editing code).**
1. Install [Rojo](https://rojo.space) (VS Code extension or CLI) and the Rojo Studio plugin.
2. `rojo serve` in this folder, then connect from the plugin in an empty baseplate.
3. Or build a fresh place file: `rojo build -o StealADonut.rbxlx`.

`src/` is the source of truth; `StealADonut.rbxlx` is just a build of it.

---

## Before you publish (checklist)

1. **Game Settings → Security → Enable Studio Access to API Services** (so saving and leaderboards
   work while you test). Without it the game still runs, it just doesn't save and shows a warning.
2. **Game Settings → Places → Max Players = 8.** There are 8 bases (`Config.Plots.Count`).
3. **Create the Game Passes** on the Creator Dashboard (Monetization → Passes):
   8 passes (1.5x, 2x, 3x, 4x, 5x, 10x Money, 2x Speed, Teleporter). Paste each ID into `GamePassId` in
   `src/shared/Config.luau`. Suggested prices are in `SuggestedPrice` (they're only shown until a real ID
   is set — after that the real price is read from Roblox). Any pass left at `GamePassId = 0` shows
   "coming soon" in live games. (Base skins are no longer passes: they're bought with Speed.)
4. In Studio, clicking a pass grants it for that test session for free
   (`Config.Debug.StudioFreePurchases`) — this never happens in a live server and is never saved.
   **This is why testing in Studio feels much faster than a real player's game**: with every money pass
   you earn 20.5x. Turn it off (or don't click the passes) when you judge the pacing.
5. Want to test late-game areas? Set `Config.Debug.StudioStartMoney` / `StudioStartSpeed` (Studio only).
6. **Music:** Roblox can't play YouTube links. Upload audio you own (Creator Dashboard → Development
   Items → Audio) or pick licensed tracks from the Creator Store, then add `{ Name = ..., Id = ... }`
   entries to `Config.Music.Tracks`. Audio must be public or owned by the game's owner, otherwise it
   won't play (the Output window tells you which ID failed).

---

## Design decisions you should know about

These are all one-line changes in `src/shared/Config.luau` if you disagree.

* **Skins are bought with Speed, as you asked — but that gives up Robux income.** Skins were the
  cheapest way for a player to spend Robux. If you want both, a skin could cost Speed *or* Robux.
* **Only Secret donuts get the big server-wide banner.** Area events and your own rebirths show a small
  toast instead (events only to players who can reach that world).
* **Rebirths reset your base donuts**, like Steal a Brainrot. The multiplier is big (x2, x3, x4…) so
  the replay of World 1 goes a lot faster each time.
* **The guard's name is a config value (`Config.Guard.Name`).** Heads-up: Homer Simpson is Disney/Fox IP.
  Roblox takes games down when a rights holder files a DMCA claim, and a game that grows popular is
  exactly the one that gets noticed. The in-game model is a generic blocky bald guy in a white shirt and
  blue pants; renaming him (e.g. "Donut Dad") removes the risk entirely.
* **Money passes stack additively** (`MoneyPassStacking = "Additive"`): owning 2x + 3x gives 4x; owning all
  six gives 20.5x. Multiplying them would give 1,800x and break the economy for buyers; "Highest" makes
  the cheap passes pointless once someone buys a big one.
* **The Money leaderboard ranks total money *earned*, not current cash.** Ranking current cash would drop
  players down the board every time they buy an upgrade — punishing exactly what you want them to do.
* **Offline earnings are capped at 12 hours** (`Config.Offline.MaxHours`). Uncapped, a player could stay
  away for a month and come back rich without playing.
* **Guards sleep at the back of their area**, so every donut is between you and safety and each steal is a
  straight race. With the guard in the middle, donuts behind him force you to run past an awake guard,
  and no amount of speed makes that fair.

---

## Balance

Speed turns into Roblox WalkSpeed on a log curve: every 10x more Speed ≈ +10 WalkSpeed (so numbers can
climb into the quadrillions without the game becoming unplayable). On top of that, everyone is x1.2
faster in World 2 and x1.4 faster in World 3, so the later worlds actually *feel* faster.

| Area | Recommended Speed | Homer WalkSpeed | Best donut (not counting Secrets) |
|---|---|---|---|
| 1 Glazed Meadow | any | 19 | $15/s (Rare) |
| 2 Sprinkle Park | 30 | 27 | $90/s (Rare) |
| 3 Sugar Dunes | 180 | 34 | $540/s (Epic) |
| 4 Frosting Falls | 1.1K | 42 | $3.2K/s (Epic) |
| 5 Chocolate Caverns | 6.5K | 50 | $19.5K/s (Legendary) |
| 6 Glacier Glaze | 40K | 57 | $117K/s (Legendary) |
| 7 Molten Bakery | 240K | 65 | $700K/s (Legendary) |
| 8 Neon Donut City | 1.4M | 73 | $4.2M/s (Legendary) |
| 9 Crystal Cosmos | 8.5M | 81 | $25M/s (Celestial) |
| 10 Celestial Donut Dimension | 50M | 88 | $150M/s (Celestial) |
| 11 Glaze Beach | 300M | 115 | $900M/s (Legendary) |
| 12 Coral Crullers | 1.8B | 125 | $5.4B/s (Legendary) |
| 13 Pirate Cove | 11B | 134 | $33B/s (Legendary) |
| 14 Jelly Jungle | 65B | 143 | $196B/s (Celestial) |
| 15 Volcano Isle | 400B | 153 | $1.2T/s (Celestial) |
| 16 Cloud Bakery | 2.4T | 192 | $7T/s (Legendary) |
| 17 Toy Factory | 14T | 203 | $42T/s (Celestial) |
| 18 Haunted Donuttery | 85T | 214 | $254T/s (Celestial) |
| 19 Clockwork Void | 500T | 224 | $1.5Qa/s (Celestial) |
| 20 Donut Heaven | 3Qa | 235 | $9.1Qa/s (Celestial) |

Checked with a chase simulation (with ~120 ms of network lag): at the recommended speed you escape
even from the donut right next to Homer; a couple of WalkSpeed below it the risky donuts get you
caught. Worlds 2 and 3 start with a long bridge so their first areas are just as far from safety as
if the lane kept going — without it, a player who just rebirthed (Speed 0) could steal World 2 donuts
next to the safe zone and skip the whole game.

Pacing, from a simulated bot that steals, upgrades and trains efficiently and buys **no** passes:

| Milestone | Bot time |
|---|---|
| Area 2 / Area 5 | 4 min / 24 min |
| Area 10 (end of World 1) | ~85 min |
| Rebirth 1 → World 2 | ~1.5 h |
| End of World 2, Rebirth 2 → World 3 | ~4 h |
| Area 20, Rebirth 3 | ~8.5 h |
| Rebirths 4–10 | many more hours (speed requirements x7–8 each) |

Real players usually take 2–3x longer than the bot. Before this update the same bot reached the end in
about 70 minutes, and in Studio with every money pass (free test purchases) it's ~20x faster than that.
Tune with `Config.Treadmill`, `Config.SpeedMultiplier`, `Config.Rebirth`, `Config.Plots.ExpansionCosts`
and donut incomes.

The guard's speed is derived from each area's `RecommendedSpeed` (+`GuardSpeedBonus`, and the world's
speed bonus), so if you rebalance speeds the signs and the guards stay in sync automatically.

---

## Editing the map by hand

The map is saved in the place file (`map/Map.model.json` in this repo), so it's visible in Studio's
edit mode. Move, restyle or replace anything and save. At runtime, if `Workspace.Map` exists the game
uses it as-is instead of building a new one.

Keep the names that the scripts look up: `Plots/PlotN` (with `Slots/SlotN`, `Spawn`, `SignAnchor`,
`TreadmillAnchor`, `PodiumAnchor`), `Lane/AreaN` (with `Spawns/DonutSpawn`, `GuardHome`),
`Hub/ShopStall/PromptPart` + `Glow`, `Hub/Leaderboards/Board_X/Screen`, the portals (`Hub/Portals`,
`Worlds/WorldN/HomePortal`, each with a `Trigger` part) and `Worlds/WorldN/Arrival`.

If you had edited an older copy of the map: it's upgraded automatically when the game starts (missing
areas, worlds and portals are added, and the donut stands are rebuilt at the front of each base).

Want a fresh copy of the generated map (e.g. after changing `Config.Map` or area themes)? Delete
`Workspace.Map`, then in **View → Command Bar** run
`require(game.ServerScriptService.Server.MapBuilder).Build()` and save.

## Adding content

* **New donut:** copy a line in `src/shared/Donuts.luau`, give it a unique `Id`. The Index, spawns,
  leaderboards and podium pick it up automatically. Accessories available in `Parts`:
  `Legs, Arms, Bat, Tutu, Mustache, TopHat, Sunglasses, Visor, Camel, SharkFin, Pharaoh, CoffeeCup,
  MonkeyEars, Horns, PlaneWings, Crown, Halo, Wings, Flames, IceSpikes, Beak, Antenna, Cape, Orbit,
  Leaf, Snorkel, Tentacles, Fangs, PirateHat, EyePatch, Propeller, WitchHat, Gears, Bow`.
  Add new donuts at the end of the list (the list position is part of the saved "rarest donut" score).
* **New event:** add an entry to `src/shared/Events.luau` with the area themes it can happen in.
* **New area:** add an entry to `src/shared/Areas.luau` with its `World` and `Index` (theme = one of the
  existing decor themes or a new function in `Decor.luau`), and give it donuts.
* **New skin:** add to `Config.Skins`.

---

## Project layout

```
src/
  shared/   (ReplicatedStorage.Shared)  config, data tables, formulas, donut model builder
  server/   (ServerScriptService.Server) map builder + services (data, plots, guards, steal, shop...)
  client/   (StarterPlayerScripts.Client) UI and client-only effects
default.project.json   Rojo project
StealADonut.rbxlx      ready-to-open build
```

## Known limitations / next steps

* Every script passes strict Luau type-checking against the Roblox API, and the game was run end-to-end
  in a Roblox API emulator (join → steal → chase → deposit → income → treadmill → shop → caught →
  leaderboards → index rewards → expansion → rebirth → portal to World 2 → steal there → portal home →
  teleporter → events → save/rejoin). An emulator can't show visuals or real physics, so things like the
  guard's lying-down height or UI spacing on a specific phone still need an eye in Studio.
* Anti-cheat is basic (server-side reach checks, a speed check while carrying a donut, rate-limited
  remotes). Speed exploiters can still move faster when *not* carrying a donut.
* Common retention features not included yet: daily rewards, friend boosts, a trading system.
