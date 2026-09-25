class_name Sfx
extends Node
## All game audio, synthesised in code (no audio files):
## - sound effects rendered once at startup into AudioStreamWAVs,
## - a looping synthwave track rendered on a worker thread (see _render_music),
## - "SFX" (with space reverb) and "Music" (with a mood low-pass) buses,
##   and a limiter on Master.

enum Wave { SINE, SQUARE, SAW, TRI, NOISE }

const RATE := 22050
const VOICES := 16
const BPM := 116.0

## Sounds that still play during the attract-mode demo on the title screen.
const UI_SOUNDS: Array[StringName] = [&"launch", &"blip", &"record"]
## Per-sound playback gain in dB (everything is normalised when rendered).
const GAIN := {
	&"turn": -20.0, &"spawn": -8.0, &"warn": -6.0, &"eat": -3.0, &"bonus": -5.0,
	&"zap": -6.0, &"wrap": -6.0, &"blip": -8.0,
}

var game: Game
var music_enabled := true

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_lowpass: AudioEffectLowPassFilter
var _task := -1
## Filled by the worker thread; handed to the main thread when it finishes.
var _built: Dictionary[StringName, AudioStreamWAV] = {}
var _built_music: AudioStreamWAV
var _effects_ready := false
## Set on exit so the worker stops early and the node isn't freed under it.
var _cancelled := false


func _ready() -> void:
	_setup_buses()
	_load_settings()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.volume_db = -7.0
	add_child(_music)

	# Synthesis takes a few seconds of GDScript: keep it off the main thread.
	# Effects are published first (~1 s), the music track when it's done.
	_task = WorkerThreadPool.add_task(_synthesise, false, "audio synthesis")


func _synthesise() -> void:
	_build_effects()
	_effects_ready = true
	var music := _render_music()
	if not _cancelled:
		_built_music = _to_wav(music, true)


func _exit_tree() -> void:
	# Streams still playing at shutdown are otherwise reported as leaked.
	_music.stop()
	_music.stream = null
	for p in _players:
		p.stop()
		p.stream = null
	if _task != -1:
		_cancelled = true
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_built_music = null
	_built.clear()
	_streams.clear()


func _process(delta: float) -> void:
	if _effects_ready and _streams.is_empty():
		_streams = _built
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_music.stream = _built_music
		if music_enabled:
			_music.play()

	if game == null:
		return
	# Muffled on the menu / pause / game over, full range while playing;
	# the track speeds up under Hyperdrive and drags under Time Warp.
	var playing := game.state == Game.State.PLAYING
	var cutoff := 16000.0 if playing else 700.0
	var pitch := 1.0
	if playing and game.powerups.has(&"hyperdrive"):
		pitch = 1.08
	elif playing and game.powerups.has(&"timewarp"):
		pitch = 0.82
	var w := 1.0 - exp(-delta * 4.0)
	_music_lowpass.cutoff_hz = exp(lerpf(log(_music_lowpass.cutoff_hz), log(cutoff), w))
	_music.pitch_scale = lerpf(_music.pitch_scale, pitch, w)


func play(sound: StringName, pitch := 1.0) -> void:
	if not _effects_ready:
		return
	if game != null and game.ai_mode and not UI_SOUNDS.has(sound):
		return
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = GAIN.get(sound, 0.0)
	p.play()


## Plays `sound` after `delay` seconds.
func play_later(sound: StringName, delay: float, pitch := 1.0) -> void:
	get_tree().create_timer(delay).timeout.connect(play.bind(sound, pitch))


func toggle_music() -> void:
	music_enabled = not music_enabled
	if music_enabled and _music.stream != null:
		_music.play()
	else:
		_music.stop()
	_save_settings()


# --- Buses & settings ----------------------------------------------------------

