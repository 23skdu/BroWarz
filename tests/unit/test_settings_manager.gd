# tests/unit/test_settings_manager.gd
extends GutTest

var _original: Dictionary = {}

func before_each() -> void:
	_original = SettingsManager.settings.duplicate(true)

func after_each() -> void:
	SettingsManager.settings = _original.duplicate(true)
	SettingsManager.store.data = _original.duplicate(true)
	SettingsManager.apply_to_scene()

func test_defaults_and_setting_access():
	assert_eq(SettingsManager.get_setting("master_volume"), 1.0)
	assert_eq(SettingsManager.get_setting("colorblind"), "none")
	assert_eq(SettingsManager.get_setting("soundtrack"), "aerodyne")
	assert_true(SettingsManager.get_setting("missing", 42) == 42)
	SettingsManager.set_setting("camera_speed", 640.0)
	assert_eq(SettingsManager.store.get_value("camera_speed"), 640.0)
	assert_eq(SettingsManager.get_setting("camera_speed"), 640.0)

func test_hotkeys_and_palette():
	assert_eq(SettingsManager.hotkey("camera_up"), KEY_W)
	SettingsManager.bind_hotkey("camera_up", KEY_I)
	assert_eq(SettingsManager.hotkey("camera_up"), KEY_I)
	SettingsManager.bind_hotkey("bogus", KEY_Z)
	assert_eq(SettingsManager.hotkey("bogus"), KEY_W)
	SettingsManager.set_setting("colorblind", "invalid")
	assert_eq(SettingsManager.colorblind_palette(), "none")
	SettingsManager.set_setting("colorblind", "tritanopia")
	assert_eq(SettingsManager.colorblind_palette(), "tritanopia")

func test_save_load_and_reset():
	var path := "user://browarz_test_settings.cfg"
	SettingsManager.set_setting("sfx_volume", 0.25)
	SettingsManager.set_setting("colorblind", "protanopia")
	SettingsManager.set_setting("soundtrack", "vanguard")
	assert_eq(SettingsManager.save_settings(path), OK)
	SettingsManager.reset_defaults()
	assert_eq(SettingsManager.get_setting("sfx_volume"), 1.0)
	assert_eq(SettingsManager.get_setting("soundtrack"), "aerodyne")
	SettingsManager.load_settings(path)
	assert_eq(SettingsManager.get_setting("sfx_volume"), 0.25)
	assert_eq(SettingsManager.colorblind_palette(), "protanopia")
	assert_eq(SettingsManager.get_setting("soundtrack"), "vanguard")
	assert_eq(AudioManager.soundtrack, "vanguard")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_settings_dialog_builds_and_frees():
	var dialog := SettingsDialog.new()
	add_child_autofree(dialog)
	assert_gt(dialog.get_children().size(), 0)
	assert_eq(dialog.get_ok_button().text, "Save & Close")
