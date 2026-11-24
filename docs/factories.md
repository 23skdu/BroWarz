# BroWarz — Factories & Production Structures

Production in BroWarz is organized into tiered industrial facilities across land, naval, and aerial domains. Capturing or destroying all of an enemy corporation's production facilities eliminates their ability to sustain warfare and wins the match.

---

## 1. Command & Logistics

### Headquarters (`hq`)
- **Footprint:** 3 × 3 tiles
- **HP:** 1,200
- **Cost:** 400 Iron, 100 Food (Build Time: 12.0s)
- **Role:** Primary corporate command center and base population anchor.
- **Produces:** Basic `engineerbot` construction droids and coordinates orbital/strategic uplinks.

---

## 2. Ground & Mech Production

### Mech Factory 1 (`mech_factory_1`)
- **Footprint:** 2 × 2 tiles
- **HP:** 650
- **Cost:** 60 Oil, 170 Iron, 40 Food (Build Time: 6.0s)
- **Built By:** Basic `engineerbot` or `hq`
- **Role:** Assembly plant for smaller infantry robots and light scout walkers.
- **Produces:**
  - `riflebot` (Line Infantry Robot)
  - `heavybot` (Mountain-Capable Heavy Infantry Robot)
  - `sapperbot` (Demolition & Fortification Bot)
  - `stealthbot` (Cloaked Recon/Ambush Bot)
  - `sniperbot` (Long-Range Precision Bot)
  - `rocketbot` (Anti-Armor Infantry Bot)
  - `medicbot` (Field Repair Support Bot)
  - `engineerbot` (Standard Construction Bot)
  - `light_mech` (Fast Bipedal Scout Mech)
  - `light_tank` (Fast Recon Tank)

### Mech Factory 2 (`mech_factory_2`)
- **Footprint:** 3 × 2 tiles
- **HP:** 850
- **Cost:** 120 Oil, 260 Iron, 50 Geothermal, 50 Food (Build Time: 8.5s)
- **Built By:** `engineerbot` (Requires T2 Tech)
- **Role:** Heavy assembly line for medium-sized armored combat vehicles and **Advanced Construction Bots** (`adv_engineerbot`).
- **Produces:**
  - `adv_engineerbot` (**Advanced Construction Bot** — required to construct **Mech Factory 3**, **Advanced Shipyard**, and **Aeries Level 2**)
  - `apc` (6×6 Armored Personnel Carrier / IFV)
  - `mbt` (Main Battle Tank)
  - `artillery` (Self-Propelled Siege Howitzer)
  - `aa_vehicle` (Mobile Quad-Flak Air Defense Vehicle)

### Mech Factory 3 (`mech_factory_3`)
- **Footprint:** 3 × 3 tiles
- **HP:** 1,150
- **Cost:** 220 Oil, 420 Iron, 150 Geothermal, 70 Food (Build Time: 12.0s)
- **Built By:** **Only buildable by Advanced Construction Bots (`adv_engineerbot`)** (Requires T3 Tech)
- **Role:** Apex heavy foundry capable of fabricating super-heavy armor and colossal killer mechs.
- **Produces:**
  - `heavy_tank` (Twin-Barrel Siege Mammoth Tank)
  - `heavy_mech` (Heavy Killer Mech)
  - `siege_mech` (Long-Range Thermal Bombardment Mech)

---

## 3. Maritime & Subsurface Production

### Docks (`docks`)
- **Footprint:** 2 × 2 tiles (Coastal / Water edge)
- **HP:** 550
- **Cost:** 50 Oil, 160 Iron, 25 Food (Build Time: 5.5s)
- **Built By:** `engineerbot`
- **Role:** Littoral naval berth for patrol craft, amphibious transports, and stealth amphibious bots.
- **Produces:**
  - `patrol_boat` (Patrol Sea Drone)
  - `landing_craft` (Amphibious Transport)
  - `hovercraft` (Amphibious Air-Cushion Craft)
  - `frogbot` (Amphibious Stealth Demolition Frogbot)

