# 🍩 Steal a Donut

A brainrot-style Roblox game in the style of *Steal an Egg*: sneak down one long lane of increasingly
magical areas, grab donuts from under a sleeping (and HUGE) guard's nose, outrun him back to the safe
zone, and put the donuts on your base where they make money — even while you're offline. Then raid other
players' bases, hatch pet eggs, and chase the ultra-rare Admin donuts.

Everything (map, guards, donuts, UI) is built from code, so the project works without any uploaded
meshes, images or sounds.

---

## What's in the game

| Feature | Where it lives |
|---|---|
| **3 worlds, 20 areas.** World 1 *Donut Land* (grass → desert → candy → caves → ice → lava → neon city → crystals → cosmic), World 2 *Glaze Islands* (beach → coral reef → pirate cove → jelly jungle → volcano) and World 3 *Dream Dimension* (clouds → toy factory → haunted bakery → clockwork void → donut heaven). Worlds 2 and 3 are reached through portals in the hub, need rebirths, and everyone moves faster there (x1.2 / x1.3) |
| **Your base comes with you.** Every world has its own hub with 8 base plots; when you go to another world your base (donuts, treadmill, traps, incubator) moves to your plot there, so you never run back and forth. The 🏠 portal takes you home to World 1 | `src/server/PlotService.luau` (`MoveBase`), `src/server/WorldService.luau`, `Layout.PlotCFrame(plot, world)` | `src/shared/Areas.luau`, `src/server/MapBuilder.luau`, `src/server/Decor.luau`, `src/server/WorldService.luau` |
| **110 brainrot donuts**, 8 rarities (Common → Uncommon → Rare → Epic → Legendary → Celestial → Secret → **ADMIN**). Each area's best donut is a ~1% spawn; Secrets are 0.006–0.03%. The three **Admin** donuts (end of each world: areas 10, 15, 20) are about **1 in 24,000 spawns** and get a red beam, halo, orbiting orbs and a server-wide banner. Rarer donuts get more effects: sparkles, lights, floating, light pillars, a glowing ring on the ground, orbiting orbs, halos, rainbow frosting, a shimmering aura | `src/shared/Donuts.luau`, `src/shared/Rarities.luau`, `src/shared/DonutModel.luau` |
| **Mutations** rolled on every spawn: Gold x2 (1.2%), Diamond x3 (0.5%), Mythic x5 (0.15%), Divine x10 (0.04%), Rainbow x25 (0.01%), each with its own look | `Rarities.Mutations` |
| **Global rarity stats**: the Index shows, for every Legendary-or-rarer donut and every mutation, how many have *spawned* and been *found* across the whole game so far (all servers), plus "#N ever found" in the steal announcement | `src/server/StatsService.luau` (sharded DataStore counters), `Config.GlobalStats` |
| **Sizes**: Small x0.6, Normal, Big x1.8, Huge x3.5, Giant x7. Bigger = more money, but you run 5% / 10% / 16% slower while carrying it | `Rarities.Sizes` |
| **Your own Domer — and he's HUGE** (4x size), and 7.5% faster than his base speed (`Config.Guard.SpeedMultiplier`). Every player has their own sleeping guard on every blanket (drawn by your client) and only ever sees their own. Steal a donut → yours wakes up yelling and chases you. You hear his footsteps when he's within ~110 studs and the screen shakes harder the closer he gets (from 45 studs); the red edge glow pulses faster too | `src/server/GuardService.luau`, `src/client/Guards.luau`, `src/client/UI/Chase.luau`, `src/shared/GuardModel.luau` |
| **He catches you at 10 studs — really 10.** The catch is lag-compensated: the server checks the distance between where *you* were and where he was *as your screen showed him* (rewound by your ping), so a fast runner with lag no longer gets caught from 40 studs away | `GuardService.PerceivedDistance`, `Config.Guard.CatchRadius` |
| Reach the safe zone and he gives up; walk into your base to place the donut. **Get caught or hit while carrying a donut → it goes back to the exact spot it spawned** (anyone can steal it again), and you get flung home | `src/server/StealService.luau`, `DonutSpawnService.Return` |
| **Area events** every ~5 minutes near where players are: Sandstorm (desert), Blizzard (ice), Eruption (lava/volcano), Blood Moon (haunted), Golden Hour, Meteor Shower, Rainbow Rush… Weather effects + boosted mutation luck, and the area's donuts re-roll when it starts | `src/shared/Events.luau`, `src/server/EventService.luau`, `src/client/Weather.luau` |
| **Rebirths**: reset Money, Speed, treadmill, Speed Multiplier and your base donuts for x2, x3, x4… money AND speed forever, and unlock the next world. Keeps passes, items, skins, base expansions and Index rewards | `Config.Rebirth`, `ShopService` (`Rebirth` action), `src/client/UI/Rebirth.luau` |
| **Donut Index with rewards**: claim cash for every donut you've found; Epic+ donuts let you pick a permanent treadmill speed bonus instead (+1% / +3% / +8% / +20%). Shows which mutations you've found | `src/client/UI/Index.luau`, `Rarities.List[].IndexReward` |
| **Mystical effects** for rare and mutated donuts, getting crazier with rarity: Legendary *Radiance* (spinning sun rays), Celestial *Starlight* (twinkling stars, magic circle, comets), Secret *Void* (rainbow particles pouring in like a black hole, prismatic lightning, triple magic circle, 5 rainbow comets, shockwaves, galaxy-coloured dough, colour-shifting outline); mutations add *Treasure* (Gold), *Glitter* (Diamond), *Hellfire* (Mythic: red fire, smoke, embers, red lightning rising from a demonic circle, a throbbing heartbeat glow), *Holy* (Divine: god rays from the sky, falling light, golden lightning strikes with shockwaves) and *Prism* (Rainbow: rainbow rays, lightning, comets and a rainbow donut). The moving parts are drawn by each client for the closest donuts only | `src/shared/FXThemes.luau`, `src/shared/DonutModel.luau`, `src/client/DonutFX.luau` |
| **Idle animations** for the donuts on every base: each has a personality (bouncing, swaying, dancing, looking around, or hovering if it floats), does a twirl / jump / wave / wiggle every few seconds, and blinks. Propellers spin, orbs orbit, tentacles wiggle, capes flutter. All client-side, only near the camera | `src/client/DonutIdle.luau` (limbs are marked in `DonutModel.luau`) |
| Money per second from every donut at your base; upgrades are cheap (+25% for 20 s of income, x1.3 per level) | `src/server/PlotService.luau`, `Config.DonutUpgrade` |
| **Base expansions**: start with 8 stands at the front of your base, buy up to 24 | `Config.Plots` |
| **Second floor**: once all 24 stands are unlocked, the Base Expansion card in the shop turns into **🏢 Second Floor** ($1Qn, 200x the last expansion): a deck over your whole base with 24 more stands (48 total). Glowing lift pads at the front take anyone up and down (thieves too: raids work upstairs). It's 26 studs up, above even a Giant donut, follows your base to every world, and is kept through rebirths | `PlotService` (`BuySecondFloor`), `Config.Plots.SecondFloor` |
| Offline / AFK earnings with a "Welcome back" popup (capped at 12h) | `src/server/PlayerService.luau` |
| **Speed is linear now**: every 10 Speed = +1 WalkSpeed (16 + Speed/10, max 220), so every bit of training is felt. Treadmill next to every base: 15 tiers (the last ones need rebirths), locked onto the belt while running. Effects: chasing LED strips, a spinning fan, sparks and dust from the belt, a glowing aura on high tiers, camera FOV kick, speed lines, a trail and "+N WALK SPEED!" bursts | `Economy.WalkSpeedFromStat`, `src/server/TreadmillService.luau`, `src/client/Treadmill.luau` |
| Shop: Speed Multiplier (+5% per level, 20 levels), Treadmill, Base Expansion (money); 1.5x–10x Money, 2x Speed and **Teleporter** passes (Robux); the **Luck Event** (Robux); base skins (paid with **Speed**) | `src/server/ShopService.luau`, `src/client/UI/Shop.luau` |
| **Luck Event** (developer product, suggested R$100): 10 minutes of better donuts for **the whole server** — rare donuts x3, mutations x3, Big/Huge/Giant x2, better eggs. Buying again adds 10 more minutes. A timer pill shows on everyone's screen with the buyer's name | `src/server/LuckService.luau`, `src/server/ProductService.luau`, `Config.LuckEvent` |
| **Pet eggs**: from area 4 on, eggs appear on the lane now and then (7 kinds; the rarer the egg, the deeper it spawns and the crazier it looks — rune rings, orbiting stars, light pillars, god rays, a Void egg with a swirling vortex). Carry one home like a donut; it goes into your base's incubator and hatches on a timer (3 min for a Sprinkle Egg … 90 min for a Void Egg) with a hatch animation. **30 pets** give money and treadmill-speed bonuses; rarer eggs → better pets. Equip 3; bonuses are capped at +600% money / +300% speed. Pets are kept through rebirths. Crate exclusives: the **Royal Egg** (4 pets you can't get anywhere else) and the **Crate King** pet | `src/shared/Pets.luau`, `src/shared/PetModel.luau`, `src/server/PetService.luau`, `src/client/UI/PetsWindow.luau`, `src/client/PetFX.luau` |
| **Favorite donut**: press **R** on one of your own donuts (❤ Favorite) and a copy at **1/3 of its size** follows you around, with its mutation look. The real one stays on its stand and keeps earning; if it's sold, stolen or reset by a rebirth, the follower goes away. (Replaces the old Index "Buddy") | `PlotService.FavoriteSlot`, `src/client/Followers.luau`, `Config.Favorite` |
| **Crates**: Common / Rare / Epic / Legendary. They show up now and then in the lane (hold E to open, no chase; mostly Common, Legendary is ~1 in 200) or can be bought in the shop's **🎁 Crates** tab for R$50 / 150 / 300 / 800 (developer products). Each gives ONE reward: coins (scaled to how far your Speed gets you), a 10-minute Speed Boost (run 20% faster, counts down only while you play), a 10-minute server-wide Luck Event, an egg (straight into your incubator), or for Legendary the exclusive Royal Egg or Crate King pet. Every outcome and its exact % is on the card, with an "All odds" page that also lists every pet inside the eggs. An opening animation plays for each crate | `src/shared/Crates.luau`, `src/shared/CrateModel.luau`, `src/server/CrateService.luau`, `src/client/UI/CrateOpen.luau`, `Config.Crates` |
| **Donations**: R$10 / 50 / 100 / 500 / 1,000 buttons (developer products) and a **TOP DONATORS** board. Flightly33 is pinned at the top with R$100T, with "-10 Robux donated" under the name (a joke row: shown to everyone, never saved, not counted) | `src/client/UI/Donate.luau`, `ProductService`, `Config.Donations` |
| **Admin panel**: type `ender=cool` in chat (the message is hidden from everyone else) to open a cheat panel: money, speed, max treadmill, rebirth, any donut with any mutation/size, spawn donuts, eggs, hatch all, pets, luck event, area events, "Domer can't catch me", teleport. Works for the game's owner, in Studio, and for `Config.Admin.AllowedUserIds`. Anyone who used it is left off the global leaderboards | `src/server/AdminService.luau`, `src/client/UI/Admin.luau`, `Config.Admin` |
| **Teleporter pass**: jump to any unlocked world or the start of any area you're fast enough for | `src/client/UI/Worlds.luau`, `WorldService` |
| Five top-500 leaderboards next to the shop (Money earned, best Speed, Rarest donut incl. mutation, Time Played, Top Donators). There's no leaderboard button on the HUD any more; the boards in the hub are scrollable | `src/server/LeaderboardService.luau`, `src/client/UI/Leaderboards.luau` |
| Podium outside each base showing the owner's rarest **or** top-earning donut | `src/server/PlotService.luau` |
| **Base raids** (like Steal a Brainrot): hold "Steal" for 2.5 s on another player's donut. The donut goes above the thief's head and the thief is put in **slow mode** (WalkSpeed 16). The owner hears an **alarm**, sees the thief outlined in red and gets a warning the moment someone starts stealing. The thief has to reach **their own base** before the owner (or anyone) hits them — one hit and the donut flies back to the owner's stand. Only an active **Base Lock** stops raids | `src/server/RaidService.luau`, `StealService.StartRaid`, `src/client/UI/Chase.luau` |
| **Item shop**: Slap Hand (free for everyone, so every owner can defend), Donut Bat, Mega Hammer, Banana Peel, Launch Pad, Base Lock. New 3D models held properly in the hand, and a spinning 3D preview in the shop | `src/shared/ItemModel.luau`, `src/server/ItemService.luau`, `Config.Items` |
| **Cleaner UI**: everything is ~18% smaller (`Theme.UIScale`), buttons grouped on the left and right edges, notifications stacked so they don't cover each other | `src/client/UI/HUD.luau`, `src/client/UI/Theme.luau` |
| Soundtrack player with volume/on-off in Settings and a **🎵 Music** on/off switch on the HUD (under Slow Mode); songs that fail to load are skipped and reported in Output. **No songs are set up yet** (`Config.Music.Tracks` is empty), see the checklist | `src/client/UI/Settings.luau`, `Config.Music` |
| Saving with session locking, autosave, safe shutdown and automatic upgrade of old saves (old Speed stats are converted so every player keeps exactly the walk speed they had) | `src/server/DataService.luau` |

