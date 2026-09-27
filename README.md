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
| One lane, 10 areas that go from plain grass → desert → candy → caves → ice → lava → neon night city → floating crystals → cosmic dimension | `src/shared/Areas.luau`, `src/server/MapBuilder.luau`, `src/server/Decor.luau` |
| 53 brainrot donuts across 9 rarities (Common → Secret). Rarer donuts get lights, particles, light pillars, halos, wings and rainbow frosting | `src/shared/Donuts.luau`, `src/shared/Rarities.luau`, `src/shared/DonutModel.luau` |
| A sleeping guard (default name "Homer") in every area. Steal a donut → he wakes up yelling and chases you. Each area's guard is faster | `src/server/GuardService.luau` |
| Reach the safe zone and he gives up; walk into your base to place the donut. Get caught → you drop it and get flung home | `src/server/StealService.luau` |
| Money per second from every donut at your base, with upgrades that cost more each level, and selling | `src/server/PlotService.luau` |
| Offline / AFK earnings with a "Welcome back" popup (capped at 12h) | `src/server/PlayerService.luau` |
| Speed stat + treadmill next to every base (starts at +1/s, 10 upgradeable treadmill tiers that look cooler each tier). Step on it and you're locked onto the belt running; a "+speed" popup appears somewhere on screen every second; press Space / Jump / "Get off" to step off | `src/server/TreadmillService.luau`, `src/client/Treadmill.luau` |
| Shop (walk onto the glowing circle or press E at the stall): Speed Multiplier + Treadmill upgrades (money), 1.5x/2x/3x/4x/5x/10x Money and 2x Speed passes (Robux), 7 Robux base skins + a free one | `src/server/ShopService.luau`, `src/client/UI/Shop.luau` |
| Four top-500 leaderboards next to the shop (Money, Speed, Rarest Donut, Time Played) — scrollable on the boards and in a Top 500 window | `src/server/LeaderboardService.luau`, `src/client/UI/Leaderboards.luau` |
| Podium outside each base showing the owner's rarest **or** top-earning donut (press E on it to switch) | `src/server/PlotService.luau` |
| Donut Index with 3D previews and silhouettes for undiscovered donuts | `src/client/UI/Index.luau` |
| HUD modelled on the reference screenshots: Shop / Index buttons on the left, big outlined Speed + Money bottom-left, square buttons on the right, Slow Mode toggle | `src/client/UI/HUD.luau` |
| Soft, easy-on-the-eyes lighting (lower sun for longer shadows, darker ambient, low bloom) that shifts per area (day → sunset → night) so later areas feel mystical | `src/server/MapBuilder.luau` (`setupLighting`), `src/shared/Areas.luau`, `src/client/Effects.luau` |
| Saving with session locking, autosave, and safe shutdown | `src/server/DataService.luau` |

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
   7 passes (1.5x, 2x, 3x, 4x, 5x, 10x Money, 2x Speed) + 7 base skins (Candy, Frozen, Neon, Lava, Gold,
   Galaxy, Rainbow). Paste each ID into `GamePassId` in `src/shared/Config.luau`.
   Suggested prices are in `SuggestedPrice` (they're only shown until a real ID is set — after that the
   real price is read from Roblox). Any pass left at `GamePassId = 0` shows "coming soon" in live games.
4. In Studio, clicking a pass/skin grants it for that test session for free
   (`Config.Debug.StudioFreePurchases`) — this never happens in a live server and is never saved.
5. Want to test late-game areas? Set `Config.Debug.StudioStartMoney` / `StudioStartSpeed` (Studio only).

---

## Design decisions you should know about

These are all one-line changes in `src/shared/Config.luau` if you disagree.

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

Speed turns into Roblox WalkSpeed on a log curve: every 10x more Speed ≈ +10 WalkSpeed
(so numbers can climb into the billions without the game becoming unplayable).

| Area | Recommended Speed | Guard WalkSpeed | Top donut |
|---|---|---|---|
| 1 Glazed Meadow | any | 19 | $15/s (Rare) |
| 2 Sprinkle Park | 25 | 26 | $90/s (Epic) |
| 3 Sugar Dunes | 200 | 35 | $540/s (Legendary) |
| 4 Frosting Falls | 1.5K | 43 | $3.2K/s (Mythic) |
| 5 Chocolate Caverns | 12K | 52 | $19.5K/s (Mythic) |
| 6 Glacier Glaze | 100K | 61 | $117K/s (Divine) |
| 7 Molten Bakery | 800K | 70 | $700K/s (Divine) |
| 8 Neon Donut City | 7M | 80 | $4.2M/s (Divine) |
| 9 Crystal Cosmos | 60M | 89 | $100M/s (Secret, 0.3%) |
| 10 Celestial Donut Dimension | 500M | 98 | $1.5B/s (Secret, 0.15%) |

Checked with a chase simulation that includes ~120 ms of network lag: at the recommended speed you
escape even from the donut right next to the guard; about 2 WalkSpeed below it the risky donuts get you
caught; about 8 below, nothing in that area is safe. Area 1 works at the starting speed.

A pacing simulation (a bot that steals, upgrades and trains efficiently) reaches Area 2 in ~5 minutes
and Area 10 in ~70 minutes. Expect real players to take 2–4x longer. Tune with the treadmill tier
costs, `Config.SpeedMultiplier`, and donut incomes.

The guard's speed is derived from each area's `RecommendedSpeed` (+`GuardSpeedBonus`), so if you
rebalance speeds the signs and the guards stay in sync automatically.

---

## Editing the map by hand

The map is saved in the place file (`map/Map.model.json` in this repo), so it's visible in Studio's
edit mode. Move, restyle or replace anything and save. At runtime, if `Workspace.Map` exists the game
uses it as-is instead of building a new one.

Keep the names that the scripts look up: `Plots/PlotN` (with `Slots/SlotN`, `Spawn`, `SignAnchor`,
`TreadmillAnchor`, `PodiumAnchor`), `Lane/AreaN` (with `Spawns/DonutSpawn`, `GuardHome`),
`Hub/ShopStall/PromptPart` + `Glow`, and `Hub/Leaderboards/Board_X/Screen`.

Want a fresh copy of the generated map (e.g. after changing `Config.Map` or area themes)? Delete
`Workspace.Map`, then in **View → Command Bar** run
`require(game.ServerScriptService.Server.MapBuilder).Build()` and save.

## Adding content

* **New donut:** copy a line in `src/shared/Donuts.luau`, give it a unique `Id`. The Index, spawns,
  leaderboards and podium pick it up automatically. Accessories available in `Parts`:
  `Legs, Arms, Bat, Tutu, Mustache, TopHat, Sunglasses, Visor, Camel, SharkFin, Pharaoh, CoffeeCup,
  MonkeyEars, Horns, PlaneWings, Crown, Halo, Wings, Flames, IceSpikes, Beak, Antenna, Cape, Orbit`.
* **New area:** add an entry to `src/shared/Areas.luau` (theme = one of the existing decor themes or a
  new function in `Decor.luau`), and give it donuts.
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
  leaderboards → save/rejoin). An emulator can't show visuals or real physics, so things like the
  guard's lying-down height or UI spacing on a specific phone still need an eye in Studio.
* Anti-cheat is basic (server-side reach checks, a speed check while carrying a donut, rate-limited
  remotes). Speed exploiters can still move faster when *not* carrying a donut.
* Common retention features not included yet: rebirths, daily rewards, friend boosts, stealing from
  other players' bases.
