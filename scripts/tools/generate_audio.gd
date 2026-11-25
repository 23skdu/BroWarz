extends SceneTree

# Deterministic retro-synth WAV generator. Run with:
#   godot --headless -s res://scripts/tools/generate_audio.gd
# The committed WAVs under assets/ are produced by this tool; regenerating
# them is reproducible and does not require external audio libraries.
#
# In addition to the original menu/battle beds and SFX, this tool renders the
# eight faction soundtracks (4 playable corporations + 4 AI-only NPC factions).
# Each is a 10-second seamless loop with a distinct harmonic language:
#   AeroDyne   - bright major arpeggios and glassy aerial pads
#   FerroCore  - E-minor industrial riff, sub bass and hammered metal
#   Pelagic    - A-dorian 6/8 tides with submerged marimba plucks
#   Vanguard   - sparse whole-tone stabs, radar ticks and a covert drone
#   Vesper     - Lydian stratospheric saucer hum and eerie vibrato theremin
#   Thalassa   - deep D-dorian abyssal brass swells and sunken temple bells
#   Gravebound - heavy C-phrygian funeral march, crypt organ and bone ticks
#   Lumen      - cryptic A harmonic-minor baroque plucks and veiled choir pads

const SAMPLE_RATE := 22050
const LOOP_SECONDS := 10.0
const FRAMES := int(SAMPLE_RATE * LOOP_SECONDS)
const NOTE_SEMITONES := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

func _init() -> void:
	var asset_root := "res://assets"
	_write_music("%s/music/menu.wav" % asset_root, _menu_theme())
	_write_music("%s/music/battle.wav" % asset_root, _battle_theme())
	_write_music("%s/music/aerodyne.wav" % asset_root, _aerodyne_theme(), true)
	_write_music("%s/music/ferrocore.wav" % asset_root, _ferrocore_theme(), true)
	_write_music("%s/music/pelagic.wav" % asset_root, _pelagic_theme(), true)
	_write_music("%s/music/vanguard.wav" % asset_root, _vanguard_theme(), true)
	_write_music("%s/music/vesper.wav" % asset_root, _vesper_theme(), true)
	_write_music("%s/music/thalassa.wav" % asset_root, _thalassa_theme(), true)
	_write_music("%s/music/gravebound.wav" % asset_root, _gravebound_theme(), true)
	_write_music("%s/music/lumen.wav" % asset_root, _lumen_theme(), true)
	_write_sfx("%s/sfx/click.wav" % asset_root, _tone(0.08, 880.0, 0.25, 0.0))
	_write_sfx("%s/sfx/laser.wav" % asset_root, _sweep(0.35, 1200.0, 180.0, 0.32))
	_write_sfx("%s/sfx/explosion.wav" % asset_root, _noise(0.65, 0.38))
	_write_sfx("%s/sfx/nuke.wav" % asset_root, _sweep(1.2, 180.0, 32.0, 0.45))
	_write_sfx("%s/sfx/eel.wav" % asset_root, _sweep(0.28, 420.0, 90.0, 0.28))
	# Dedicated per-weapon, tactical event, and robotic voice-bark SFX.
	_write_sfx("%s/sfx/weapon_kinetic.wav" % asset_root, _sfx_kinetic())
	_write_sfx("%s/sfx/weapon_explosive.wav" % asset_root, _sfx_explosive())
	_write_sfx("%s/sfx/weapon_energy.wav" % asset_root, _sfx_energy())
	_write_sfx("%s/sfx/weapon_emp.wav" % asset_root, _sfx_emp())
	_write_sfx("%s/sfx/weapon_thermal.wav" % asset_root, _sfx_thermal())
	_write_sfx("%s/sfx/weapon_toxic.wav" % asset_root, _sfx_toxic())
	_write_sfx("%s/sfx/unit_explode.wav" % asset_root, _sfx_unit_explode())
	_write_sfx("%s/sfx/building_explode.wav" % asset_root, _sfx_building_explode())
	_write_sfx("%s/sfx/order_move.wav" % asset_root, _sfx_chirp_seq([660.0, 880.0], 0.055, 0.24))
	_write_sfx("%s/sfx/order_attack.wav" % asset_root, _sfx_chirp_seq([520.0, 740.0, 980.0], 0.05, 0.26))
	_write_sfx("%s/sfx/build_complete.wav" % asset_root, _sfx_chirp_seq([392.0, 523.25, 659.25], 0.08, 0.28))
	_write_sfx("%s/sfx/tech_up.wav" % asset_root, _sfx_chirp_seq([440.0, 554.37, 659.25, 880.0], 0.09, 0.30))
	_write_sfx("%s/sfx/sonar_ping.wav" % asset_root, _sfx_sonar_ping())
	_write_sfx("%s/sfx/capture.wav" % asset_root, _sfx_chirp_seq([330.0, 440.0, 660.0], 0.09, 0.28))
	_write_sfx("%s/sfx/alert_under_attack.wav" % asset_root, _sfx_alert())
	_write_sfx("%s/sfx/bark_confirm.wav" % asset_root, _sfx_robot_bark([220.0, 260.0], [720.0, 1450.0], 0.22))
	_write_sfx("%s/sfx/bark_engage.wav" % asset_root, _sfx_robot_bark([190.0, 240.0, 175.0], [640.0, 1280.0], 0.28))
	_write_sfx("%s/sfx/bark_alert.wav" % asset_root, _sfx_robot_bark([290.0, 210.0, 290.0], [880.0, 1820.0], 0.32))
	_write_sfx("%s/sfx/bark_ready.wav" % asset_root, _sfx_robot_bark([205.0, 245.0, 285.0], [760.0, 1620.0], 0.26))
	print("Generated 10 music beds and 24 SFX/bark clips.")
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