---

## Getting it into Roblox Studio

**Option A — just open it.** Double-click `StealADonut.rbxlx` (in this repo) to open it in Roblox Studio,
then press **Play**. The whole map is already in the file, so you can see and edit it before playing.

**Option B — Rojo (recommended if you'll keep editing code).**
1. Install [Rojo](https://rojo.space) (VS Code extension or CLI) and the Rojo Studio plugin.
2. `rojo serve` in this folder, then connect from the plugin in an empty baseplate.
3. Or build a fresh place file: `rojo build -o StealADonut.rbxlx`.

`src/` is the source of truth; `StealADonut.rbxlx` is just a build of it.

Note: the map saved in the place file is still the previous version. When you press Play it's upgraded
automatically (the World 2/3 hubs with their base plots, incubators, bigger blankets for Domer, the
donation board, and up-to-date area signs). So in **edit mode** you won't see the new world hubs until
you re-bake the map (see *Editing the map by hand*).

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
4. **Create the Developer Products** (Monetization → Developer Products): one for the Luck Event
   (suggested R$100), one per crate (R$50 / 150 / 300 / 800) and one per donation amount (R$10, 50,
   100, 500, 1,000). Paste the IDs into `Config.LuckEvent.DeveloperProductId`,
   `Config.Crates.Products[...].DeveloperProductId` and `Config.Donations.Products[...].DeveloperProductId`.
   Until then, pressing those buttons in a live game just says "coming soon". Every purchase is recorded on the
   player's save, so Roblox retrying a receipt never grants it twice.
5. **Crates are "paid random items"** under Roblox's rules. Tick that in the **Maturity & Compliance
   Questionnaire** on the Creator Dashboard. The game already does the rest: the odds are shown before
   buying, and players whose region doesn't allow paid random items (`PolicyService`) can't buy
   crates (they can still open the ones they find). If you change the odds, change them in
   `Crates.luau` — the shop reads them from there, so what players see is always what they get.
6. **Admin panel access.** The code works for the game's owner (for a group game: the group's owner)
   and in Studio. To let friends use it, put their UserIds in `Config.Admin.AllowedUserIds`.
   Don't turn on `AllowAnyone` in a live game: anyone who hears the code would get free money and
   free Luck Events. To change the code itself, edit `ADMIN_CODE` in `src/server/AdminService.luau`
   (it lives on the server on purpose: code in `src/shared` can be read by exploiters).
7. In Studio, clicking a pass or product grants it for that test session for free
   (`Config.Debug.StudioFreePurchases`) — this never happens in a live server and is never saved.
   **This is why testing in Studio feels much faster than a real player's game**: with every money pass
   you earn 20.5x. Turn it off (or don't click the passes) when you judge the pacing.
8. Want to test late-game areas? Set `Config.Debug.StudioStartMoney` / `StudioStartSpeed` (Studio only),
   or use the admin panel.
9. **Music:** there are no songs yet, so the Music switch has nothing to mute until you add some. Roblox can't play YouTube links. Upload audio you own (Creator Dashboard → Development
   Items → Audio) or pick licensed tracks from the Creator Store, then add `{ Name = ..., Id = ... }`
   entries to `Config.Music.Tracks`. Audio must be public or owned by the game's owner, otherwise it
   won't play (the Output window tells you which ID failed).

---

## Design decisions you should know about

These are all one-line changes in `src/shared/Config.luau` if you disagree.

* **Crates give one reward each**, picked by the odds on the card (the way you described Common and
  Legendary). Found crates use the same odds as bought ones. A crate's **Luck Event is server-wide**,
  because donuts in the lane are shared by everyone, so a personal luck boost couldn't make only your
  donuts better. The **Speed Boost** makes you run 20% faster, which *does* make Domer easier while it
  lasts; it only counts down while you're in the game, so a paid boost isn't wasted by leaving.
  Crate eggs and pets skip the incubator / pet limits so a paid reward is never lost.
* **The second floor uses lift pads, not stairs.** There's no room for a ramp inside the fence without
  cutting through the stands, and the pads sit exactly above each other, so riding them with a
  stolen donut doesn't trip the anti-teleport check.
* **The Luck Event is a developer product, not a game pass.** A game pass can only be bought once,
  ever, so it can't be a repeatable "10 minutes of luck". It boosts the **whole server** (like the
  big games do): the buyer gets a shout-out, everyone nearby benefits, and that's what sells it.
