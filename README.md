# 🍩 Steal a Donut

A brainrot-style Roblox game in the style of *Steal an Egg*: sneak down one long lane of increasingly
magical areas, grab donuts from under a sleeping (and HUGE) guard's nose, outrun him back to the safe
zone, and put the donuts on your base where they make money — even while you're offline. Then raid other
players' bases, hatch pet eggs, and chase the ultra-rare Secret and Icon donuts.

Everything (map, guards, donuts, UI) is built from code, so the project works without any uploaded
meshes, images or sounds.

---

## What's in the game

| Feature | Where it lives |
|---|---|
| **4 worlds, 33 areas.** World 1 *Donut Land* (grass → desert → candy → caves → ice → lava → neon city → crystals → cosmic → candy-cane canyon → rainbow summit), World 2 *Glaze Islands* (beach → coral reef → pirate cove → jelly jungle → volcano → mango lagoon → tsunami temple), World 3 *Dream Dimension* (clouds → toy factory → haunted bakery → clockwork void → donut heaven → starfall garden → aurora palace) and the new World 4 **Cyber City** (neon streets → hologram mall → robot factory → data highway → firewall fortress → glitch zone → the mainframe). Worlds 2–4 are reached through portals in the hub, need 1 / 2 / 3 rebirths, and everyone moves faster there (x1.2 / x1.3 / x1.45) | `src/shared/Areas.luau`, `src/server/MapBuilder.luau`, `src/server/Decor.luau` |
| **Scenery in the other worlds**: Glaze Islands gets palm trees, beach umbrellas, a lighthouse, and floating islands and clouds along the whole lane; Dream Dimension gets cotton-candy trees, pastel clouds at every height, floating islands with waterfalls and rainbows, giant floating donuts, star rings and a crescent moon; Cyber City gets a neon skyline, flying cars, holo donuts and neon signs. Each world has its own sky colour and fog. All cosmetic (no collisions) | `src/server/WorldDecor.luau`, `src/client/Effects.luau` |
| **Your base comes with you.** Every world has its own hub with 8 base plots; when you go to another world your base (donuts, treadmill, traps, incubator) moves to your plot there, so you never run back and forth. The 🏠 portal takes you home to World 1 | `src/server/PlotService.luau` (`MoveBase`), `src/server/WorldService.luau`, `Layout.PlotCFrame(plot, world)` |
| **182 brainrot donuts**, 8 rarities (Common → Uncommon → Rare → Epic → Legendary → Celestial → Secret → **ADMIN**). Each area's best donut is a ~1% spawn; Secrets are 0.006–0.03%. The **Admin** donuts (end of each world: areas 12, 19, 26, 33, plus World 2's Cosmic copy) **never spawn by themselves**: only the admin panel can make one (`AdminOnly` in `Rarities.luau`; lane spawns, Luck Events and Rare Donut Rain all skip them, and the Index shows "Admin panel only"). They get a red beam, halo and orbiting orbs. Rarer donuts get more effects: sparkles, lights, floating, light pillars, a glowing ring on the ground, orbiting orbs, halos, rainbow frosting, a shimmering aura | `src/shared/Donuts.luau`, `src/shared/Rarities.luau`, `src/shared/DonutModel.luau` |
| **Mutations** rolled on every spawn: Gold x2 (0.6%), Diamond x3 (0.25%), Mythic x5 (0.08%), Divine x10 (0.02%), Rainbow x25 (0.006%), each with its own look. **Eternal** x50 never rolls: only the Eternal Storm's purple lightning gives it. The best two donuts of every area also spawn less often than their listed weights (4% → 3%, 1% → 0.6%) | `Rarities.Mutations`, `Donuts.luau` (`RARER`) |
| **Global rarity stats**: the Index shows, for every Legendary-or-rarer donut and every mutation, how many have *spawned* and been *found* across the whole game so far (all servers), plus "#N ever found" in the steal announcement | `src/server/StatsService.luau` (sharded DataStore counters), `Config.GlobalStats` |
| **Sizes**: Small x0.6, Normal, Big x1.8, Huge x3.5, Giant x7. Bigger = more money, but you run 5% / 10% / 16% slower while carrying it | `Rarities.Sizes` |
| **Your own Domer — and he's HUGE** (4x size), and 7.5% faster than his base speed (`Config.Guard.SpeedMultiplier`). Every player has their own sleeping guard on every blanket (drawn by your client) and only ever sees their own. **Asleep** he lies on his back on a pillow (one arm flung over his head, the other hand on his hip, legs flopped apart, a wide-brimmed hat put down beside him), eyes shut, mouth open: every breath out puffs Z's out of his mouth, and within ~85 studs you hear him snore (a rattling breath in, a soft breath out, made from Roblox's own sounds or `Config.Guard.SnoreSoundId`). Steal a donut → yours wakes up with an angry grunt (`Config.Guard.GruntSoundId`), yelling, and chases you. You hear his footsteps when he's within ~110 studs and the screen shakes harder the closer he gets (from 45 studs); the red edge glow pulses faster too | `src/server/GuardService.luau`, `src/client/Guards.luau`, `src/client/UI/Chase.luau`, `src/shared/GuardModel.luau` |
| **He catches you at 10 studs — really 10.** The catch is lag-compensated: the server checks the distance between where *you* were and where he was *as your screen showed him* (rewound by your ping), so a fast runner with lag no longer gets caught from 40 studs away | `GuardService.PerceivedDistance`, `Config.Guard.CatchRadius` |
| Reach the safe zone and he gives up; walk into your base to place the donut. **Get caught or hit while carrying a donut → it goes back to the exact spot it spawned** (anyone can steal it again), and you get flung home | `src/server/StealService.luau`, `DonutSpawnService.Return` |
| **Server events**, one at a time, for the **whole server** (every area in every world): the first ~90 s after the server starts, then every 3–5 minutes, each lasting 2½ minutes. 15 **luck events** (Golden Hour, Sandstorm, Blizzard, Eruption, Glitch Storm, Meteor Shower, Blood Moon, Divine Light, Rainbow Rush…) with weather and boosted rare-donut / mutation luck everywhere (every area re-rolls when one starts); **☄️ Rare Donut Rain** (every 12 s one rare donut crashes down, one at a time, in an area someone in the server can actually reach); **🥚 Egg Shower** (eggs keep appearing in every egg area); **⏩ 2x Incubator Speed** (everyone's eggs hatch twice as fast) | `src/shared/Events.luau`, `src/server/EventService.luau`, `src/client/Weather.luau`, `Config.Events` |
| **🌌 Eternal Storm**, the rarest event (weight 0.6 of ~125, so about 1 event in 200; the owner can start it any time from the admin panel's 👑 button, nobody else can): a giant black hole hangs over every world, the screen turns a stormy purple, huge grassy rocks crash down near players in the lanes (a purple circle shows where; whoever's in it is flung, and a carried donut goes back), and purple lightning strikes lane donuts all over the game every 7–12 s: each one it hits becomes **Eternal** (x50, purple glow, a storm of purple lightning, shards and smoke). Plays the **Radetzky March**: paste the Toolbox recording's id into `Config.EternalStorm.MusicId`, otherwise a built-in version made from Roblox's own sounds plays | `EventService` (eternalStorm), `src/client/StormFX.luau`, `src/client/UI/StormMusic.luau`, `Config.EternalStorm` |
| **Big event announcement**: when an event starts, a large card drops in at the top of everyone's screen (the event's colour, a huge icon, its name, what it does and a countdown) with a little fanfare, pulses for ~7 s, then shrinks into a pill with the time left. Players who join mid-event get the pill | `src/client/UI/EventBanner.luau` |
| **Rebirths**: reset Money, Speed, treadmill, Speed Multiplier and your base donuts for x2, x3, x4… money AND speed forever, and unlock the next world. Keeps passes, items, skins, base expansions and Index rewards | `Config.Rebirth`, `ShopService` (`Rebirth` action), `src/client/UI/Rebirth.luau` |
| **Donut Index with rewards**: claim cash for every donut you've found; Epic+ donuts let you pick a permanent treadmill speed bonus instead (+1% / +3% / +8% / +20%). Shows which mutations you've found | `src/client/UI/Index.luau`, `Rarities.List[].IndexReward` |
| **Effects**: early donuts (Common–Epic, Gold, Diamond) stay plain and clean; from Legendary up they get wild, like the big Steal games: Legendary *Radiance* (golden flames, embers, sun rays), Celestial *Starlight* (spirals, crystal shards, stars, magic circle, comets), Secret *Void* (dark purple shards and smoke, white electric bursts, lightning arcs, galaxy dough), Admin *Overload* (red flames, black smoke, crimson shards, red lightning), Icon *Nova* (huge electric bursts, blue shards, strikes from the sky); mutations add *Hellfire* (Mythic), *Holy* (Divine), *Prism* (Rainbow) and *Eternal* (purple lightning storm). The flames / spirals / smoke run near full strength but only on the ~14 donuts closest to you (off on the rest, for phones); shards and electric bursts are drawn by each client. Textures are Roblox's own; `Config.DonutFX.Textures` takes Creator Store ones | `src/shared/FXThemes.luau`, `src/shared/DonutModel.luau`, `src/client/DonutFX.luau`, `src/client/ParticleBudget.luau` |
| **Idle animations** for the donuts on every base: each has a personality (bouncing, swaying, dancing, looking around, or hovering if it floats), does a twirl / jump / wave / wiggle every few seconds, and blinks. Propellers spin, orbs orbit, tentacles wiggle, capes flutter. All client-side, only near the camera | `src/client/DonutIdle.luau` (limbs are marked in `DonutModel.luau`) |
| Money per second from every donut at your base; upgrades are cheap (+25% for 20 s of income, x1.3 per level) | `src/server/PlotService.luau`, `Config.DonutUpgrade` |
| **Open bases** (like Steal an Egg): 6 bases a server, each an open pen with a low fence you can hop and a gate at the front. Every donut has its own 16-stud patch and **roams** it: stands around (idle animations), turns, walks somewhere else. Where each donut is comes from `Roam.luau` + the shared server clock, so every player sees it in the same place and the server checks thieves against where it really is | `src/shared/Roam.luau`, `PlotService`, `src/client/DonutIdle.luau`, `Layout.PenGrid` |
| **Bigger bases**: the Shop's 🏢 BIGGER BASE card grows your pen: 8 → 12 → 16 → 20 → 24 → 36 → 48 → 60 → 72 donuts (same prices as the old expansions and floors). Old saves get a pen that holds at least as many donuts as they had stands. Kept through rebirths | `Config.Plots.Sizes`, `PlotService.BuySize` |
| **Base sign**: the owner's avatar in a black ring, their name and income float over the back of their pen | `PlotService` (refreshSign) |
| Offline / AFK earnings with a "Welcome back" popup (capped at 12h) | `src/server/PlayerService.luau` |
| **Speed is linear and has no maximum**: every 10 Speed = +1 WalkSpeed (16 + Speed/10, no cap any more), so every bit of training is felt. **Speed slider** on the HUD (replaces Slow Mode): drag it to run anywhere from normal walking speed (16) up to your full speed; it's saved. Treadmill next to every base: 15 tiers (the last ones need rebirths), locked onto the belt while running. Effects: chasing LED strips, a spinning fan, sparks and dust from the belt, a glowing aura on high tiers, camera FOV kick, speed lines, a trail and "+N WALK SPEED!" bursts | `Economy.WalkSpeedFromStat`, `src/server/TreadmillService.luau`, `src/client/Treadmill.luau` |
| Shop: Speed Multiplier (+5% per level, 20 levels), Treadmill, Base Expansion (money); 1.5x–10x Money, 2x Speed and **Teleporter** passes (Robux); the **Luck Event** (Robux); base skins (paid with **Speed**) | `src/server/ShopService.luau`, `src/client/UI/Shop.luau` |
| **Luck Event** (developer product, suggested R$100): 10 minutes of better donuts for **the whole server** — rare donuts x3, mutations x3, Big/Huge/Giant x2, better eggs. Buying again adds 10 more minutes. A timer pill shows on everyone's screen with the buyer's name | `src/server/LuckService.luau`, `src/server/ProductService.luau`, `Config.LuckEvent` |
| **Pet eggs**: from area 4 on, eggs appear on the lane now and then (8 kinds; the rarer the egg, the deeper it spawns and the crazier it looks — rune rings, orbiting stars, light pillars, god rays, a Void egg with a swirling vortex). Carry one home like a donut; it goes into your base's incubator and hatches on a timer (3 min for a Sprinkle Egg … 90 min for a Void Egg) with a hatch animation. Cyber City has its own **Cyber Egg** (Pixel Pup, Drone Bird, Mecha Cat, Neon Overlord). **31 pets** from the lane eggs give money and treadmill-speed bonuses; rarer eggs → better pets. Equip 3; bonuses are capped at +600% money / +300% speed. Pets are kept through rebirths. Crate exclusives: the **Royal Egg** (4 pets you can't get anywhere else) and the **Crate King** pet | `src/shared/Pets.luau`, `src/shared/PetModel.luau`, `src/server/PetService.luau`, `src/client/UI/PetsWindow.luau`, `src/client/PetFX.luau` |
| **Incubator upgrades** (Shop → Upgrades, money): **Hatch Speed** +25% per level (8 levels, up to x3) and **Egg Capacity** +1 egg per level (6 levels, 6 → 12 eggs). Buying hatch speed also speeds up the eggs already in the incubator. Kept through rebirths | `PetService.BuyUpgrade`, `Config.Pets.IncubatorSpeed` / `IncubatorSize`, `src/client/UI/Shop.luau` |
| **Favorite donut**: press **R** on one of your own donuts (❤ Favorite) and a copy at **1/3 of its size** follows you around, with its mutation look. The real one stays on its stand and keeps earning; if it's sold, stolen or reset by a rebirth, the follower goes away. (Replaces the old Index "Buddy") | `PlotService.FavoriteSlot`, `src/client/Followers.luau`, `Config.Favorite` |
| **Crates**: Common / Rare / Epic / Legendary. They show up now and then in the lane (hold E to open, no chase; mostly Common, Legendary is ~1 in 200) or can be bought in the shop's **🎁 Crates** tab for R$50 / 150 / 300 / 800 (developer products). Each gives ONE reward: coins (scaled to how far your Speed gets you), a 10-minute Speed Boost (run 20% faster, counts down only while you play), a 10-minute server-wide Luck Event, an egg (straight into your incubator), or for Legendary the exclusive Royal Egg or Crate King pet. Every outcome and its exact % is on the card, with an "All odds" page that also lists every pet inside the eggs. An opening animation plays for each crate | `src/shared/Crates.luau`, `src/shared/CrateModel.luau`, `src/server/CrateService.luau`, `src/client/UI/CrateOpen.luau`, `Config.Crates` |
| **Donations**: R$10 / 50 / 100 / 500 / 1,000 buttons (developer products) and a **TOP DONATORS** board. Flightly33 is pinned at the top with R$100T, with "-10 Robux donated" under the name (a joke row: shown to everyone, never saved, not counted) | `src/client/UI/Donate.luau`, `ProductService`, `Config.Donations` |
| **Admin panel**: type `ender=cool` in chat (the message is hidden from everyone else) to open a cheat panel: money, speed, max treadmill, rebirth, any donut with any mutation/size, spawn donuts, eggs, hatch all, pets, "Domer can't catch me", teleport, and **🕊 Fly** / **🧞 Magic carpet** (WASD + camera to steer, Space / Shift to go up and down, on-screen ⬆⬇ buttons on phones). **Anyone** who types the code gets the panel (`Config.Admin.AllowAnyone = true`, as asked). The 👑 buttons only work for the owner: Luck Event, crates and starting server events (see *Design decisions*). Anyone who used the panel is left off the global leaderboards. **Owner only** (👑, hidden from everyone else): **bigger / max / smaller base** past the biggest you can buy (up to `Config.Admin.MaxSlots` = 100 donuts, as big as a pen fits on its plot), the **🌌 Eternal Storm**, and the **👑 Owner's Throne** base skin (purple marble, gold posts, a red carpet and a giant floating crown; also in the owner's Shop) | `src/server/AdminService.luau`, `src/client/UI/Admin.luau`, `src/client/Flight.luau`, `Config.Admin` |
| **Base code**: type `ender=rich` in chat (hidden from everyone else, like the admin code) to get **only** the base-size buttons: a 🏢 BASE button on the HUD and a small window with **BIGGER**, **SMALLER** and **MAX SIZE** (nothing else from the admin panel), for this session. Anyone can use it (`Config.Admin.AllowAnyone`), except players the owner took admin away from. It goes up to `Config.Admin.MaxSlots` = 100 donuts, not infinite: the pen has to fit on its plot and every roaming donut is ~100 parts every player's device moves. Making a base smaller never deletes a donut: ones that don't fit are kept and come back when it's big enough | `src/server/AdminService.luau`, `src/client/UI/BaseSize.luau`, `PlotService.RefreshPen` |
| **Teleporter pass**: jump to any unlocked world or the start of any area you're fast enough for (the 🌀 TELEPORT square on the HUD) | `src/client/UI/Worlds.luau`, `WorldService` |
| Five top-500 leaderboards next to the shop (Money earned, best Speed, Rarest donut incl. mutation, Time Played, Top Donators). There's no leaderboard button on the HUD any more; the boards in the hub are scrollable | `src/server/LeaderboardService.luau`, `src/client/UI/Leaderboards.luau` |
| Podium outside each base showing the owner's rarest **or** top-earning donut | `src/server/PlotService.luau` |
| **Base raids** (like Steal a Brainrot): hold "Steal" for 2.5 s on another player's donut. The donut goes above the thief's head and the thief is put in **slow mode** (WalkSpeed 16). The owner hears an **alarm**, sees the thief outlined in red and gets a warning the moment someone starts stealing. The thief has to reach **their own base** before the owner (or anyone) hits them — one hit and the donut flies back to the owner's stand. Only an active **Base Lock** stops raids | `src/server/RaidService.luau`, `StealService.StartRaid`, `src/client/UI/Chase.luau` |
| **Item shop**: Slap Hand (free for everyone, so every owner can defend), Donut Bat, Mega Hammer, Banana Peel, Launch Pad, Base Lock. New 3D models held properly in the hand, and a spinning 3D preview in the shop | `src/shared/ItemModel.luau`, `src/server/ItemService.luau`, `Config.Items` |
| **Cleaner UI**: everything is ~18% smaller (`Theme.UIScale`), buttons grouped on the left and right edges, notifications stacked so they don't cover each other | `src/client/UI/HUD.luau`, `src/client/UI/Theme.luau` |
| **Every donut is unique**: besides its classic accessories, each donut has signature details that match its name (Tick Tock Glazock's clock face and bells, Volcanito's volcano, Wifinut's wifi arcs, Banhammer's giant BAN hammer, Lava Crabbo's claws, MissingDonut's missing-texture checkerboard, ~150 in all) and touches from its home area (lava cracks in The Underworld, circuit traces in Cyber City, icicles in Glacier Glaze, star specks in space, slime in the Haunted Donuttery...). Dough is baked darker underneath and the glaze has a soft shine. Tails wag, flags and flames sway, clock hands and wind-up keys turn. Nine pets got matching details too (drone rotors, jester hat, tiki mask...) | `src/shared/DonutExtras.luau`, `Donuts.luau` (Parts), `PetModel.luau` |
| **Lane donuts come alive** when you're near: little hops on the spot, blinking, looking around and at you, and a wave or a hop to say hi when you walk up (the gentle "Lane" style of the base donuts' idle animations; floating rare ones keep bobbing and spinning) | `src/client/DonutIdle.luau`, `DonutSpawnService` (LaneDonut tag) |
| **Performance**: each player's screen only draws what's near: lane areas' decorations, donuts and crates further than ~600 studs, bases further than ~520 studs and other worlds' scenery are hidden locally and come back as you get close (floors and walls always stay); far base donuts skip their tiny parts; donuts behind the camera don't animate, and further lane donuts move 30 / 15 times a second. Hiding and showing an area is spread over a few frames (no stutter as you run down the lane). ShadowMap lighting instead of Future, half as many shadow-casting parts, decoration particles capped, and empty lane areas stop re-rolling donuts (less to download). **Grabbing a donut is instant on phones**: the server no longer builds and welds a ~110-part donut onto the thief (that was sent to every player and made the first second of a steal stutter). It just sets `CarryingDonut` / `CarryKind` / `CarryMutation` / `CarrySize`, and each client draws the donut (or egg) in the carrier's arms itself; yours is already built while you hold Steal, and other players' only while they're near you. The chase screen only updates its text when the numbers change, Domer's footsteps reuse 3 sounds, his animations and the chase music are loaded when the game starts | `src/client/Culling.luau`, `src/client/Carried.luau`, `src/client/Effects.luau`, `src/client/DonutIdle.luau`, `src/client/UI/Chase.luau`, `MapBuilder` (optimize), `DonutSpawnService`, `default.project.json` |
| **Chase music**: a soft heartbeat that speeds up (96 → 138 bpm), a low drone, a quiet boom every two bars and a faint creepy note, through an EQ that takes the edge off the highs and a compressor, no louder than the normal music (it used to be 2.2x the music volume with a big bass boost). Domer's footsteps are quieter too. Paste a Creator Store track into `Config.Music.Chase` to use your own | `src/client/UI/ChaseMusic.luau`, `Config.Music` |
| **Update Log** on every join, for everyone (a brand-new player's tutorial starts once they close it); the 📰 UPDATES button on the side opens it any time. Each update is themed: a 3D donut emblem in the update's frosting on a turning wheel of sprinkles, a glowing border, a ribbon tab, and floating decorations (golden diamonds, rising embers, twinkling stars with shooting stars, or soft bubbles). New donuts, pets and eggs are spinning 3D cards: **hover one** (tap on phones) for a details card with its rarity, money / chance / area, a description and how to get it. Add an update at the top of `UpdateNotes.List` | `src/shared/UpdateNotes.luau`, `src/client/UI/UpdateNotes.luau`, `UpdateDecor.luau`, `ItemCard.luau` |
| **Graphics ("shaders")** in the bright Steal an Egg style: strong sun with soft shadows, bright shade, very vivid colours, a gentle glow on neon and fire, a light blue haze far away and Roblox's 3D clouds (hidden at night and in foggy areas). No per-frame scripts: it's all Lighting settings plus a colour-correction and bloom effect; there's no sun-rays pass (it cost a full-screen pass for little). Every knob is in `Config.Graphics`; each area's own mood is in `Areas.luau` | `src/server/MapBuilder.luau` (setupLighting), `src/client/Effects.luau`, `Config.Graphics` |
| **Loading screen** while the game loads in: a dark stage with spotlights, the logo (a masked donut in front of a turning wheel of sprinkles), "Loading... 42%", nine rarity-coloured donuts that light up as the map, your save and the downloads arrive, and rotating tips. **SKIP** closes it any time; it stays at least 2.5 s and at most 45 s. The Update Log waits until it's gone. Upload `branding/logo.png` and paste its id into `LOGO_IMAGE` to show the real logo picture | `src/first/LoadingScreen/` (ReplicatedFirst) |
| **Hide UI**: the 👁 HIDE UI button on the side (or **X** on a keyboard) clears the screen for screenshots and videos: every game window, the HUD, notifications and Roblox's chat / player list / hotbar. Steal prompts stay so you can keep playing. Press X again or tap the small 👁 SHOW UI pill (it fades away after 3 s on PC) and everything comes back exactly as it was; X typed in chat does nothing | `src/client/UI/HideUI.luau` |
| **UI sounds**: every button clicks like a soft mechanical keyboard (a muffled key-down "thock" and a lighter key-up), windows that pop up by themselves get a deeper thock, and messages chime softly, each kind with its own little tune (info, success, rare find, error, server announcement, event fanfare). Built from Roblox's own sounds with EQ/reverb, so nothing to upload; paste Creator Store sounds into `Config.Sounds` to use your own | `src/client/UI/Theme.luau`, `Config.Sounds` |
| **Music lives in ⚙️ Settings** (as asked): the separate HUD music button is gone; the Settings window has Music ON/OFF (also mutes the chase music), NEXT song and volume, all saved per player. The Settings square is always on the HUD | `src/client/UI/Settings.luau`, `src/client/UI/HUD.luau`, `Config.Music` |
| **No Worlds button** (as asked): players travel through the portals in the hub. The Worlds window is still there for **Teleporter** pass owners only, behind a 🌀 TELEPORT square that appears once they own the pass (otherwise the paid pass would have no way to be used) | `src/client/UI/HUD.luau`, `src/client/UI/Worlds.luau` |
| **Cartoon icons** on the HUD and the big buttons instead of emojis: a white body with a thick black outline, a drop shadow, top-to-bottom shading and shiny highlights (a pink heart, a red-nosed rocket, a blue eye...). Built from plain Frames in code (outline and shadow scale with the icon), so there's nothing to upload and they look the same on every device. Outlines always have rounded corners, pieces behind others (the wrench, the rocket's fins, the book's pages) get their own edge, and holes (the gear's middle, the ↻ arrow's ring) are painted with the button's own gradient so they really look see-through | `src/client/UI/Icons.luau` |
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

Note: the map saved in the place file is still your earlier map (with your own edits). When you press
Play it's upgraded automatically to map version 4: the whole **lane is rebuilt** (the areas were
renumbered: World 1 now has 12 areas, Worlds 2–3 have 7 each, and Cyber City adds 27–33), the world
hubs and the hub portals are rebuilt (now with a 4th portal, stacked next to the others), and the new
scenery is added. The rest of the hub (your edits there) is kept. So in **edit mode** you won't see the
new areas or Cyber City until you re-bake the map (see *Editing the map by hand*). The generated map has
about 41,000 parts (around 5,000 of them are the new scenery).

