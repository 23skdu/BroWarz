# BroWarz — Corporations

Each playable corporation is one of four weapons divisions of a single planetary megacorp ("Terran Herzog Heavy Industries") that rules the planet. The RTS match is how the four divisions settle their dividing of planetary resources — borders are drawn by match results.

Each playable corporation has a unique identity: motto, background, distinctive color, and gameplay modifiers. Units and buildings use the corporation color for quick identification. When two players run the *same* corporation against each other (e.g. 2v2), the colors read as a chess game: the corporation keeps its base color and the opposing player uses black (`#0a0a0b`) or white (`#f7f7f8`), letting them be told apart.

## AeroDyne Industries
![AeroDyne Banner](../assets/banners/aerodyne.png)
- **Motto:** "Dominion of the Skies"
- **Background:** An aerospace megacorp dominating orbital and aerial warfare. Founded from a satellite network conglomerate, AeroDyne controls the high ground.
- **Color:** Sky Blue `#3FBFFF`
- **Strengths:** Air superiority, orbital laser cooldown reduction, cheaper aerial drones.
- **Weaknesses:** Lighter ground armor, fewer heavy tanks.
- **Preferred units:** Scout/fighter/bomber drones, AWACS, orbital laser uplink.
- **Signature:** Cheaper aerial drones; orbital laser cooldown −15%.

## FerroCore Heavy
![FerroCore Banner](../assets/banners/ferrocore.png)
- **Motto:** "Iron Will, Iron Fist"
- **Background:** A heavy-industry giant specializing in armor and siege. FerroCore builds the thickest armor and biggest guns.
- **Color:** Amber `#FF8C26`
- **Strengths:** Heavy tanks, sappers, fortifications.
- **Weaknesses:** Slower air force, limited stealth.
- **Preferred units:** Main battle tanks, heavy tanks, artillery, sapperbots, turrets.
- **Signature:** Heavier tanks; sappers destroy fortifications faster.

## Pelagic Systems
![Pelagic Banner](../assets/banners/pelagic.png)
- **Motto:** "Depths of Power"
- **Background:** A naval conglomerate ruling the seas and depths. Pelagic controls shipping lanes and submarine warfare.
- **Color:** Teal `#26CCC0`
- **Strengths:** Naval superiority, submarine stealth, cheaper sea drones.
- **Weaknesses:** Weaker land armor, limited air force.
- **Preferred units:** Patrol boats, corvettes, submarines, frogbots, shipyards.
- **Signature:** Submarines start cloaked; cheaper sea drones.

## Vanguard Robotics
![Vanguard Banner](../assets/banners/vanguard.png)
- **Motto:** "Unseen, Unstoppable"
- **Background:** A stealth and infantry specialist of covert operations. Vanguard excels at ambush and rapid infantry deployment.
- **Color:** Violet `#BF59F2`
- **Strengths:** Stealth, infantry, mechanized units.
- **Weaknesses:** Lighter vehicles, limited naval presence.
- **Preferred units:** Stealthbots, sniperbots, rocketbots, mechanized infantry, light mechs.
- **Signature:** Stealth units cloak longer; mechanized infantry cheaper.

## Unit Colors
Unit and building sprites use the corporation color of their owner so factions are identifiable at a glance on the battlefield. A same-corporation mirror match uses the chess black/white variants from `Faction.color_of(id, variant)` so the two sides remain readable.

## Diplomatic Doctrine

The divisions negotiate as rivals inside one megacorp: an alliance is a temporary resource-budget accord, not a merger. Every corporation follows the same in-match rules in [`diplomacy.md`](diplomacy.md); none receives a diplomacy-specific gameplay bonus. Their narrative postures differ:

| Corporation | Negotiating style | Typical alliance goal |
|---|---|---|
| **AeroDyne Industries** | Precise, transactional airspace pacts | Protect drone corridors and orbital uplink windows. |
| **FerroCore Heavy** | Blunt border agreements | Secure flank against armored pushes while siege works finish. |
| **Pelagic Systems** | Shipping-lane and seabed accords | Keep sea lanes open and submarine deterrents pointed elsewhere. |
| **Vanguard Robotics** | Quiet non-aggression understandings | Cover covert infantry deployments and reconnaissance. |

Any two divisions can sign a short-lived side agreement in a 3+ team match. Allied teams share vision and refuse friendly fire, but keep their own colors, emblems, resources, factories, research and unit control. In co-op the host picks the shared human corporation, the AI corporation and AI difficulty; in spectator the Corporation and AI Side B Corp selectors pick the two AI divisions. Faction choice changes each squad's color/signature identity, never the alliance rules.