* **Raids no longer need the owner to be away.** The old rule ("only while the owner is outside
  their base") was a big reason raids felt broken — the owner was almost always standing at home.
  Now anyone can raid anytime, but the thief is slow, glowing red and the owner gets an alarm, and
  everyone gets the Slap Hand free, so defending is always possible. The Base Lock is the only hard
  block. If raids become too punishing, raise `Config.Raid.HoldSeconds` or lower `CarryWalkSpeed`.
* **Admin donuts can come from the admin panel too.** Players who used the panel are hidden from the
  global leaderboards and their finds don't count in the global "found" stats; donuts placed with the
  panel don't count as spawned or found for anyone. So the rarity numbers stay real.
* **Skins are bought with Speed, as you asked — but that gives up Robux income.** Skins were the
  cheapest way for a player to spend Robux. If you want both, a skin could cost Speed *or* Robux.
* **Only Secret donuts get the big server-wide banner.** Area events and your own rebirths show a small
  toast instead (events only to players who can reach that world).
* **Rebirths reset your base donuts**, like Steal a Brainrot. The multiplier is big (x2, x3, x4…) so
  the replay of World 1 goes a lot faster each time.
* **The guard is now called Domer (`Config.Guard.Name`).** That lowers the Homer Simpson (Disney/Fox IP)
  risk but doesn't remove it: "Domer", a bald guy in a white shirt and blue pants who loves donuts, is
  still obviously a parody of Homer. Parody isn't a safe harbour on Roblox — takedowns are decided on
  a DMCA claim, not in court. If the game takes off, consider changing his look too (hair, colours).
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

**Speed is linear:** WalkSpeed = 16 + Speed / 10 (capped at 220). 90 Speed = 25 WalkSpeed, 810 Speed =
97 WalkSpeed, and every treadmill session makes a visible difference. On top of that everyone is x1.2
faster in World 2 and x1.3 faster in World 3.

**Domer is 7.5% faster** than his base speed (`Config.Guard.SpeedMultiplier = 1.075`). Because that's a
percentage, it bites harder the faster everyone is: +1.6 WalkSpeed in Area 1, +19 in Area 20. So the
**Recommended Speed is now worked out from the chase itself** (`Economy.RecommendedSpeed`): it's the
Speed that gets you home with at least the front half of an area's donuts (the ones deep in the area,
near Domer's blanket, need more). The signs, the HUD, the teleporter, events and crate coins all use it,
and it updates by itself if you change Domer's speed again.

| Area | Recommended Speed | Your WalkSpeed at that Speed | Domer WalkSpeed | Best donut (not counting Secrets) |
|---|---|---|---|---|
| 1 Glazed Meadow | any | 16 | 22 | $15/s (Rare) |
| 2 Sprinkle Park | 90 | 25 | 32 | $90/s (Rare) |
| 3 Sugar Dunes | 180 | 34 | 41 | $540/s (Epic) |
| 4 Frosting Falls | 270 | 43 | 51 | $3.2K/s (Epic) |
| 5 Chocolate Caverns | 360 | 52 | 61 | $19.5K/s (Legendary) |
| 6 Glacier Glaze | 460 | 62 | 70 | $117K/s (Legendary) |
| 7 Molten Bakery | 550 | 71 | 80 | $700K/s (Legendary) |
| 8 Neon Donut City | 650 | 81 | 90 | $4.2M/s (Legendary) |
| 9 Crystal Cosmos | 740 | 90 | 99 | $25M/s (Celestial) |
| 10 Celestial Donut Dimension | 840 | 100 | 109 | $150M/s (Celestial) |
| 11 Glaze Beach | 940 | 132 | 145 | $900M/s (Legendary) |
| 12 Coral Crullers | 1,030 | 142 | 157 | $5.4B/s (Legendary) |
| 13 Pirate Cove | 1,130 | 154 | 168 | $33B/s (Legendary) |
| 14 Jelly Jungle | 1,220 | 165 | 180 | $196B/s (Celestial) |
| 15 Volcano Isle | 1,320 | 177 | 192 | $1.2T/s (Celestial) |
| 16 Cloud Bakery | 1,420 | 205 | 223 | $7T/s (Legendary) |
| 17 Toy Factory | 1,510 | 217 | 236 | $42T/s (Celestial) |
| 18 Haunted Donuttery | 1,610 | 230 | 248 | $254T/s (Celestial) |
| 19 Clockwork Void | 1,700 | 241 | 261 | $1.5Qa/s (Celestial) |
| 20 Donut Heaven | 1,790 | 253 | 273 | $9.1Qa/s (Celestial) |

The Speed numbers are much smaller than before the linear change. Existing saves were converted when a
player joins: their old Speed becomes whatever new Speed gives the same WalkSpeed, so nobody gets faster
or slower from the update. Treadmills give 0.3 → 1.3 Speed/s per tier, the Speed Multiplier gives +5%
per level, and each rebirth adds +35% treadmill speed.

Worlds 2 and 3 start with a long bridge so their first areas are just as far from safety as if the lane
kept going — without it, a player who just rebirthed (Speed 0) could steal World 2 donuts next to the
safe zone and skip the whole game.

Pacing, from a simulated bot that steals, upgrades and trains efficiently, buys **no** passes and has
**no pets or crates**:

| Milestone | Before the linear-speed update | Now |
|---|---|---|
| Area 2 | 4 min | 8 min |
| Area 5 | 25 min | 37 min |
| Area 10 (end of World 1) | 1.2 h | 1.5 h |
| Rebirth 1 → World 2 | 1.35 h | 1.7 h |
| Rebirth 2 → World 3 | 4.5 h | 4.8 h |
| Area 20 / Rebirth 3 | 9.4 h | 9.6 h |

The faster Domer makes each chase tighter but barely changes these totals (rebirth costs are the
bottleneck, not getting into areas). **Pets and crates are not in the simulation** and make things
faster for players who have good ones (up to +600% money and +300% treadmill speed from pets; crate
coins and Speed Boosts), so for many players the late game will be *quicker* than this. Knobs:
`Config.Pets.MaxMoneyBonus` / `MaxSpeedBonus`, crate rewards in `Crates.luau`, the rates in
`Config.Treadmill`, `Config.SpeedMultiplier`, `Config.Rebirth` and donut incomes. Real players usually
take 2–3x longer than the bot, and in Studio with every money pass (free test purchases) it's ~20x faster.

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
4. **Create the Developer Products** (Monetization → Developer Products): one for the Luck Event
   (suggested R$100), one per crate (R$50 / 150 / 300 / 800) and one per donation amount (R$10, 50,
   100, 500, 1,000). Paste the IDs into `Config.LuckEvent.DeveloperProductId`,
   `Config.Crates.Products[...].DeveloperProductId` and `Config.Donations.Products[...].DeveloperProductId`.
   Until then, pressing those buttons in a live game just says "coming soon". Every purchase is recorded on the
   player's save, so Roblox retrying a receipt never grants it twice.
5. **Crates are "paid random items"** under Roblox's rules. Tick that in the **Maturity & Compliance
   Questionnaire** on the Creator Dashboard. The game already does the rest: the odds are shown before
   buying, and players whose region doesn't allow paid random items (`PolicyService`) can't buy
   crates (they can still open the ones they find). If you change the odds, change them in
   `Crates.luau` — the shop reads them from there, so what players see is always what they get.
6. **Admin panel access.** The code works for the game's owner (for a group game: the group's owner)
   and in Studio. To let friends use it, put their UserIds in `Config.Admin.AllowedUserIds`.
   Don't turn on `AllowAnyone` in a live game: anyone who hears the code would get free money and
   free Luck Events. To change the code itself, edit `ADMIN_CODE` in `src/server/AdminService.luau`
   (it lives on the server on purpose: code in `src/shared` can be read by exploiters).
