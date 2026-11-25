extends SceneTree

# Deterministic retro-synth WAV generator. Run with:
#   godot --headless -s res://scripts/tools/generate_audio.gd
# The committed WAVs under assets/ are produced by this tool; regenerating
# them is reproducible and does not require external audio libraries.
#
# In addition to the original menu/battle beds and SFX, this tool renders the
# four faction soundtracks. Each is a 10-second seamless loop with a distinct
# harmonic language matched to its corporation:
#   AeroDyne  - bright major arpeggios and glassy aerial pads
#   FerroCore - E-minor industrial riff, sub bass and hammered metal
#   Pelagic   - A-dorian 6/8 tides with submerged marimba plucks
#   Vanguard  - sparse whole-tone stabs, radar ticks and a covert drone

const SAMPLE_RATE := 22050
const LOOP_SECONDS := 10.0
const FRAMES := int(SAMPLE_RATE * LOOP_SECONDS)
const NOTE_SEMITONES := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

func _init() -> void:
	var root := "res://assets"
	_write_music("%s/music/menu.wav" % root, _menu_theme())
	_write_music("%s/music/battle.wav" % root, _battle_theme())
	_write_music("%s/music/aerodyne.wav" % root, _aerodyne_theme(), true)
	_write_music("%s/music/ferrocore.wav" % root, _ferrocore_theme(), true)
	_write_music("%s/music/pelagic.wav" % root, _pelagic_theme(), true)
	_write_music("%s/music/vanguard.wav" % root, _vanguard_theme(), true)
	_write_sfx("%s/sfx/click.wav" % root, _tone(0.08, 880.0, 0.25, 0.0))
	_write_sfx("%s/sfx/laser.wav" % root, _sweep(0.35, 1200.0, 180.0, 0.32))
	_write_sfx("%s/sfx/explosion.wav" % root, _noise(0.65, 0.38))
	_write_sfx("%s/sfx/nuke.wav" % root, _sweep(1.2, 180.0, 32.0, 0.45))
	_write_sfx("%s/sfx/eel.wav" % root, _sweep(0.28, 420.0, 90.0, 0.28))
	print("Generated 6 music beds and 5 SFX clips.")
	quit()

# ---------------------------------------------------------------------------
# Original menu/battle beds and SFX
# ---------------------------------------------------------------------------

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
		var arp := sin(TAU * 196.0 * fmod(t, 0.5)) * 0.08
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

# ---------------------------------------------------------------------------
# Faction soundtrack helpers
# ---------------------------------------------------------------------------

func _q(freq: float) -> float:
	# Quantize to a whole number of cycles over LOOP_SECONDS so sustained
	# partials are seamless when the WAV loops.
	return round(freq * LOOP_SECONDS) / LOOP_SECONDS

func _hz(pitch: String) -> float:
	var semitone := int(NOTE_SEMITONES.get(pitch.substr(0, pitch.length() - 1), 0))
	var octave := int(pitch.substr(pitch.length() - 1, 1))
	var midi := 12 * (octave + 1) + semitone
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)

func _blank_loop() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(FRAMES)
	return out

func _add_voice(buf: PackedFloat32Array, start: float, length: float, freq: float,
		amp: float, partials: Array, attack: float, release: float,
		detune: float = 0.0) -> void:
	# Add an envelope-shaped voice. Tails wrap modulo FRAMES, so notes near
	# the end of the loop continue at the beginning instead of being clipped.
	var f := _q(freq)
	var start_i := int(start * float(SAMPLE_RATE)) % FRAMES
	var length_i := maxi(1, int(length * float(SAMPLE_RATE)))
	var attack_i := maxi(1, int(attack * float(SAMPLE_RATE)))
	var release_i := maxi(1, int(release * float(SAMPLE_RATE)))
	var voices: Array = []
	var norm := 0.0
	for p in partials:
		var pf := _q(f * float(p[0]))
		var weight := float(p[1])
		voices.append([pf, weight])
		norm += absf(weight)
	if detune != 0.0:
		voices.append([_q(f * (1.0 + detune)), 0.45])
		norm += 0.45
	for offset in range(length_i):
		var idx := (start_i + offset) % FRAMES
		var env := 1.0
		if offset < attack_i:
			env = float(offset) / float(attack_i)
		else:
			var remaining := length_i - offset
			if remaining < release_i:
				env = maxf(0.0, float(remaining) / float(release_i))
		if release >= length * 0.75:
			env *= exp(-3.0 * float(offset) / float(length_i))
		var age := float(offset) / float(SAMPLE_RATE)
		var sample := 0.0
		for v in voices:
			sample += float(v[1]) * sin(TAU * float(v[0]) * age)
		sample /= maxf(1.0, norm)
		buf[idx] = buf[idx] + amp * env * sample

func _add_kick(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var start_i := int(start * float(SAMPLE_RATE)) % FRAMES
	var length_i := int(0.34 * float(SAMPLE_RATE))
	var phase := 0.0
	for offset in range(length_i):
		var t := float(offset) / float(SAMPLE_RATE)
		var hz := 52.0 + 95.0 * exp(-28.0 * t)
		phase += hz / float(SAMPLE_RATE)
		var env := exp(-12.0 * t)
		var idx := (start_i + offset) % FRAMES
		buf[idx] = buf[idx] + amp * env * sin(TAU * phase)

func _normalize(buf: PackedFloat32Array, target: float) -> void:
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, absf(s))
	if peak <= 0.001:
		return
	var scale := target / peak
	for i in range(buf.size()):
		buf[i] = buf[i] * scale

