extends SceneTree

# Deterministic retro-synth WAV generator (roadmap Step 13). Run with:
#   godot --headless -s res://scripts/tools/generate_audio.gd
# The committed WAVs under assets/ are produced by this tool; regenerating
# them is reproducible and does not require external audio libraries.

const SAMPLE_RATE := 22050

func _init() -> void:
	var root := "res://assets"
	_write_music("%s/music/menu.wav" % root, _menu_theme())
	_write_music("%s/music/battle.wav" % root, _battle_theme())
	_write_sfx("%s/sfx/click.wav" % root, _tone(0.08, 880.0, 0.25, 0.0))
	_write_sfx("%s/sfx/laser.wav" % root, _sweep(0.35, 1200.0, 180.0, 0.32))
	_write_sfx("%s/sfx/explosion.wav" % root, _noise(0.65, 0.38))
	_write_sfx("%s/sfx/nuke.wav" % root, _sweep(1.2, 180.0, 32.0, 0.45))
	_write_sfx("%s/sfx/eel.wav" % root, _sweep(0.28, 420.0, 90.0, 0.28))
	print("Generated %d music beds and %d SFX clips." % [2, 5])
	quit()

func _menu_theme() -> PackedFloat32Array:
	# Minor-key ominous bed: sub drone, dissonant minor second, slow pulse.
	var seconds := 12.0
	var out := PackedFloat32Array()
	var frames := int(seconds * float(SAMPLE_RATE))
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var drone := sin(TAU * 55.0 * t) * 0.24
		var fifth := sin(TAU * 82.41 * t) * 0.12
		var dissonance := sin(TAU * 87.31 * t) * 0.07
		var pulse := sin(TAU * 0.5 * t) * 0.05
		var fade := clampf(minf(t / 1.5, (seconds - t) / 1.5), 0.0, 1.0)
		out.append((drone + fifth + dissonance + pulse) * fade)
	return out

func _battle_theme() -> PackedFloat32Array:
	var seconds := 16.0
	var out := PackedFloat32Array()
	var frames := int(seconds * float(SAMPLE_RATE))
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var bass := sin(TAU * 65.41 * t) * 0.18
		var arp := sin(TAU * 196.0 * (t % 0.5)) * 0.08
		var hat := sin(TAU * 7.0 * t) * 0.04
		var fade := clampf(minf(t / 1.0, (seconds - t) / 1.0), 0.0, 1.0)
		out.append((bass + arp + hat) * fade)
	return out

func _tone(seconds: float, freq: float, amp: float, _unused: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var env := 1.0 - (t / seconds)
		out.append(sin(TAU * freq * t) * amp * env)
	return out

func _sweep(seconds: float, from_hz: float, to_hz: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var frames := int(seconds * float(SAMPLE_RATE))
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(SAMPLE_RATE)
		var hz := from_hz + (to_hz - from_hz) * (t / seconds)
		phase += hz / float(SAMPLE_RATE)
		var env := pow(1.0 - t / seconds, 1.5)
		out.append(sin(TAU * phase) * amp * env)
	return out

func _noise(seconds: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB057
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var env := pow(1.0 - t / seconds, 2.0)
		out.append((rng.randf_range(-1.0, 1.0)) * amp * env)
	return out

func _write_music(path: String, samples: PackedFloat32Array) -> void:
	_write_wav(path, samples)

func _write_sfx(path: String, samples: PackedFloat32Array) -> void:
	_write_wav(path, samples)

func _write_wav(path: String, samples: PackedFloat32Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	var data_size := samples.size() * 2
	f.store_string("RIFF")
	_write_u32(f, 36 + data_size)
	f.store_string("WAVEfmt ")
	_write_u32(f, 16)       # PCM header size
	_write_u16(f, 1)        # PCM
	_write_u16(f, 1)        # mono
	_write_u32(f, SAMPLE_RATE)
	_write_u32(f, SAMPLE_RATE * 2)
	_write_u16(f, 2)        # block align
	_write_u16(f, 16)       # bits per sample
	f.store_string("data")
	_write_u32(f, data_size)
	for sample in samples:
		var v := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
		_write_u16(f, v & 0xFFFF)
	f.close()

func _write_u16(f: FileAccess, value: int) -> void:
	f.store_8(value & 0xFF)
	f.store_8((value >> 8) & 0xFF)

func _write_u32(f: FileAccess, value: int) -> void:
	f.store_8(value & 0xFF)
	f.store_8((value >> 8) & 0xFF)
	f.store_8((value >> 16) & 0xFF)
	f.store_8((value >> 24) & 0xFF)