7. In Studio, clicking a pass or product grants it for that test session for free
   (`Config.Debug.StudioFreePurchases`) — this never happens in a live server and is never saved.
   **This is why testing in Studio feels much faster than a real player's game**: with every money pass
   you earn 20.5x. Turn it off (or don't click the passes) when you judge the pacing.
8. Want to test late-game areas? Set `Config.Debug.StudioStartMoney` / `StudioStartSpeed` (Studio only),
   or use the admin panel.
9. **Music:** there are no songs yet, so the Music switch has nothing to mute until you add some. Roblox can't play YouTube links. Upload audio you own (Creator Dashboard → Development
   Items → Audio) or pick licensed tracks from the Creator Store, then add `{ Name = ..., Id = ... }`
   entries to `Config.Music.Tracks`. Audio must be public or owned by the game's owner, otherwise it
   won't play (the Output window tells you which ID failed).

---

## Design decisions you should know about

These are all one-line changes in `src/shared/Config.luau` if you disagree.

* **Crates give one reward each**, picked by the odds on the card (the way you described Common and
  Legendary). Found crates use the same odds as bought ones. A crate's **Luck Event is server-wide**,
  because donuts in the lane are shared by everyone, so a personal luck boost couldn't make only your
  donuts better. The **Speed Boost** makes you run 20% faster, which *does* make Domer easier while it
  lasts; it only counts down while you're in the game, so a paid boost isn't wasted by leaving.
  Crate eggs and pets skip the incubator / pet limits so a paid reward is never lost.