func _sfx_kinetic() -> PackedFloat32Array:
	var seconds := 0.11
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1101
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-32.0 * t)
		var snap := rng.randf_range(-1.0, 1.0) * 0.55 + sin(TAU * (320.0 - 180.0 * t / seconds) * t) * 0.45
		out.append(snap * 0.34 * env)
	return out

func _sfx_explosive() -> PackedFloat32Array:
	var seconds := 0.26
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x2202
	var phase := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var hz := 145.0 * exp(-9.0 * t) + 38.0
		phase += hz / float(SAMPLE_RATE)
		var env := exp(-10.0 * t)
		var s := sin(TAU * phase) * 0.65 + rng.randf_range(-1.0, 1.0) * 0.35 * exp(-16.0 * t)
		out.append(s * 0.42 * env)
	return out

func _sfx_energy() -> PackedFloat32Array:
	var seconds := 0.18
	var out := PackedFloat32Array()
	var phase := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var hz := 1550.0 * exp(-10.0 * t) + 280.0
		phase += hz / float(SAMPLE_RATE)
		var env := exp(-14.0 * t)
		var s := sin(TAU * phase) * 0.7 + sin(TAU * phase * 2.0) * 0.3
		out.append(s * 0.32 * env)
	return out

func _sfx_emp() -> PackedFloat32Array:
	var seconds := 0.28
	var out := PackedFloat32Array()
	var phase := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var hz := 640.0 * exp(-4.5 * t) + sin(TAU * 42.0 * t) * 95.0
		phase += maxf(40.0, hz) / float(SAMPLE_RATE)
		var env := pow(1.0 - t / seconds, 1.3)
		out.append(sin(TAU * phase) * 0.32 * env)
	return out

func _sfx_thermal() -> PackedFloat32Array:
	var seconds := 0.24
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4404
	var lp := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		lp = lp * 0.78 + rng.randf_range(-1.0, 1.0) * 0.22
		var env := sin(PI * clampf(t / seconds, 0.0, 1.0))
		out.append((lp * 0.75 + sin(TAU * 130.0 * t) * 0.25) * 0.36 * env)
	return out

func _sfx_toxic() -> PackedFloat32Array:
	var seconds := 0.22
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5505
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var bubble := sin(TAU * (310.0 + sin(TAU * 28.0 * t) * 140.0) * t) * 0.45
		var hiss := rng.randf_range(-1.0, 1.0) * 0.55
		var env := pow(1.0 - t / seconds, 1.4)
		out.append((bubble + hiss) * 0.28 * env)
	return out

func _sfx_unit_explode() -> PackedFloat32Array:
	var seconds := 0.42
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x6606
	var phase := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (120.0 * exp(-7.0 * t) + 34.0) / float(SAMPLE_RATE)
		var env := pow(1.0 - t / seconds, 1.8)
		var s := sin(TAU * phase) * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		out.append(s * 0.40 * env)
	return out

func _sfx_building_explode() -> PackedFloat32Array:
	var seconds := 0.78
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x7707
	var phase := 0.0
	var lp := 0.0
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		phase += (88.0 * exp(-4.0 * t) + 26.0) / float(SAMPLE_RATE)
		lp = lp * 0.85 + rng.randf_range(-1.0, 1.0) * 0.15
		var burst2 := exp(-14.0 * absf(t - 0.18)) * 0.35
		var env := pow(1.0 - t / seconds, 1.4)
		out.append(clampf((sin(TAU * phase) * 0.5 + lp * 0.5 + burst2) * 0.48 * env, -0.95, 0.95))
	return out

