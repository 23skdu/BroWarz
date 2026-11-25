# tests/unit/test_audio_manager.gd
extends GutTest

var _original_soundtrack: String = "aerodyne"
var _original_music: String = "menu"

func before_each() -> void:
	_original_soundtrack = AudioManager.soundtrack
	_original_music = AudioManager.current_music

func after_each() -> void:
	SettingsManager.set_setting("soundtrack", _original_soundtrack)
	AudioManager.current_music = _original_music
	if _original_music != "":
		AudioManager.set_music(_original_music)

func test_eight_faction_soundtracks_are_wired():
	assert_eq(AudioManager.SOUNDTRACK_ORDER.size(), 8)
	var expected_factions := [
		Faction.Id.AERODYNE, Faction.Id.FERROCORE,
		Faction.Id.PELAGIC, Faction.Id.VANGUARD,
		Faction.Id.VESPER, Faction.Id.THALASSA,
		Faction.Id.GRAVEBOUND, Faction.Id.LUMEN,
	]
	for index in range(AudioManager.SOUNDTRACK_ORDER.size()):
		var id := String(AudioManager.SOUNDTRACK_ORDER[index])
		assert_true(ResourceLoader.exists("res://assets/music/%s.wav" % id))
		assert_eq(AudioManager.soundtrack_faction(id), expected_factions[index])
		assert_eq(AudioManager.soundtrack_for_faction(expected_factions[index]), id)
		assert_true(AudioManager.soundtrack_label(id).contains(Faction.name_of(expected_factions[index])))
		assert_ne(AudioManager.soundtrack_theme(id), "")

func test_cycle_and_set_soundtrack_are_bounded():
	assert_eq(AudioManager.next_soundtrack(), "ferrocore")
	AudioManager.set_soundtrack("vanguard")
	assert_eq(AudioManager.soundtrack, "vanguard")
	assert_eq(AudioManager.next_soundtrack(), "vesper")
	AudioManager.set_soundtrack("lumen")
	assert_eq(AudioManager.soundtrack, "lumen")
	assert_eq(AudioManager.next_soundtrack(), "aerodyne")
	assert_false(AudioManager.set_soundtrack("unknown"))
	assert_eq(AudioManager.soundtrack, "lumen")

func test_menu_and_battle_cues_follow_the_selected_soundtrack():
	AudioManager.set_soundtrack("vesper")
	AudioManager.set_music("battle")
	assert_eq(AudioManager.current_music, "battle")
	assert_eq(AudioManager._music_path("battle"), "res://assets/music/vesper.wav")
	assert_eq(AudioManager._music_path("menu"), "res://assets/music/vesper.wav")
	var stream: AudioStreamWAV = AudioManager._music_player.stream
	assert_not_null(stream)
	assert_gt(stream.get_length(), 8.0)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)

func test_soundtrack_setting_applies_to_live_audio_and_store():
	SettingsManager.set_setting("soundtrack", "ferrocore")
	assert_eq(SettingsManager.get_setting("soundtrack"), "ferrocore")
	assert_eq(SettingsManager.store.get_value("soundtrack"), "ferrocore")
	assert_eq(AudioManager.soundtrack, "ferrocore")

func test_settings_dialog_exposes_all_eight_soundtracks():
	var dialog := SettingsDialog.new()
	add_child_autofree(dialog)
	var option := _find_option_button(dialog)
	assert_not_null(option)
	assert_eq(option.item_count, 8)
	assert_eq(option.get_item_text(0), AudioManager.soundtrack_label("aerodyne"))
	assert_eq(option.get_item_text(4), AudioManager.soundtrack_label("vesper"))

func test_sfx_players_are_released_even_without_finished_signal():
	AudioManager.muted = false
	AudioManager.play_sfx("click")
	assert_gt(_sfx_player_count(), 0)
	await get_tree().create_timer(0.7).timeout
	assert_eq(_sfx_player_count(), 0)

func _sfx_player_count() -> int:
	var count := 0
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and child != AudioManager._music_player:
			count += 1
	return count

func _find_option_button(node: Node) -> OptionButton:
	if node is OptionButton:
		return node
	for child in node.get_children():
		var found := _find_option_button(child)
		if found != null:
			return found
	return null
