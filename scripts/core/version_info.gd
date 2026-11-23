# scripts/core/version_info.gd
class_name VersionInfo
extends RefCounted

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

static func commit_sha() -> String:
	var path := "res://build_info.json"
	if not FileAccess.file_exists(path):
		return "dev"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "dev"
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return str(parsed.get("commit_sha", "dev"))
	return "dev"