func _sfx_chirp_seq(freqs: Array, step_sec: float, amp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step_frames := maxi(1, int(step_sec * float(SAMPLE_RATE)))
	for f_val in freqs:
		var hz := float(f_val)
		for i in range(step_frames):
			var t := float(i) / float(SAMPLE_RATE)
			var u := float(i) / float(step_frames)
			var env := minf(u * 12.0, 1.0) * pow(1.0 - u, 1.2)
			var s := sin(TAU * hz * t) * 0.75 + sin(TAU * hz * 2.0 * t) * 0.25
			out.append(s * amp * env)
	return out

func _sfx_sonar_ping() -> PackedFloat32Array:
	var seconds := 0.58
	var out := PackedFloat32Array()
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var env := minf(t * 140.0, 1.0) * exp(-5.8 * t)
		var s := sin(TAU * 1320.0 * t) * 0.8 + sin(TAU * 2642.0 * t) * 0.2
		out.append(s * 0.36 * env)
	return out

func _sfx_alert() -> PackedFloat32Array:
	var seconds := 0.36
	var out := PackedFloat32Array()
	for i in range(int(seconds * float(SAMPLE_RATE))):
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := 1.0 if fmod(t, 0.18) < 0.12 else 0.0
		var hz := 780.0 if fmod(t, 0.18) < 0.06 else 540.0
		var s := sin(TAU * hz * t) * 0.7 + sin(TAU * hz * 3.0 * t) * 0.2
		out.append(s * 0.30 * pulse)
	return out

func _sfx_robot_bark(pitches: Array, formants: Array, seconds: float) -> PackedFloat32Array:
	# Synthesizes a compact robotic vocoder bark via pulse-train excitation
	# modulated through two metallic formant resonances.
	var out := PackedFloat32Array()
	var total := maxi(1, int(seconds * float(SAMPLE_RATE)))
	var seg := maxi(1, int(float(total) / float(maxi(1, pitches.size()))))
	var f1 := float(formants[0])
	var f2 := float(formants[1])
	for i in range(total):
		var t := float(i) / float(SAMPLE_RATE)
		var idx := mini(pitches.size() - 1, int(float(i) / float(seg)))
		var f0 := float(pitches[idx])
		var local_u := fmod(float(i), float(seg)) / float(seg)
		var env := sin(PI * clampf(local_u, 0.0, 1.0)) * pow(1.0 - float(i) / float(total), 0.5)
		var carrier := sin(TAU * f0 * t) + 0.5 * sin(TAU * f0 * 2.0 * t) + 0.3 * sin(TAU * f0 * 3.0 * t)
		var mod := 0.6 * sin(TAU * f1 * t) + 0.4 * sin(TAU * f2 * t)
		var sample := (carrier * 0.45 + carrier * mod * 0.55) * 0.24 * env
		out.append(clampf(sample, -0.9, 0.9))
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

func _vesper_theme() -> PackedFloat32Array:
	# Dominion begins above: eerie Lydian UFO shimmer, wobbling theremin lead & saucer hum.
	var buf := _blank_loop()
	var arp := ["C5", "E5", "F#5", "B5", "G5", "F#5", "E5", "D5"]
	for bar in range(5):
		var base := float(bar) * 2.0
		for step in range(8):
			_add_voice(buf, base + float(step) * 0.25, 0.36, _hz(arp[step]), 0.12,
				[[1.0, 1.0], [2.0, 0.25], [3.5, 0.12]], 0.012, 0.28, 0.008)
	# Continuous oscillating saucer vibrato bed (exact loop-quantized LFO)
	var carrier_a := _q(_hz("C3"))
	var carrier_b := _q(_hz("F#3"))
	var lead_notes := ["B5", "A5", "F#5", "G5", "E5"]
	for i in range(FRAMES):
		var t := float(i) / float(SAMPLE_RATE)
		var wob := sin(TAU * 0.6 * t) * 0.5 + 0.5
		var vib := sin(TAU * 5.0 * t) * 0.012
		var saucer := (sin(TAU * carrier_a * t + vib * 8.0) * 0.16
			+ sin(TAU * carrier_b * t - vib * 6.0) * 0.11 * (0.4 + 0.6 * wob))
		buf[i] = buf[i] + saucer
	for idx in range(lead_notes.size()):
		var f := _hz(lead_notes[idx])
		_add_voice(buf, float(idx) * 2.0 + 0.2, 1.65, f, 0.14,
			[[1.0, 1.0], [2.0, 0.15]], 0.28, 0.55, 0.011)
	return buf

func _thalassa_theme() -> PackedFloat32Array:
	# The sea remembers its masters: deep D-dorian abyssal brass swells & sunken bells.
	var buf := _blank_loop()
	var chords := [
		["D2", "A2", "D3", "F3"],
		["C2", "G2", "C3", "E3"],
		["B1", "F#2", "B2", "D3"],
		["A1", "E2", "A2", "C3"],
	]
	for bar in range(chords.size()):
		var base := float(bar) * 2.5
		for p in chords[bar]:
			_add_voice(buf, base, 2.45, _hz(String(p)), 0.14,
				[[1.0, 1.0], [2.0, 0.42], [3.0, 0.22], [4.0, 0.10]], 0.45, 0.85, -0.003)
	var bells := ["D4", "A4", "F4", "E4", "C4", "G4", "B3", "A4"]
	for i in range(bells.size()):
		_add_voice(buf, float(i) * 1.25 + 0.15, 1.4, _hz(bells[i]), 0.15,
			[[1.0, 1.0], [2.0, 0.35], [2.76, 0.22], [4.07, 0.10]], 0.008, 1.25)
	for i in range(8):
		_add_kick(buf, float(i) * 1.25, 0.38 if i % 2 == 0 else 0.22)
	return buf

func _gravebound_theme() -> PackedFloat32Array:
	# The fallen still march: heavy C-phrygian funeral dirge, crypt organ & bone rattle.
	var buf := _blank_loop()
	var march := ["C2", "C2", "C#2", "C2", "G1", "C2", "G#1", "G1"]
	for repeat in range(4):
		for i in range(march.size()):
			var t := float(repeat * march.size() + i) * (LOOP_SECONDS / 32.0)
			_add_voice(buf, t, 0.29, _hz(march[i]), 0.21,
				[[1.0, 1.0], [2.0, 0.55], [3.0, 0.30], [5.0, 0.14]], 0.008, 0.20)
	# Slow funeral bass drums + hollow crypt organ fifths
	for i in range(16):
		var start := float(i) * (LOOP_SECONDS / 16.0)
		_add_kick(buf, start, 0.62 if i % 4 == 0 else 0.36)
		if i % 2 == 1:
			_add_voice(buf, start + 0.15, 0.14, 1480.0 + float(i % 3) * 210.0, 0.06,
				[[1.0, 1.0], [2.31, 0.65], [3.9, 0.35]], 0.002, 0.12)
	for bar in range(2):
		var organ := ["C3", "G3", "C#4"] if bar == 0 else ["C3", "G3", "D#4"]
		for p in organ:
			_add_voice(buf, float(bar) * 5.0, 4.92, _hz(p), 0.11,
				[[1.0, 1.0], [2.0, 0.45], [3.0, 0.25], [4.0, 0.12]], 0.35, 0.75, 0.003)
	return buf

func _lumen_theme() -> PackedFloat32Array:
	# We saw you coming: cryptic A harmonic-minor baroque plucks, choir pad & clockwork pulse.
	var buf := _blank_loop()
	var motif := ["A3", "C4", "E4", "G#4", "A4", "E4", "F4", "E4",
		"D4", "F4", "A4", "G#4", "E4", "B3", "C4", "E4"]
	var step := LOOP_SECONDS / 32.0
	for repeat in range(2):
		for i in range(motif.size()):
			var start := float(repeat * motif.size() + i) * step
			_add_voice(buf, start, 0.38, _hz(motif[i]), 0.17,
				[[1.0, 1.0], [2.0, 0.58], [3.0, 0.35], [4.0, 0.18], [6.0, 0.08]],
				0.003, 0.32)
	# Mysterious veiled choir pad + subtle clockwork escapement ticks
	for p in ["A2", "E3", "C4"]:
		_add_voice(buf, 0.0, 9.95, _hz(p), 0.10,
			[[1.0, 1.0], [2.0, 0.25], [3.0, 0.10]], 0.7, 0.9, 0.004)
	for i in range(40):
		_add_voice(buf, float(i) * 0.25, 0.06, 2640.0 if i % 2 == 0 else 3120.0, 0.028,
			[[1.0, 1.0], [2.9, 0.28]], 0.001, 0.05)
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
