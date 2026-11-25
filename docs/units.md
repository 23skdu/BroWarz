# BroWarz — Units

Every unit has a large, detailed 48×48 pixel-art sprite (rendered below at 64×64) with a strictly uniform silhouette, structural shading, and weapon/chassis geometry across all four corporations (**AeroDyne Industries**, **FerroCore Heavy**, **Pelagic Systems**, and **Vanguard Robotics**), recolored solely by each corporation's primary color ramp.

## Allied Behavior

Unit behavior follows the active alliance graph from [`diplomacy.md`](diplomacy.md), queried through `GameManager.is_allied()`:

- **Shared sight:** allied teams reveal explored tiles and live contacts to each other; enemy buildings still stay hidden under fog until seen. Corvette sonar buoys likewise reveal submerged contacts to their owner and allies for 75 s.
- **No friendly fire:** auto-targeting, attack orders, orbital lasers and nuclear strikes skip allied units and structures. Capture and demolish orders reject allied buildings.
- **Repairs:** Sapperbots and other repair-capable workers mend allied units (`100 px`) and buildings (`110 px`) at `12 HP/s` (`18 HP/s` for the unified Sapperbot worker role).
- **AI:** skirmish/co-op/spectator AI treats allied teams as non-enemies when picking targets and evaluating threats.
- **Identity:** an allied team keeps its own corporation color, emblem and upgrades; co-op partners and spectator AI squads remain distinguishable even when they share a side.

## Infantry Robots

| Unit | AeroDyne | FerroCore | Pelagic | Vanguard | Role |
|---|---|---|---|---|---|
| Riflebot | ![Riflebot](thumbnails/riflebot_f0.png) | ![Riflebot](thumbnails/riflebot_f1.png) | ![Riflebot](thumbnails/riflebot_f2.png) | ![Riflebot](thumbnails/riflebot_f3.png) | Line infantry |
| Heavybot | ![Heavybot](thumbnails/heavybot_f0.png) | ![Heavybot](thumbnails/heavybot_f1.png) | ![Heavybot](thumbnails/heavybot_f2.png) | ![Heavybot](thumbnails/heavybot_f3.png) | Heavy infantry, crosses mountains |
| Sapperbot | ![Sapperbot](thumbnails/sapperbot_f0.png) | ![Sapperbot](thumbnails/sapperbot_f1.png) | ![Sapperbot](thumbnails/sapperbot_f2.png) | ![Sapperbot](thumbnails/sapperbot_f3.png) | Unified worker: demolition/breach, construction capture, and field repair (sapper/engineer/medic roles merged; `engineerbot`, `medicbot`, and `adv_engineerbot` are compatibility aliases) |
| Stealthbot | ![Stealthbot](thumbnails/stealthbot_f0.png) | ![Stealthbot](thumbnails/stealthbot_f1.png) | ![Stealthbot](thumbnails/stealthbot_f2.png) | ![Stealthbot](thumbnails/stealthbot_f3.png) | Cloaked recon/ambush |
| Sniperbot | ![Sniperbot](thumbnails/sniperbot_f0.png) | ![Sniperbot](thumbnails/sniperbot_f1.png) | ![Sniperbot](thumbnails/sniperbot_f2.png) | ![Sniperbot](thumbnails/sniperbot_f3.png) | Long-range precision |
| Rocketbot | ![Rocketbot](thumbnails/rocketbot_f0.png) | ![Rocketbot](thumbnails/rocketbot_f1.png) | ![Rocketbot](thumbnails/rocketbot_f2.png) | ![Rocketbot](thumbnails/rocketbot_f3.png) | Anti-armor infantry |

## Mechanized & Armor