### Shipyard (`shipyard`)
- **Footprint:** 3 × 2 tiles (Water)
- **HP:** 750
- **Cost:** 90 Oil, 220 Iron, 30 Geothermal, 30 Food (Build Time: 7.5s)
- **Built By:** `engineerbot` (Requires T2 Tech)
- **Role:** Fleet drydock for blue-water escort warships and attack submarines.
- **Produces:**
  - `corvette` (Guided-Missile Corvette)
  - `attack_sub` (Torpedo Attack Submarine)
  - `cruiser` (Guided-Missile Cruiser)

### Advanced Shipyard (`advanced_shipyard`)
- **Footprint:** 3 × 3 tiles (Deep Water)
- **HP:** 1,050
- **Cost:** 180 Oil, 360 Iron, 110 Geothermal, 50 Food (Build Time: 11.5s)
- **Built By:** `adv_engineerbot` (Requires T3 Tech)
- **Role:** Capital naval yard for dreadnought battleships, fleet carriers, and strategic nuclear submarines.
- **Produces:**
  - `battleship` (Heavy Dreadnought Battleship)
  - `aircraft_carrier` (Fleet Aircraft Carrier)
  - `ballistic_sub` (Ballistic-Missile Strategic Submarine)

---

## 4. Aerial & Orbital Production (Aeries)

### Aeries Level 1 (`aeries_1`)
- **Footprint:** 2 × 2 tiles
- **HP:** 650
- **Cost:** 90 Oil, 190 Iron, 40 Geothermal, 30 Food (Build Time: 7.0s)
- **Built By:** `engineerbot`
- **Role:** Tactical drone launchpad and flight deck for reconnaissance and air-superiority UAVs.
- **Produces:**
  - `scout_drone` (High-Speed Recon Aerial Drone)
  - `fighter_drone` (Air-Superiority Delta Fighter Drone)

### Aeries Level 2 (`aeries_2`)
- **Footprint:** 3 × 2 tiles
- **HP:** 920
- **Cost:** 170 Oil, 310 Iron, 110 Geothermal, 45 Food (Build Time: 10.0s)
- **Built By:** `adv_engineerbot` (Requires T3 Tech)
- **Role:** Heavy stratospheric flight wing for strike bombers and airborne radar command craft.
- **Produces:**
  - `bomber_drone` (Heavy Flying-Wing Strike Bomber)
  - `awacs` (AWACS Airborne Radar & EMP Drone)

---

## 5. Summary Table

| Building ID | Display Name | Tier | Builder Required | Primary Output Domain |
|---|---|---|---|---|
| `hq` | Corporate HQ | T1 | Starting / `engineerbot` | Command & Basic Engineers |
| `docks` | Naval Docks | T1 | `engineerbot` | Littoral Craft, Hovercraft, Frogbots |
| `mech_factory_1` | Mech Factory 1 | T1 | `engineerbot` | Small Infantry Bots & Light Mechs |
| `mech_factory_2` | Mech Factory 2 | T2 | `engineerbot` | Medium Armor & Advanced Construction Bots |
| `mech_factory_3` | Mech Factory 3 | T3 | **`adv_engineerbot` only** | Heavy Tanks, Heavy Killer Mechs, Siege Mechs |
| `shipyard` | Naval Shipyard | T2 | `engineerbot` | Corvettes, Attack Subs, Cruisers |
| `advanced_shipyard` | Advanced Shipyard | T3 | `adv_engineerbot` | Battleships, Aircraft Carriers, Ballistic Subs |
| `aeries_1` | Aeries Level 1 | T1/T2 | `engineerbot` | Scout Drones & Fighter Drones |
| `aeries_2` | Aeries Level 2 | T3 | `adv_engineerbot` | Bomber Drones & AWACS Radar Drones |