func _aerodyne_theme() -> PackedFloat32Array:
	# Dominion of the Skies: luminous D-major air-horn pads, bell arpeggios.
	var buf := _blank_loop()
	var chords := [
		["D4", "F#4", "A4", "D5"],
		["A3", "C#4", "E4", "A4"],
		["B3", "D4", "F#4", "B4"],
		["G3", "B3", "D4", "G4"],
	]
	for bar in range(chords.size()):
		var base := float(bar) * 2.0
		var chord: Array = chords[bar]
		for p in chord:
			_add_voice(buf, base, 1.96, _hz(String(p)), 0.105,
				[[1.0, 1.0], [2.0, 0.32], [3.0, 0.12]], 0.32, 0.55, 0.004)
		for step in range(8):
			var f := _hz(String(chord[step % 4]))
			if step >= 4:
				f *= 2.0
			_add_voice(buf, base + float(step) * 0.25, 0.42, f, 0.15,
				[[1.0, 1.0], [2.76, 0.28], [5.4, 0.10]], 0.006, 0.32)
		for step in range(8):
			_add_voice(buf, base + float(step) * 0.25, 0.18,
				1760.0 + float(step % 3) * 37.0, 0.018,
				[[1.0, 1.0], [3.1, 0.35]], 0.01, 0.16)
	return buf

func _ferrocore_theme() -> PackedFloat32Array:
	# Iron Will, Iron Fist: E-minor forge riff, sub drone, anvil percussion.
	var buf := _blank_loop()
	var riff := ["E2", "E2", "G2", "E2", "F2", "E2", "B1", "E2"]
	for repeat in range(5):
		for i in range(riff.size()):
			var idx := repeat * riff.size() + i
			_add_voice(buf, float(idx) * 0.25, 0.235, _hz(riff[i]), 0.22,
				[[1.0, 1.0], [2.0, 0.62], [3.0, 0.34], [4.0, 0.18], [6.0, 0.09]],
				0.004, 0.16)
	for i in range(20):
		var start := float(i) * 0.5
		_add_kick(buf, start, 0.65 if i % 4 == 0 else 0.42)
		if i % 2 == 1:
			_add_voice(buf, start + 0.25, 0.26, 310.0, 0.14,
				[[1.0, 1.0], [2.41, 0.7], [3.83, 0.45], [5.17, 0.22]],
				0.002, 0.24)
	for p in ["E1", "B1"]:
		_add_voice(buf, 0.0, 9.96, _hz(p), 0.11,
			[[1.0, 1.0], [2.0, 0.25]], 0.4, 0.6)
	return buf

func _pelagic_theme() -> PackedFloat32Array:
	# Depths of Power: A-dorian rolling 6/8 tides and submerged marimba.
	var buf := _blank_loop()
	var pattern := ["A3", "C4", "E4", "F#4", "E4", "C4",
		"G3", "B3", "D4", "E4", "D4", "B3"]
	var step := LOOP_SECONDS / float(pattern.size())
	for repeat in range(4):
		for i in range(pattern.size()):
			var idx := repeat * pattern.size() + i
			var start := float(idx) * step
			_add_voice(buf, start, 0.72, _hz(pattern[i]), 0.16,
				[[1.0, 1.0], [2.0, 0.18], [3.01, 0.07]], 0.012, 0.55)
			if i % 6 == 0:
				_add_voice(buf, start, 6.0, _hz(pattern[i]) * 0.5, 0.085,
					[[1.0, 1.0], [1.5, 0.22], [2.0, 0.12]], 0.9, 1.6, -0.003)
	for i in range(12):
		_add_voice(buf, float(i) * (LOOP_SECONDS / 12.0), 1.35,
			92.0 + float(i % 4) * 11.0, 0.035,
			[[1.0, 1.0], [1.01, 0.55], [2.003, 0.2]], 0.28, 0.9)
	return buf

func _vanguard_theme() -> PackedFloat32Array:
	# Unseen, Unstoppable: whole-tone stabs, radar ticks, covert sub pulse.
	var buf := _blank_loop()
	for i in range(20):
		_add_voice(buf, float(i) * 0.5, 0.4, _hz("C2"), 0.2,
			[[1.0, 1.0], [2.0, 0.38], [3.0, 0.16]], 0.008, 0.28)
	var stabs := ["C4", "F#4", "D4", "G#4", "A3", "D#4"]
	for i in range(stabs.size()):
		_add_voice(buf, 0.35 + float(i) * 1.55, 1.15, _hz(stabs[i]), 0.115,
			[[1.0, 1.0], [1.414, 0.48], [2.0, 0.22]], 0.02, 0.85, 0.006)
	for i in range(40):
		_add_voice(buf, float(i) * 0.25 + (0.125 if i % 3 == 0 else 0.0),
			0.13, 4200.0 + float(i % 5) * 180.0, 0.035,
			[[1.0, 1.0], [2.7, 0.3]], 0.002, 0.11)
	_add_voice(buf, 0.0, 9.98, _hz("C1"), 0.12,
		[[1.0, 1.0], [2.0, 0.3], [2.828, 0.16]], 0.5, 0.8, 0.004)
	return buf

# ---------------------------------------------------------------------------
# WAV output
# ---------------------------------------------------------------------------

func _write_music(path: String, samples: PackedFloat32Array, normalize: bool = false) -> void:
	if normalize:
		_normalize(samples, 0.82)
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
