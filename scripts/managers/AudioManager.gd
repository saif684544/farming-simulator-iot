extends Node
## Procedurally synthesised audio. No audio files are shipped: short seamless
## loops are generated once at startup (small download for web builds) and
## shared by all players. Audio is optional - every call is safe if muted.

const RATE := 22050

var _streams: Dictionary = {}
var _ui_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	_streams["click"] = _make_click()
	_streams["beep"] = _make_beep(false)
	_streams["beep_off"] = _make_beep(true)
	_streams["ambient"] = _make_ambient()
	_streams["water"] = _make_water()
	_streams["pump"] = _make_pump()
	_streams["fan"] = _make_fan()
	_streams["siren"] = _make_siren()
	_streams["smoke_beep"] = _make_smoke_beep()
	_ui_player = AudioStreamPlayer.new()
	_ui_player.max_polyphony = 4
	add_child(_ui_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = _streams["ambient"]
	_ambient_player.volume_db = -14.0
	add_child(_ambient_player)


func get_stream(key: String) -> AudioStream:
	return _streams.get(key)


func play_ui(key: String = "click", volume_db := -8.0) -> void:
	if not _streams.has(key):
		return
	_ui_player.stream = _streams[key]
	_ui_player.volume_db = volume_db
	_ui_player.play()


func start_ambient() -> void:
	if not _ambient_player.playing:
		_ambient_player.play()


## Create a positional looping player for a device (pump, fan, sprinklers).
func make_3d_player(key: String, parent: Node3D, volume_db := 0.0, max_distance := 25.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams.get(key)
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 4.0
	parent.add_child(p)
	return p


# ------------------------------------------------------------ synthesis ---

func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Crossfade the end of a loop into its start so it repeats without clicks.
func _seamless(s: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := s.size()
	var out := PackedFloat32Array()
	out.resize(n - fade)
	for i in n - fade:
		out[i] = s[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = s[n - fade + i] * (1.0 - t) + s[i] * t
	return out


func _make_click() -> AudioStreamWAV:
	var n := int(RATE * 0.045)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 1800.0 * t) * exp(-t * 110.0) * 0.5
	return _wav(s, false)


func _make_beep(descending: bool) -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if (t < 0.1) != descending else 1320.0
		var env := minf(t * 200.0, 1.0) * exp(-fmod(t, 0.11) * 18.0)
		s[i] = sin(TAU * f * t) * env * 0.35
	return _wav(s, false)


func _make_ambient() -> AudioStreamWAV:
	# Soft wind (filtered noise with slow swells) plus a few bird chirps.
	var dur := 8.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := _rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		var swell := 0.55 + 0.45 * sin(TAU * t / dur * 2.0) * sin(TAU * t / dur)
		s[i] = lp2 * 6.0 * swell
	var chirps := [[1.3, 3200.0], [1.45, 3600.0], [4.2, 2800.0], [4.32, 3100.0], [4.44, 3400.0], [6.6, 4000.0]]
	for c in chirps:
		var start := int(c[0] * RATE)
		var cn := int(0.09 * RATE)
		for j in cn:
			if start + j >= n:
				break
			var tt := float(j) / RATE
			var f: float = c[1] + 1800.0 * tt / 0.09
			s[start + j] += sin(TAU * f * tt) * sin(PI * tt / 0.09) * 0.12
	return _wav(_seamless(s, int(RATE * 0.5)), true)


func _make_water() -> AudioStreamWAV:
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var lp := 0.0
	for i in n:
		var white := _rng.randf_range(-1.0, 1.0)
		var hp := white - prev
		prev = white
		lp += (hp - lp) * 0.45
		s[i] = lp * 0.35 * (0.85 + 0.15 * _rng.randf())
	return _wav(_seamless(s, int(RATE * 0.2)), true)


func _make_pump() -> AudioStreamWAV:
	# 1 second is an integer number of cycles for all partials -> seamless.
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.1
		s[i] = (sin(TAU * 50.0 * t) * 0.35 + sin(TAU * 100.0 * t) * 0.25 + sin(TAU * 150.0 * t) * 0.1) * (0.85 + 0.15 * sin(TAU * 6.0 * t)) + lp * 0.25
	return _wav(s, true)


func _make_fan() -> AudioStreamWAV:
	var n := RATE * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.08
		s[i] = lp * 1.6 * (0.75 + 0.25 * sin(TAU * 14.0 * t)) + sin(TAU * 28.0 * t) * 0.08
	return _wav(_seamless(s, int(RATE * 0.2)), true)


func _make_siren() -> AudioStreamWAV:
	# Two-tone (hi-lo) outdoor siren; 1 s per tone pair, phase-continuous.
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 960.0 if t < 0.5 else 720.0
		phase += TAU * f / RATE
		var sq := 1.0 if sin(phase) > 0.0 else -1.0
		s[i] = (sin(phase) * 0.6 + sq * 0.12) * 0.32
	return _wav(s, true)


func _make_smoke_beep() -> AudioStreamWAV:
	# Temporal-3 pattern used by smoke alarms: three beeps, then a pause.
	var n := int(RATE * 2.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := t < 1.5 and fmod(t, 0.5) < 0.3
		s[i] = sin(TAU * 3100.0 * t) * 0.22 if on else 0.0
	return _wav(s, true)