---

## Before you publish (checklist)

1. **Game Settings → Security → Enable Studio Access to API Services** (so saving and leaderboards
   work while you test). Without it the game still runs, it just doesn't save and shows a warning.
2. **Game Settings → Places → Max Players = 6.** There are 6 bases (`Config.Plots.Count`); a 7th player would be told the server is full.
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
6. **Admin panel access is ON for everyone** (`Config.Admin.AllowAnyone = true`, as you asked): any
   player who types `ender=cool` gets free money, speed, admin donuts and flying. Once the code gets
   out (and it will — someone will post it), your leaderboards and your Robux money passes lose most of
   their meaning, because anyone can skip the game. Set `AllowAnyone = false` before you launch
   publicly and put friends' UserIds in `Config.Admin.AllowedUserIds` instead. Either way the 👑 commands
   (Luck Event, crates, server events) only work for you. To change the code itself, edit `ADMIN_CODE`
   in `src/server/AdminService.luau` (it lives on the server on purpose: code in `src/shared` can be
   read by exploiters).
7. In Studio, clicking a pass or product grants it for that test session for free
   (`Config.Debug.StudioFreePurchases`) — this never happens in a live server and is never saved.
   **This is why testing in Studio feels much faster than a real player's game**: with every money pass
   you earn 20.5x. Turn it off (or don't click the passes) when you judge the pacing.
8. Want to test late-game areas? Set `Config.Debug.StudioStartMoney` / `StudioStartSpeed` (Studio only),
   or use the admin panel.
9. **Music (optional):** to add more songs, upload audio you own (Creator Dashboard → Development
   Items → Audio) or pick licensed tracks from the Creator Store, then add `{ Name = ..., Id = ... }`
   entries to `Config.Music.Tracks`; players switch songs, turn music off and change the volume in
   ⚙️ Settings. Roblox can't play YouTube links, and audio must be public or owned by the game's owner
   (the Output window tells you which ID failed).

---

## Design decisions you should know about

These are all one-line changes in `src/shared/Config.luau` if you disagree.

* **"Anyone can use the admin panel", but a few commands stay yours (👑).** The Luck Event, crates and
  starting server events only work for the owner: the first two are things you sell for Robux, and a
  server event changes the game for everyone in the server (one player could spam Rare Donut Rain).
  Everything else (money, speed, donuts, pets, flying, the magic carpet…) works for anyone. Edit
  `Config.Admin.OwnerOnlyCommands` to change the list.
* **"Run too fast → you drop your donut" is gone, but a teleport check stays.** Players can be as fast
  as they like while carrying a donut. The only thing left is: a single jump of more than 400 studs
  that's also far more than your speed allows (a teleport hack) still drops it. Without that, an
  exploiter could teleport home with every donut in the game. Legit players (even flying admins) never
  hit it.
* **No max walk speed means Roblox physics becomes the limit.** At WalkSpeed ~1,000+ a player can
  slip through thin walls or overshoot the safe zone in one frame. That's why the speed slider is
  there. The lane is wide open so it isn't a problem in practice, but it's why the old cap existed.
* **"Control speed" = the speed slider** on the HUD (from 16 up to your full speed), and it replaces the
  old Slow Mode switch. **"Rarer donuts one at a time" = the Rare Donut Rain event** (one rare donut at
  a time, every 12 s, in an area someone in the server can reach) plus **one event at a time** for the
  whole server. Tell me if you meant something else.
* **Events are server-wide now, not per area**, as asked. So a luck event boosts *every* area, which
  is a lot stronger than before; that's why they're one at a time with 3–5 minute breaks. They don't
  stack with each other, but they do stack with a bought Luck Event (so the paid one still feels good).
* **Crates give one reward each**, picked by the odds on the card (the way you described Common and
  Legendary). Found crates use the same odds as bought ones. A crate's **Luck Event is server-wide**,
  because donuts in the lane are shared by everyone, so a personal luck boost couldn't make only your
  donuts better. The **Speed Boost** makes you run 20% faster, which *does* make Domer easier while it
  lasts; it only counts down while you're in the game, so a paid boost isn't wasted by leaving.
  Crate eggs and pets skip the incubator / pet limits so a paid reward is never lost.
* **Floors are gone: bases grow outwards instead.** Roaming donuts don't fit a stack of floors, so
  the floors code (`ender=rich`) and the owner's 👑 buttons make the pen bigger or smaller instead.
* **Roaming is worked out, not sent.** Moving 72 donuts per base on the server would flood every
  player's connection, so the server only says *how* each donut roams (seed, patch, pen) and every
  device works out where it is from the shared clock. Donuts can walk through each other, like in
  Steal an Egg; they stay spread out because each one roams its own patch.
* **The Luck Event is a developer product, not a game pass.** A game pass can only be bought once,
  ever, so it can't be a repeatable "10 minutes of luck". It boosts the **whole server** (like the
  big games do): the buyer gets a shout-out, everyone nearby benefits, and that's what sells it.
