# scripts/core/sonar_buoy.gd
class_name SonarBuoy
extends RefCounted

## Pure data/helper for corvette-deployed naval early-warning buoys. A buoy
## reveals submerged enemies of its owner (and the owner's allies) inside its
## radius; it never reveals terrain or surface targets by itself.

const RADIUS_PX: float = 320.0
const LIFETIME_SEC: float = 75.0
const DEPLOY_RANGE_PX: float = 220.0
const COOLDOWN_SEC: float = 30.0

static func make(owner_team: int, owner_id: int, pos: Vector2, deployed_at: float) -> Dictionary:
	return {
		"owner_team": owner_team,
		"owner_id": owner_id,
		"pos": pos,
		"radius_px": RADIUS_PX,
		"deployed_at": deployed_at,
		"expires_at": deployed_at + LIFETIME_SEC,
	}

static func is_active(buoy: Dictionary, now: float) -> bool:
	return float(buoy.get("expires_at", 0.0)) > now

static func reveals_sub(buoy: Dictionary, observer_team: int, target_pos: Vector2, target_is_submerged: bool) -> bool:
	if not target_is_submerged:
		return false
	if not Vision.shared_vision({observer_team: GameManager.alliances.get(observer_team, [])}, observer_team, int(buoy.get("owner_team", -1))):
		return false
	var pos: Vector2 = buoy.get("pos", Vector2.INF)
	return pos.distance_to(target_pos) <= float(buoy.get("radius_px", RADIUS_PX))