* **The second floor uses lift pads, not stairs.** There's no room for a ramp inside the fence without
  cutting through the stands, and the pads sit exactly above each other, so riding them with a
  stolen donut doesn't trip the anti-teleport check.
* **The Luck Event is a developer product, not a game pass.** A game pass can only be bought once,
  ever, so it can't be a repeatable "10 minutes of luck". It boosts the **whole server** (like the
  big games do): the buyer gets a shout-out, everyone nearby benefits, and that's what sells it.
* **Raids no longer need the owner to be away.** The old rule ("only while the owner is outside
  their base") was a big reason raids felt broken — the owner was almost always standing at home.
  Now anyone can raid anytime, but the thief is slow, glowing red and the owner gets an alarm, and
  everyone gets the Slap Hand free, so defending is always possible. The Base Lock is the only hard
  block. If raids become too punishing, raise `Config.Raid.HoldSeconds` or lower `CarryWalkSpeed`.
* **Admin donuts can come from the admin panel too.** Players who used the panel are hidden from the
  global leaderboards and their finds don't count in the global "found" stats; donuts placed with the
  panel don't count as spawned or found for anyone. So the rarity numbers stay real.
* **Skins are bought with Speed, as you asked — but that gives up Robux income.** Skins were the
  cheapest way for a player to spend Robux. If you want both, a skin could cost Speed *or* Robux.
* **Only Secret donuts get the big server-wide banner.** Area events and your own rebirths show a small
  toast instead (events only to players who can reach that world).
* **Rebirths reset your base donuts**, like Steal a Brainrot. The multiplier is big (x2, x3, x4…) so
  the replay of World 1 goes a lot faster each time.
* **The guard is now called Domer (`Config.Guard.Name`).** That lowers the Homer Simpson (Disney/Fox IP)
  risk but doesn't remove it: "Domer", a bald guy in a white shirt and blue pants who loves donuts, is
  still obviously a parody of Homer. Parody isn't a safe harbour on Roblox — takedowns are decided on
  a DMCA claim, not in court. If the game takes off, consider changing his look too (hair, colours).
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

**Speed is linear:** WalkSpeed = 16 + Speed / 10 (capped at 220). 90 Speed = 25 WalkSpeed, 810 Speed =
97 WalkSpeed, and every treadmill session makes a visible difference. On top of that everyone is x1.2
faster in World 2 and x1.3 faster in World 3. Domer is always 5 (World 1), 7 (World 2) or 9 (World 3)
WalkSpeed faster than a player at the recommended speed, so you need a head start or to be over the
recommendation to escape with the donuts deep in an area.

| Area | Recommended Speed | Your WalkSpeed at that Speed | Domer WalkSpeed | Best donut (not counting Secrets) |
|---|---|---|---|---|
| 1 Glazed Meadow | any | 16 | 21 | $15/s (Rare) |
| 2 Sprinkle Park | 90 | 25 | 30 | $90/s (Rare) |
| 3 Sugar Dunes | 180 | 34 | 39 | $540/s (Epic) |
| 4 Frosting Falls | 270 | 43 | 48 | $3.2K/s (Epic) |
| 5 Chocolate Caverns | 360 | 52 | 57 | $19.5K/s (Legendary) |
| 6 Glacier Glaze | 450 | 61 | 66 | $117K/s (Legendary) |
| 7 Molten Bakery | 540 | 70 | 75 | $700K/s (Legendary) |
| 8 Neon Donut City | 630 | 79 | 84 | $4.2M/s (Legendary) |
| 9 Crystal Cosmos | 720 | 88 | 93 | $25M/s (Celestial) |
| 10 Celestial Donut Dimension | 810 | 97 | 102 | $150M/s (Celestial) |
| 11 Glaze Beach | 900 | 127 | 136 | $900M/s (Legendary) |
| 12 Coral Crullers | 990 | 138 | 146 | $5.4B/s (Legendary) |
| 13 Pirate Cove | 1,080 | 149 | 157 | $33B/s (Legendary) |
| 14 Jelly Jungle | 1,170 | 160 | 168 | $196B/s (Celestial) |
| 15 Volcano Isle | 1,260 | 170 | 179 | $1.2T/s (Celestial) |
| 16 Cloud Bakery | 1,350 | 196 | 208 | $7T/s (Legendary) |
| 17 Toy Factory | 1,440 | 208 | 220 | $42T/s (Celestial) |
| 18 Haunted Donuttery | 1,530 | 220 | 231 | $254T/s (Celestial) |
| 19 Clockwork Void | 1,620 | 231 | 243 | $1.5Qa/s (Celestial) |
| 20 Donut Heaven | 1,710 | 243 | 255 | $9.1Qa/s (Celestial) |

The Speed numbers are much smaller than before because the curve is linear now. Existing saves are
converted when a player joins: their old Speed becomes whatever new Speed gives the same WalkSpeed, so
nobody gets faster or slower from the update. Treadmills give less (0.3 → 1.3 Speed/s per tier), the
Speed Multiplier gives +5% per level, and each rebirth adds +35% treadmill speed (was +100%).

Worlds 2 and 3 start with a long bridge so their first areas are just as far from safety as if the lane
kept going — without it, a player who just rebirthed (Speed 0) could steal World 2 donuts next to the
safe zone and skip the whole game.

Pacing, from a simulated bot that steals, upgrades and trains efficiently, buys **no** passes and has
**no pets**:

| Milestone | Before this update | Now |
|---|---|---|
| Area 2 | 4 min | 8 min |
| Area 5 | 25 min | 37 min |
| Area 10 (end of World 1) | 1.2 h | 1.5 h |
| Rebirth 1 → World 2 | 1.35 h | 1.7 h |
| Rebirth 2 → World 3 | 4.5 h | 4.9 h |
| Area 20 / Rebirth 3 | 9.4 h | 9.7 h |

So the **early game is about twice as slow** and World 1 takes ~25% longer, but the full run is about
the same length as before. **Pets are not in that simulation** and make it faster for players who hatch
good ones (up to +600% money and +300% treadmill speed at the cap), so for many players the late game
will be *quicker* than before. Knobs: `Config.Pets.MaxMoneyBonus` / `MaxSpeedBonus`, the rates in
`Config.Treadmill`, `Config.SpeedMultiplier`, `Config.Rebirth` and donut incomes. Real players usually
take 2–3x longer than the bot, and in Studio with every money pass (free test purchases) it's ~20x faster.

The guard's speed and the area signs are derived from each area's `RecommendedSpeed` (+`GuardSpeedBonus`,
and the world's speed bonus), so if you rebalance speeds, the signs and the guards stay in sync.

---

## Editing the map by hand

The map is saved in the place file (`map/Map.model.json` in this repo), so it's visible in Studio's
edit mode. Move, restyle or replace anything and save. At runtime, if `Workspace.Map` exists the game
uses it as-is instead of building a new one.

Keep the names that the scripts look up: `Plots/PlotN` and `Worlds/WorldN/Plots/PlotN` (with
`Slots/SlotN`, `Spawn`, `SignAnchor`, `TreadmillAnchor`, `PodiumAnchor`, `IncubatorAnchor`), `Lane/AreaN` (with `Spawns/DonutSpawn`, `GuardHome`),
`Hub/ShopStall/PromptPart` + `Glow`, `Hub/Leaderboards/Board_X/Screen`, the portals (`Hub/Portals`,
`Worlds/WorldN/HomePortal`, each with a `Trigger` part) and `Worlds/WorldN/Arrival`.

If you had edited an older copy of the map: it's upgraded automatically when the game starts (missing
areas, worlds and portals are added, the donut stands are rebuilt at the front of each base, the world
hubs are rebuilt with base plots, and the text on the area arches and portals is refreshed from the
config). Heads-up: the upgrade **rebuilds `Worlds/`** (each world's landing hub) from scratch, so hand
edits in there are lost once; everything else you edited is kept.

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
* **New pet or egg:** add to `src/shared/Pets.luau` (pets pick a body `Shape` and `Features`; eggs list
  which pets they can hatch and the areas they appear in). Add new pets at the end of the list.

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

* Every script passes strict Luau type-checking against the Roblox API. The server was run end-to-end
  in a Roblox API emulator (steal → chase → caught → donut back at its spawn, raids with slow mode and
  alarm, owner hitting the thief, base moving between worlds, eggs → incubator → hatch → pets, luck
  event, donations and receipts, admin code, save migration, rebirth), including booting on the
  previous version of the place file to test the map upgrade. The client scripts were also booted in
  the emulator and every window and effect was run without errors.
* The crates (every reward kind, lane crates, purchases with receipts, the region block), favorites,
  the second floor (lift pads, a raid upstairs carried down the lift, moving worlds, kept on rebirth)
  and the music switch were run in the same emulator.
* **Not verified:** anything visual or physical. An emulator can't render, so the UI layout on a
  phone, the tool grips in the hand, Domer's size in the lane, egg/pet/crate looks, the second floor's
  look and the treadmill effects still need a look in Studio. The lag compensation assumes `Player:GetNetworkPing()` is the
  round-trip time; if catches feel off in live games, tune `Config.Guard.InterpolationDelay` /
  `MaxRewind`.
* Global "found/spawned" stats are updated every ~2–3 minutes (DataStore limits), so they lag a bit.
* Anti-cheat is basic (server-side reach checks, a speed check while carrying a donut, rate-limited
  remotes). Speed exploiters can still move faster when *not* carrying a donut.
* Common retention features not included yet: daily rewards, friend boosts, a trading system.