* **Raids no longer need the owner to be away.** The old rule ("only while the owner is outside
  their base") was a big reason raids felt broken — the owner was almost always standing at home.
  Now anyone can raid anytime, but the thief is slow, glowing red and the owner gets an alarm, and
  everyone gets the Slap Hand free, so defending is always possible. The Base Lock is the only hard
  block. If raids become too punishing, raise `Config.Raid.HoldSeconds` or lower `CarryWalkSpeed`.
* **Admin donuts only come from the admin panel.** Players who used the panel are hidden from the
  global leaderboards and their finds don't count in the global "found" stats; donuts placed with the
  panel don't count as spawned or found for anyone. So the rarity numbers stay real.
* **Skins are bought with Speed, as you asked — but that gives up Robux income.** Skins were the
  cheapest way for a player to spend Robux. If you want both, a skin could cost Speed *or* Robux.
* **Only Secret donuts (and server events) get a big banner.** Your own rebirths and Rare Donut Rain
  drops show a small toast (Rare Donut Rain only to players who can reach that world).
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

**Speed is linear and uncapped:** WalkSpeed = 24 + Speed / 10 (Domer is tuned from 21, so you start 3 ahead of his base). 90 Speed = 33 WalkSpeed, 810 Speed = 105
WalkSpeed, and every treadmill session makes a visible difference. On top of that everyone is x1.2
faster in World 2, x1.3 in World 3 and x1.45 in Cyber City. (The old ~286 limit was the 220 WalkSpeed
cap times World 3's x1.3; there's no cap now.)

**Domer is 7.5% faster** than his base speed (`Config.Guard.SpeedMultiplier = 1.075`), and the
**Recommended Speed is worked out from the chase itself** (`Economy.RecommendedSpeed`): the Speed that
gets you home with at least the front half of an area's donuts (the ones deep in the area, near
Domer's blanket, need more). The signs, the HUD, the teleporter, events and crate coins all use it.

| Area | Recommended Speed | Your WalkSpeed at that Speed | Domer WalkSpeed | Best donut (not counting Secrets) |
|---|---|---|---|---|
| 1 Glazed Meadow | any | 24 | 27 | $15/s (Rare) |
| 2 Sprinkle Park | 90 | 33 | 37 | $90/s (Rare) |
| 3 Sugar Dunes | 180 | 42 | 47 | $540/s (Epic) |
| 4 Frosting Falls | 270 | 51 | 56 | $3.2K/s (Epic) |
| 5 Chocolate Caverns | 360 | 60 | 66 | $19.5K/s (Legendary) |
| 6 Glacier Glaze | 450 | 69 | 76 | $117K/s (Legendary) |
| 7 Molten Bakery | 540 | 78 | 86 | $700K/s (Legendary) |
| 8 Neon Donut City | 630 | 87 | 95 | $4.2M/s (Legendary) |
| 9 Crystal Cosmos | 730 | 97 | 105 | $25M/s (Celestial) |
| 10 Celestial Donut Dimension | 820 | 106 | 115 | $150M/s (Celestial) |
| 11 Candy Cane Canyon | 920 | 116 | 124 | $900M/s (Legendary) |
| 12 Rainbow Sprinkle Summit | 1K | 125 | 134 | $5.4B/s (Legendary) |
| 13 Ember Gates | 1.1K | 162 | 175 | $32.4B/s (Legendary) |
| 14 Brimstone Bakery | 1.2K | 174 | 187 | $194B/s (Legendary) |
| 15 Magma Rivers | 1.3K | 184 | 198 | $1.1T/s (Legendary) |
| 16 Soul Caverns | 1.4K | 196 | 210 | $7T/s (Celestial) |
| 17 Obsidian Forge | 1.5K | 208 | 221 | $42.4T/s (Celestial) |
| 18 Inferno Spires | 1.5K | 219 | 233 | $255T/s (Celestial) |
| 19 The Molten Core | 1.6K | 231 | 245 | $1.5Qa/s (Celestial) |
| 20 Cloud Bakery | 1.7K | 263 | 280 | $9Qa/s (Legendary) |
| 21 Toy Factory | 1.8K | 276 | 293 | $54.4Qa/s (Celestial) |
| 22 Haunted Donuttery | 1.9K | 288 | 306 | $329Qa/s (Celestial) |
| 23 Clockwork Void | 2K | 301 | 318 | $1.9Qi/s (Celestial) |
| 24 Donut Heaven | 2.1K | 313 | 331 | $11.7Qi/s (Celestial) |
| 25 Starfall Garden | 2.2K | 326 | 343 | $70.8Qi/s (Celestial) |
| 26 Aurora Palace | 2.3K | 338 | 356 | $425Qi/s (Celestial) |
| 27 Neon Streets | 2.4K | 391 | 414 | $2.5Sx/s (Legendary) |
| 28 Hologram Mall | 2.5K | 406 | 428 | $15.3Sx/s (Celestial) |
| 29 Robot Factory | 2.6K | 420 | 442 | $91.6Sx/s (Celestial) |
| 30 Data Highway | 2.7K | 433 | 456 | $550Sx/s (Celestial) |
| 31 Firewall Fortress | 2.8K | 448 | 470 | $3.3Sp/s (Celestial) |
| 32 Glitch Zone | 2.9K | 461 | 484 | $19.8Sp/s (Celestial) |
| 33 The Mainframe | 3K | 475 | 498 | $119Sp/s (Celestial) |

Rebirths need **400 / 700 / 1,000 / 1,300 Speed** and **$5M / $200B / $20Qa / $2Sx**, and there's **no limit**: after that every rebirth needs +50 Speed and costs 5x more (`Config.Rebirth.After`). Each rebirth
adds +100% money and **+50% treadmill speed**. Treadmills give **0.1 → 0.6 Speed/s** across the 17
tiers, the Speed Multiplier gives +5% per level.

**Head Start:** treadmill gains are **x4 at Speed 0**, fading evenly to x1 at Speed 450 (Area 6)
(`Config.Treadmill.HeadStart`). New players reach Area 2 in about 4 minutes of running on the free
treadmill instead of 15, and it kicks in again after every rebirth (Speed goes back to 0), so the
climb back is quicker too. The treadmill's screen and the Shop show the current boost (🚀 x3.2).

Worlds 2–4 start with a long bridge so their first areas are just as far from safety as if the lane
kept going — without it, a player who just rebirthed (Speed 0) could steal the next world's donuts
next to the safe zone and skip the whole game.

### Pacing

From a simulated bot that steals, upgrades and trains efficiently, buys **no** passes and has **no
pets, crates or Index bonus** (median of 5 runs). The bot fills its base before it trains, so a
player who hops on the treadmill straight away gets there sooner:

| Milestone | Before the Head Start | Now (Head Start, easier rebirths, longer lanes) |
|---|---|---|
| Area 2 | 16 min | 7 min |
| Area 3 | 30 min | 12 min |
| Area 5 | 54 min | 29 min |
| Area 10 | 2.7 h | 1.9 h |
| Rebirth 1 → World 2 | 1.3 h | 37 min |
| Rebirth 2 → World 3 | 3.1 h | 2.0 h |
| Rebirth 3 → Cyber City | 5.9 h | 4.6 h |
| Rebirth 4 | 10.6 h | 9.2 h |

In the late game, walking to the far areas and back takes most of the time, not training. The knobs
are the Head Start (`Config.Treadmill.HeadStart`), the rebirth requirements (`Config.Rebirth.Levels`)
and the donut incomes.

Things the simulation leaves out, which make it **faster** for real players who have them: pets (up to
+600% money and +300% treadmill speed), Index speed bonuses (up to +150%), crate coins and Speed
Boosts, the 2x Speed pass and money passes, and Luck/Rare Donut Rain events. Things that make it
**slower**: breaks, getting caught, raids, and not playing optimally. Real players usually take 2–3x
longer than the bot. In Studio with every money pass (free test purchases) it's ~20x faster.

The guard's speed and the area signs are derived from each area's `RecommendedSpeed` (+`GuardSpeedBonus`,
and the world's speed bonus), so if you rebalance speeds, the signs and the guards stay in sync.

---

## Editing the map by hand

The map is saved in the place file (`map/Map.model.json` in this repo), so it's visible in Studio's
edit mode. Move, restyle or replace anything and save. At runtime, if `Workspace.Map` exists the game
uses it as-is instead of building a new one.

Keep the names that the scripts look up: `Plots/PlotN` and `Worlds/WorldN/Plots/PlotN` (with
`Pen` (rebuilt by the game), `Spawn`, `SignAnchor`, `TreadmillAnchor`, `PodiumAnchor`, `IncubatorAnchor`), `Lane/AreaN` (with `Spawns/DonutSpawn`, `GuardHome`),
`Hub/ShopStall/PromptPart` + `Glow`, `Hub/Leaderboards/Board_X/Screen`, the portals (`Hub/Portals`,
`Worlds/WorldN/HomePortal`, each with a `Trigger` part) and `Worlds/WorldN/Arrival`.

If you had edited an older copy of the map: maps saved before version 11 are **rebuilt from scratch**
when the game starts (bases became open pens and there are 6 of them, every hub got bigger, and every
area got longer and wider, so nothing of an older map fits any more). Hand edits to an older map are
lost once; edits to a version 11 map are kept.

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
* **New event:** add an entry to `src/shared/Events.luau` (its kind — `Luck`, `RareRain`, `EggShower` or
  `DoubleHatch` — how often it's picked, its luck, weather, colours and the text on the big banner).
* **New area:** add an entry to `src/shared/Areas.luau` with its `World` and `Index` (theme = one of the
  existing decor themes or a new function in `Decor.luau`), and give it donuts. Adding areas in the
  middle of a world renumbers the ones after it: bump `MAP_VERSION` in `MapBuilder.luau` so saved maps
  rebuild their lane.
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
  open pens (every size, roaming donuts staying inside the fence, client and server agreeing where a
  donut is, a raid on a walking donut, moving worlds, shrinking without losing donuts), the Eternal
  Storm (black holes, falling rocks flinging you, lightning making lane donuts Eternal, owner-only),
  and this update's server events (every kind, one at a time, the big banner shrinking into the pill),
  Rare Donut Rain, Egg Shower, 2x Incubator, incubator upgrades, the speed slider, carrying a donut at
  very high speed without dropping it, the admin panel for non-owners (👑 commands refused), flying
  and the magic carpet, Cyber City and the v4 map upgrade on your previous place file were run in the
  same emulator.
* **Not verified:** anything visual or physical. An emulator can't render, so the UI layout on a
  phone, the tool grips in the hand, Domer's size in the lane, egg/pet/crate looks, how the new donut
  effects and the storm really look with Roblox's own particle textures, the Radetzky March tune
  (written out from memory), and the treadmill effects still need a look in Studio. The lag compensation assumes `Player:GetNetworkPing()` is the
  round-trip time; if catches feel off in live games, tune `Config.Guard.InterpolationDelay` /
  `MaxRewind`.
* Global "found/spawned" stats are updated every ~2–3 minutes (DataStore limits), so they lag a bit.
* Anti-cheat is basic (server-side reach checks, a speed check while carrying a donut, rate-limited
  remotes). Speed exploiters can still move faster when *not* carrying a donut.
* Common retention features not included yet: daily rewards, friend boosts, a trading system.
