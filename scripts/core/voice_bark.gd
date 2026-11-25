# scripts/core/voice_bark.gd
class_name VoiceBark
extends RefCounted

## Deterministic robotic voice-bark catalog, per-weapon SFX resolver, and
## accessible subtitle formatter. Pure logic so tests and headless runs can
## verify every cue without an audio device.

const DEFAULT_COOLDOWN_SEC: float = 1.8

const EVENTS: Array[String] = [
	"select", "move", "attack", "under_attack", "build_complete",
	"tech_complete", "capture", "sonar_buoy", "orbital_laser",
	"nuke_warning", "eel_hazard", "victory", "defeat",
]

const EVENT_SFX := {
	"select": "bark_ready",
	"move": "bark_confirm",
	"attack": "bark_engage",
	"under_attack": "alert_under_attack",
	"build_complete": "build_complete",
	"tech_complete": "tech_up",
	"capture": "capture",
	"sonar_buoy": "sonar_ping",
	"orbital_laser": "laser",
	"nuke_warning": "nuke",
	"eel_hazard": "eel",
	"victory": "bark_ready",
	"defeat": "bark_alert",
}

const FACTION_TAG := {
	Faction.Id.AERODYNE: "AeroDyne",
	Faction.Id.FERROCORE: "FerroCore",
	Faction.Id.PELAGIC: "Pelagic",
	Faction.Id.VANGUARD: "Vanguard",
	Faction.Id.VESPER: "Vesper",
	Faction.Id.THALASSA: "Thalassa",
	Faction.Id.GRAVEBOUND: "Gravebound",
	Faction.Id.LUMEN: "Lumen",
}

static func all_events() -> Array[String]:
	return EVENTS.duplicate()

static func sfx_for_event(event: String) -> String:
	return String(EVENT_SFX.get(event, "bark_confirm"))

static func weapon_sfx_for_damage_type(damage_type: int) -> String:
	match damage_type:
		Damage.DamageType.EXPLOSIVE: return "weapon_explosive"
		Damage.DamageType.ENERGY: return "weapon_energy"
		Damage.DamageType.EMP: return "weapon_emp"
		Damage.DamageType.THERMAL: return "weapon_thermal"
		Damage.DamageType.TOXIC: return "weapon_toxic"
		_: return "weapon_kinetic"

static func can_emit(last_time: float, now: float, cooldown: float = DEFAULT_COOLDOWN_SEC) -> bool:
	if last_time < 0.0:
		return true
	return (now - last_time) >= maxf(0.0, cooldown)

static func subtitle_for(event: String, faction_id: int = 0, subject: String = "") -> String:
	var tag := String(FACTION_TAG.get(faction_id, "Command"))
	var detail := subject.strip_edges()
	var line := ""
	match event:
		"select":
			line = _select_line(faction_id)
		"move":
			line = _move_line(faction_id)
		"attack":
			line = _attack_line(faction_id)
		"under_attack":
			line = "Warning: friendly forces under fire!"
		"build_complete":
			line = "Construction complete: %s." % detail if not detail.is_empty() else "Construction complete."
		"tech_complete":
			line = "Research online: %s." % detail if not detail.is_empty() else "Technology upgrade online."
		"capture":
			line = "Facility captured: %s." % detail if not detail.is_empty() else "Enemy facility captured."
		"sonar_buoy":
			line = "Sonar buoy active — scanning subsurface contacts."
		"orbital_laser":
			line = "Orbital laser firing on designated coordinates."
		"nuke_warning":
			line = "Strategic nuclear launch detected!"
		"eel_hazard":
			line = "Propulsion jammed — hovercraft full of eels!"
		"victory":
			line = "Sector secured. Division claim ratified."
		"defeat":
			line = "Production lost. Command link terminated."
		_:
			line = "Acknowledged."
	return "[%s] %s" % [tag, line]

static func _select_line(faction_id: int) -> String:
	match faction_id:
		Faction.Id.AERODYNE: return "Flight telemetry locked. Awaiting vector."
		Faction.Id.FERROCORE: return "Armor chassis online. Ready for orders."
		Faction.Id.PELAGIC: return "Hydro-drive nominal. Standing by."
		Faction.Id.VANGUARD: return "Cloak array calibrated. Go ahead."
		Faction.Id.VESPER: return "Orbital link resonant."
		Faction.Id.THALASSA: return "Abyssal helm answers."
		Faction.Id.GRAVEBOUND: return "Ranks standing."
		Faction.Id.LUMEN: return "Veil attentive."
	return "Unit online. Awaiting coordinates."

static func _move_line(faction_id: int) -> String:
	match faction_id:
		Faction.Id.AERODYNE: return "Course plotted. Advancing."
		Faction.Id.FERROCORE: return "Roll out. Moving to grid."
		Faction.Id.PELAGIC: return "Heading locked. Underway."
		Faction.Id.VANGUARD: return "Moving quietly to waypoint."
		_: return "Coordinates confirmed. En route."

static func _attack_line(faction_id: int) -> String:
	match faction_id:
		Faction.Id.AERODYNE: return "Target painted. Engaging."
		Faction.Id.FERROCORE: return "Weapons hot. Rolling to contact."
		Faction.Id.PELAGIC: return "Salvo armed. Closing range."
		Faction.Id.VANGUARD: return "Ambush vector set. Engaging."
		_: return "Hostile locked. Engaging target."