| Unit | AeroDyne | FerroCore | Pelagic | Vanguard | Role |
|---|---|---|---|---|---|
| APC/IFV | ![APC](thumbnails/apc_f0.png) | ![APC](thumbnails/apc_f1.png) | ![APC](thumbnails/apc_f2.png) | ![APC](thumbnails/apc_f3.png) | Transport and light cannon |
| Light Mech | ![Light Mech](thumbnails/light_mech_f0.png) | ![Light Mech](thumbnails/light_mech_f1.png) | ![Light Mech](thumbnails/light_mech_f2.png) | ![Light Mech](thumbnails/light_mech_f3.png) | Fast skirmisher |
| Light Tank | ![Light Tank](thumbnails/light_tank_f0.png) | ![Light Tank](thumbnails/light_tank_f1.png) | ![Light Tank](thumbnails/light_tank_f2.png) | ![Light Tank](thumbnails/light_tank_f3.png) | Fast armor |
| Main Battle Tank | ![MBT](thumbnails/mbt_f0.png) | ![MBT](thumbnails/mbt_f1.png) | ![MBT](thumbnails/mbt_f2.png) | ![MBT](thumbnails/mbt_f3.png) | Standard armor |
| Heavy Tank | ![Heavy Tank](thumbnails/heavy_tank_f0.png) | ![Heavy Tank](thumbnails/heavy_tank_f1.png) | ![Heavy Tank](thumbnails/heavy_tank_f2.png) | ![Heavy Tank](thumbnails/heavy_tank_f3.png) | Siege armor |
| Self-Propelled Artillery | ![Artillery](thumbnails/artillery_f0.png) | ![Artillery](thumbnails/artillery_f1.png) | ![Artillery](thumbnails/artillery_f2.png) | ![Artillery](thumbnails/artillery_f3.png) | Indirect fire |
| Anti-Air Vehicle | ![AA](thumbnails/aa_vehicle_f0.png) | ![AA](thumbnails/aa_vehicle_f1.png) | ![AA](thumbnails/aa_vehicle_f2.png) | ![AA](thumbnails/aa_vehicle_f3.png) | Air defense |
| Heavy Killer Mech | ![Heavy Mech](thumbnails/heavy_mech_f0.png) | ![Heavy Mech](thumbnails/heavy_mech_f1.png) | ![Heavy Mech](thumbnails/heavy_mech_f2.png) | ![Heavy Mech](thumbnails/heavy_mech_f3.png) | Anti-everything mech |
| Siege Mech | ![Siege Mech](thumbnails/siege_mech_f0.png) | ![Siege Mech](thumbnails/siege_mech_f1.png) | ![Siege Mech](thumbnails/siege_mech_f2.png) | ![Siege Mech](thumbnails/siege_mech_f3.png) | Long-range bombardment |

## Naval

| Unit | AeroDyne | FerroCore | Pelagic | Vanguard | Role |
|---|---|---|---|---|---|
| Patrol Sea Drone | ![Patrol](thumbnails/patrol_boat_f0.png) | ![Patrol](thumbnails/patrol_boat_f1.png) | ![Patrol](thumbnails/patrol_boat_f2.png) | ![Patrol](thumbnails/patrol_boat_f3.png) | Scout and patrol |
| Missile Corvette | ![Corvette](thumbnails/corvette_f0.png) | ![Corvette](thumbnails/corvette_f1.png) | ![Corvette](thumbnails/corvette_f2.png) | ![Corvette](thumbnails/corvette_f3.png) | Missile combatant; deploys sonar buoys (`K`, 30 s cooldown) that reveal submarines to owner/allies for 75 s |
| Attack Submarine | ![Attack Sub](thumbnails/attack_sub_f0.png) | ![Attack Sub](thumbnails/attack_sub_f1.png) | ![Attack Sub](thumbnails/attack_sub_f2.png) | ![Attack Sub](thumbnails/attack_sub_f3.png) | Torpedo/subsurface |
| Ballistic Missile Submarine | ![Ballistic Sub](thumbnails/ballistic_sub_f0.png) | ![Ballistic Sub](thumbnails/ballistic_sub_f1.png) | ![Ballistic Sub](thumbnails/ballistic_sub_f2.png) | ![Ballistic Sub](thumbnails/ballistic_sub_f3.png) | Strategic nuke platform |
| Landing Craft | ![Landing Craft](thumbnails/landing_craft_f0.png) | ![Landing Craft](thumbnails/landing_craft_f1.png) | ![Landing Craft](thumbnails/landing_craft_f2.png) | ![Landing Craft](thumbnails/landing_craft_f3.png) | Amphibious transport |
| Hovercraft | ![Hovercraft](thumbnails/hovercraft_f0.png) | ![Hovercraft](thumbnails/hovercraft_f1.png) | ![Hovercraft](thumbnails/hovercraft_f2.png) | ![Hovercraft](thumbnails/hovercraft_f3.png) | Land and sea, eel hazard |
| Cruiser | ![Cruiser](thumbnails/cruiser_f0.png) | ![Cruiser](thumbnails/cruiser_f1.png) | ![Cruiser](thumbnails/cruiser_f2.png) | ![Cruiser](thumbnails/cruiser_f3.png) | Capital ship |
| Battleship | ![Battleship](thumbnails/battleship_f0.png) | ![Battleship](thumbnails/battleship_f1.png) | ![Battleship](thumbnails/battleship_f2.png) | ![Battleship](thumbnails/battleship_f3.png) | Heavy naval firepower |
| Aircraft Carrier | ![Carrier](thumbnails/aircraft_carrier_f0.png) | ![Carrier](thumbnails/aircraft_carrier_f1.png) | ![Carrier](thumbnails/aircraft_carrier_f2.png) | ![Carrier](thumbnails/aircraft_carrier_f3.png) | Air support at sea |
| Frogbot | ![Frogbot](thumbnails/frogbot_f0.png) | ![Frogbot](thumbnails/frogbot_f1.png) | ![Frogbot](thumbnails/frogbot_f2.png) | ![Frogbot](thumbnails/frogbot_f3.png) | Amphibious stealth bot, takes out capital ships |