func _setup_buses() -> void:
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)

	for bus_name: StringName in [&"SFX", &"Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")

	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.7
	reverb.damping = 0.4
	reverb.wet = 0.18
	reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"SFX"), reverb)

	_music_lowpass = AudioEffectLowPassFilter.new()
	_music_lowpass.cutoff_hz = 700.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Music"), _music_lowpass)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Config.SAVE_PATH) == OK:
		music_enabled = bool(cfg.get_value("audio", "music", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Config.SAVE_PATH)
	cfg.set_value("audio", "music", music_enabled)
	cfg.save(Config.SAVE_PATH)


# --- Sound effects -------------------------------------------------------------

func _build_effects() -> void:
	var b: PackedFloat32Array

	# Eating: a bright two-voice "bloop" with a bell ping on top.
	b = _buf(0.3)
	_note(b, 0.0, 0.09, 520, 1100, Wave.SQUARE, 0.5, 0.002, 2.0, 0.0, 0.004, 0.45)
	_note(b, 0.03, 0.25, 1760, 1760, Wave.SINE, 0.45, 0.002, 3.0)
	_built[&"eat"] = _wav(b)

	b = _buf(0.35)
	_note(b, 0.0, 0.12, 1568, 1568, Wave.SINE, 0.5, 0.002, 2.5)
	_note(b, 0.07, 0.25, 2349, 2349, Wave.SINE, 0.5, 0.002, 3.0)
	_built[&"bonus"] = _wav(_echo(b, 0.09, 0.35))

	b = _buf(0.7)
	for i in 4:
		_note(b, i * 0.06, 0.3, _midi(76 + [0, 4, 7, 12][i]), 0, Wave.SQUARE, 0.35, 0.002, 2.0, 0.0, 0.006, 0.5)
	_built[&"combo"] = _wav(_echo(b, 0.12, 0.3))

	# Generic pickup, the orb appearing, a power-up running out / expiring.
	b = _buf(0.3)
	_note(b, 0.0, 0.28, 1320, 1980, Wave.SINE, 0.4, 0.05, 1.5, 12.0)
	_built[&"spawn"] = _wav(_echo(b, 0.1, 0.3))
	b = _buf(0.08)
	_note(b, 0.0, 0.07, 1480, 1480, Wave.SQUARE, 0.5, 0.002, 1.5, 0.0, 0.0, 0.5)
	_built[&"warn"] = _wav(b)
	b = _buf(0.35)
	_note(b, 0.0, 0.14, _midi(74), 0, Wave.TRI, 0.6, 0.003, 1.5)
	_note(b, 0.13, 0.2, _midi(67), 0, Wave.TRI, 0.6, 0.003, 2.0)
	_built[&"expire"] = _wav(b)

	_build_powerup_sounds()

	if _cancelled:
		return
	# Moment-to-moment feedback.
	b = _buf(0.03)
	_note(b, 0.0, 0.025, 220, 160, Wave.SINE, 0.8, 0.001, 2.0)
	_built[&"turn"] = _wav(b)
	b = _buf(0.18)
	_note(b, 0.0, 0.16, 2200, 400, Wave.SAW, 0.5, 0.001, 2.0, 0.0, 0.01, 0.6)
	_built[&"zap"] = _wav(b)
	b = _buf(0.4)
	_note(b, 0.0, 0.38, 180, 900, Wave.SINE, 0.5, 0.02, 1.5, 18.0)
	_note(b, 0.0, 0.3, 0, 0, Wave.NOISE, 0.25, 0.1, 1.5, 0.0, 0.0, 0.08)
	_built[&"wrap"] = _wav(b)

	# Shield breaking: glassy shatter over a falling tone.
	b = _buf(0.6)
	_note(b, 0.0, 0.45, 0, 0, Wave.NOISE, 0.6, 0.001, 3.0, 0.0, 0.0, 0.9)
	_note(b, 0.0, 0.5, 900, 150, Wave.SAW, 0.4, 0.002, 2.0, 0.0, 0.01, 0.3)
	for i in 5:
		_note(b, i * 0.03, 0.2, 2600 + i * 430, 0, Wave.SINE, 0.2, 0.001, 3.0)
	_built[&"shield"] = _wav(b)

	# Death: sub thump, filtered explosion and a long falling saw.
	b = _buf(1.4)
	_note(b, 0.0, 0.5, 120, 30, Wave.SINE, 0.9, 0.002, 2.0)
	_note(b, 0.0, 1.1, 0, 0, Wave.NOISE, 0.7, 0.002, 2.5, 0.0, 0.0, 0.12)
	_note(b, 0.05, 1.2, 440, 40, Wave.SAW, 0.35, 0.01, 1.5, 0.0, 0.01, 0.2)
	_built[&"death"] = _wav(_echo(b, 0.18, 0.3))

	# Launch: rising whoosh into a major chord.
	b = _buf(1.1)
	_note(b, 0.0, 0.5, 150, 1200, Wave.SAW, 0.3, 0.05, 1.0, 0.0, 0.01, 0.25)
	_note(b, 0.0, 0.5, 0, 0, Wave.NOISE, 0.25, 0.3, 1.0, 0.0, 0.0, 0.15)
	for m in [69, 73, 76, 81]:
		_note(b, 0.42, 0.6, _midi(m), 0, Wave.SQUARE, 0.18, 0.005, 2.0, 0.0, 0.006, 0.4)
	_built[&"launch"] = _wav(_echo(b, 0.14, 0.3))

	b = _buf(1.2)
	for i in 5:
		var m: int = [72, 76, 79, 84, 88][i]
		_note(b, i * 0.1, 0.5 if i < 4 else 0.7, _midi(m), 0, Wave.SQUARE, 0.3, 0.003, 2.0, 0.0, 0.006, 0.45)
	_built[&"record"] = _wav(_echo(b, 0.15, 0.35))

	b = _buf(0.06)
	_note(b, 0.0, 0.05, 660, 660, Wave.TRI, 0.7, 0.002, 1.5)
	_built[&"blip"] = _wav(b)


## One signature sound per power-up id (falls back to "powerup").
func _build_powerup_sounds() -> void:
	if _cancelled:
		return
	var b: PackedFloat32Array

	b = _buf(0.5)
	for i in 4:
		_note(b, i * 0.06, 0.25, _midi(72 + [0, 4, 7, 12][i]), 0, Wave.SQUARE, 0.35, 0.003, 2.0, 0.0, 0.006, 0.5)
	_built[&"powerup"] = _wav(_echo(b, 0.1, 0.3))

	b = _buf(0.7) # engine boost
	_note(b, 0.0, 0.6, 120, 1500, Wave.SAW, 0.5, 0.01, 1.2, 0.0, 0.012, 0.3)
	_note(b, 0.0, 0.6, 0, 0, Wave.NOISE, 0.35, 0.2, 1.2, 0.0, 0.0, 0.25)
	_built[&"hyperdrive"] = _wav(b)

	b = _buf(0.7) # ghostly warble
	_note(b, 0.0, 0.65, 500, 900, Wave.SINE, 0.6, 0.08, 1.2, 9.0)
	_note(b, 0.0, 0.65, 750, 1350, Wave.TRI, 0.25, 0.08, 1.2, 7.0)
	_built[&"phase"] = _wav(_echo(b, 0.12, 0.4))

	b = _buf(0.8) # deep pull
	_note(b, 0.0, 0.75, 420, 70, Wave.SINE, 0.8, 0.01, 1.0, 5.0)
	_note(b, 0.0, 0.75, 210, 35, Wave.SAW, 0.25, 0.01, 1.2, 0.0, 0.01, 0.15)
	_built[&"gravity"] = _wav(b)

	b = _buf(0.9) # tape slowing down
	_note(b, 0.0, 0.85, 1400, 180, Wave.TRI, 0.6, 0.005, 0.8)
	_note(b, 0.0, 0.85, 700, 90, Wave.SQUARE, 0.2, 0.005, 0.8, 0.0, 0.0, 0.3)
	_built[&"timewarp"] = _wav(_echo(b, 0.2, 0.3))

	b = _buf(0.9) # bright shimmering chord
	for i in 4:
		_note(b, i * 0.04, 0.8, _midi([72, 76, 79, 84][i]), 0, Wave.SINE, 0.3, 0.01, 2.0, 6.0)
	_built[&"shield_up"] = _wav(_echo(b, 0.1, 0.35))

	b = _buf(1.1) # explosion then sparkles
	_note(b, 0.0, 0.6, 0, 0, Wave.NOISE, 0.7, 0.002, 2.5, 0.0, 0.0, 0.2)
	_note(b, 0.0, 0.3, 90, 40, Wave.SINE, 0.7, 0.002, 2.0)
	for i in 7:
		_note(b, 0.15 + i * 0.07, 0.2, _midi(84 + [0, 7, 4, 12, 7, 16, 19][i]), 0, Wave.SINE, 0.3, 0.002, 2.5)
	_built[&"supernova"] = _wav(_echo(b, 0.11, 0.35))

	b = _buf(0.9) # swirl
	_note(b, 0.0, 0.85, 200, 1600, Wave.SINE, 0.5, 0.05, 1.0, 22.0)
	_note(b, 0.0, 0.85, 0, 0, Wave.NOISE, 0.2, 0.3, 1.0, 0.0, 0.0, 0.06)
	_built[&"wormhole"] = _wav(_echo(b, 0.15, 0.3))

	b = _buf(0.6) # crunchy shedding stutter
	for i in 6:
		_note(b, i * 0.07, 0.06, 500 - i * 60, 300 - i * 40, Wave.SQUARE, 0.4, 0.001, 1.5, 0.0, 0.0, 0.5)
		_note(b, i * 0.07, 0.05, 0, 0, Wave.NOISE, 0.3, 0.001, 2.0, 0.0, 0.0, 0.5)
	_built[&"molt"] = _wav(b)

	b = _buf(1.0) # fanfare
	for i in 3:
		_note(b, i * 0.12, 0.45 if i == 2 else 0.12, _midi([79, 84, 88][i]), 0, Wave.SQUARE, 0.35, 0.003, 1.5, 0.0, 0.006, 0.5)
	_note(b, 0.36, 0.5, _midi(76), 0, Wave.SAW, 0.2, 0.01, 1.5, 5.0, 0.008, 0.4)
	_built[&"surge"] = _wav(_echo(b, 0.13, 0.35))

	b = _buf(1.2) # crystal bell
	_note(b, 0.0, 1.1, 2093, 0, Wave.SINE, 0.45, 0.002, 2.5)
	_note(b, 0.0, 0.9, 3136 * 1.01, 0, Wave.SINE, 0.25, 0.002, 3.0)
	_note(b, 0.0, 0.6, 5274, 0, Wave.SINE, 0.12, 0.002, 3.5)
	_built[&"stasis"] = _wav(_echo(b, 0.17, 0.4))

	b = _buf(0.5) # laser charge and fire
	_note(b, 0.0, 0.15, 300, 2400, Wave.SAW, 0.3, 0.01, 0.5, 0.0, 0.01, 0.4)
	_note(b, 0.15, 0.3, 2400, 200, Wave.SAW, 0.5, 0.001, 1.5, 0.0, 0.01, 0.5)
	_built[&"lance"] = _wav(b)

	b = _buf(0.45) # dice roll
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		_note(b, i * 0.055, 0.05, _midi(72 + rng.randi_range(0, 14)), 0, Wave.SQUARE, 0.35, 0.001, 1.5, 0.0, 0.0, 0.5)
	_built[&"quantum"] = _wav(b)


# --- Music -------------------------------------------------------------------------

## An 8-bar A-minor synthwave loop: four-on-the-floor kick, snare, hats, a
## pumping saw bass, an echoing square arpeggio and a soft pad.
## Runs on a worker thread; only touches its own buffers.
func _render_music() -> PackedFloat32Array:
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var bars := 8
	var length := bar * bars
	var chords := [[45, 0], [41, 1], [48, 1], [43, 1], [45, 0], [41, 1], [43, 1], [40, 1]] # root midi, major?
	var mix := _buf(length + 2.0)
	var arp := _buf(length + 2.0)

	for c in bars:
		if _cancelled:
			return PackedFloat32Array()
		var t0 := c * bar
		var root: int = chords[c][0]
		var third := 4 if chords[c][1] == 1 else 3
		var tones := [0, third, 7, 12]

		for m in tones.slice(0, 3):
			_note(mix, t0, bar * 0.98, _midi(root + 12 + m), 0, Wave.SAW, 0.08, 0.35, 0.6, 0.0, 0.005, 0.09)
		for e in 8:
			var n := root + (12 if e % 2 == 1 else 0)
			_note(mix, t0 + e * beat / 2.0, beat * 0.45, _midi(n), 0, Wave.SAW, 0.32, 0.003, 1.2, 0.0, 0.0, 0.14)
		var pattern := [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 3, 1, 2]
		for s in 16:
			var m: int = tones[pattern[s]]
			_note(arp, t0 + s * beat / 4.0, beat * 0.22, _midi(root + 24 + m), 0, Wave.SQUARE, 0.15, 0.002, 1.8, 0.0, 0.0, 0.35)

		for q in 4:
			var bt := t0 + q * beat
			_note(mix, bt, 0.28, 150, 42, Wave.SINE, 0.4, 0.001, 2.5)
			if q % 2 == 1:
				_note(mix, bt, 0.18, 0, 0, Wave.NOISE, 0.16, 0.001, 2.5, 0.0, 0.0, 0.45)
				_note(mix, bt, 0.1, 210, 180, Wave.TRI, 0.2, 0.001, 2.0)
			_note(mix, bt + beat / 2.0, 0.04, 0, 0, Wave.NOISE, 0.07, 0.001, 2.0, 0.0, 0.0, 1.0)

	_echo(arp, beat * 0.75, 0.35)
	for i in arp.size():
		mix[i] += arp[i]
	# Fold the ringing tail back onto the start so the loop is seamless.
	var total := int(length * RATE)
	for i in range(total, mix.size()):
		mix[i - total] += mix[i]
	mix.resize(total)
	var peak := 0.001
	for v in mix:
		peak = maxf(peak, absf(v))
	var gain := 0.8 / peak
	for i in mix.size():
		mix[i] *= gain
	return mix


# --- Synthesis helpers -------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Adds one note into `buf`. f1 = 0 means no glide. Pitch glides
## exponentially from f0 to f1; the envelope is a linear attack then a
## (1 - t)^curve decay. `vibrato` is a rate in Hz (depth fixed), `detune` adds
## a second oscillator at f * (1 + detune), `lowpass` (0..1, 0 = off) is a
## one-pole filter coefficient.
static func _note(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: Wave,
		vol: float, attack := 0.005, curve := 2.0, vibrato := 0.0, detune := 0.0, lowpass := 0.0) -> void:
	var s0 := int(start * RATE)
	var count := mini(int(dur * RATE), buf.size() - s0)
	if f1 <= 0.0:
		f1 = f0
	var ratio := f1 / f0 if f0 > 0.0 else 1.0
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	var noise_state := s0 * 7919 + 1
	var attack_n := maxf(1.0, attack * RATE)
	for i in count:
		var t := float(i) / count
		var f := f0 * pow(ratio, t)
		if vibrato > 0.0:
			f *= 1.0 + 0.03 * sin(TAU * vibrato * i / RATE)
		phase += f / RATE
		var s: float
		if wave == Wave.NOISE:
			noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
			s = float(noise_state) / 0x3fffffff - 1.0
		else:
			s = _osc(wave, phase)
			if detune > 0.0:
				phase2 += f * (1.0 + detune) / RATE
				s = (s + _osc(wave, phase2)) * 0.5
		if lowpass > 0.0:
			lp += (s - lp) * lowpass
			s = lp
		var env := minf(1.0, i / attack_n) * pow(1.0 - t, curve)
		buf[s0 + i] += s * env * vol


static func _osc(wave: Wave, phase: float) -> float:
	var x := phase - floorf(phase)
	match wave:
		Wave.SQUARE:
			return 1.0 if x < 0.5 else -1.0
		Wave.SAW:
			return 2.0 * x - 1.0
		Wave.TRI:
			return 4.0 * absf(x - 0.5) - 1.0
	return sin(TAU * x)


## Feedback delay applied in place (the buffer should have room for the tail).
static func _echo(buf: PackedFloat32Array, delay: float, feedback: float) -> PackedFloat32Array:
	var d := int(delay * RATE)
	for i in range(d, buf.size()):
		buf[i] += buf[i - d] * feedback
	return buf


## Normalises to a common peak so every sound sits at a similar loudness.
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.85 / peak
	for i in samples.size():
		samples[i] *= gain
	return _to_wav(samples, false)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