## Air

| Unit | AeroDyne | FerroCore | Pelagic | Vanguard | Role |
|---|---|---|---|---|---|
| Scout Aerial Drone | ![Scout](thumbnails/scout_drone_f0.png) | ![Scout](thumbnails/scout_drone_f1.png) | ![Scout](thumbnails/scout_drone_f2.png) | ![Scout](thumbnails/scout_drone_f3.png) | Recon; part of every player's starting escort and the AI's forward sweeps |
| Fighter Drone | ![Fighter](thumbnails/fighter_drone_f0.png) | ![Fighter](thumbnails/fighter_drone_f1.png) | ![Fighter](thumbnails/fighter_drone_f2.png) | ![Fighter](thumbnails/fighter_drone_f3.png) | Air superiority |
| Bomber Drone | ![Bomber](thumbnails/bomber_drone_f0.png) | ![Bomber](thumbnails/bomber_drone_f1.png) | ![Bomber](thumbnails/bomber_drone_f2.png) | ![Bomber](thumbnails/bomber_drone_f3.png) | Ground attack |
| AWACS Radar Drone | ![AWACS](thumbnails/awacs_f0.png) | ![AWACS](thumbnails/awacs_f1.png) | ![AWACS](thumbnails/awacs_f2.png) | ![AWACS](thumbnails/awacs_f3.png) | Vision and radar |

## AI-only NPC units

The four AI-only factions in [`npc.md`](npc.md) cannot be selected by human players, so their unique units cannot be trained by human players either. Each has a **unique per-unit sprite and a single faction-native thumbnail** (`_f4` Vesper, `_f5` Thalassa, `_f6` Gravebound, `_f7` Lumen) instead of the four corporation recolors above. These units appear only when an AI side uses that faction in skirmish, co-op or spectator play.

| Unit | Faction (ID) | Native thumbnail | Role |
|---|---|---|---|
| `ufo_wisp` | Vesper Ascendancy (4) | ![Ufo Wisp](thumbnails/ufo_wisp_f4.png) | Fast scouting saucer; opens fights and baits anti-air. |
| `ufo_talon` | Vesper Ascendancy (4) | ![Ufo Talon](thumbnails/ufo_talon_f4.png) | Agile strike saucer for air superiority and intercepts. |
| `ufo_nova` | Vesper Ascendancy (4) | ![Ufo Nova](thumbnails/ufo_nova_f4.png) | Heavy saucer bomber and main aerial damage dealer. |
| `abyssal_trireme` | Thalassa Dominion (5) | ![Abyssal Trireme](thumbnails/abyssal_trireme_f5.png) | Armored naval line warship. |
| `leviathan_carrier` | Thalassa Dominion (5) | ![Leviathan Carrier](thumbnails/leviathan_carrier_f5.png) | Capital carrier projecting air support at sea. |
| `nereid_raider` | Thalassa Dominion (5) | ![Nereid Raider](thumbnails/nereid_raider_f5.png) | Fast sea raider for flanks and shoreline strikes. |
| `bone_legionary` | Gravebound Legion (6) | ![Bone Legionary](thumbnails/bone_legionary_f6.png) | Resilient line infantry for attrition pushes. |
| `ghoul_stalker` | Gravebound Legion (6) | ![Ghoul Stalker](thumbnails/ghoul_stalker_f6.png) | Fast stalker that exploits exposed flanks. |
| `lichen_colossus` | Gravebound Legion (6) | ![Lichen Colossus](thumbnails/lichen_colossus_f6.png) | Soaks fire as a hulking bio-armor bruiser. |
| `lumen_operative` | Lumen Cabal (7) | ![Lumen Operative](thumbnails/lumen_operative_f7.png) | Cloaked infiltrator for recon and sabotage. |
| `lumen_oracle` | Lumen Cabal (7) | ![Lumen Oracle](thumbnails/lumen_oracle_f7.png) | Long-sight controller that holds distant targets visible. |
| `lumen_enforcer` | Lumen Cabal (7) | ![Lumen Enforcer](thumbnails/lumen_enforcer_f7.png) | Protected shock unit that finishes exposed targets. |

NPC factions otherwise draw from the same shared roster and production buildings as the corporations; their faction modifiers are listed in [`npc.md`](npc.md).
