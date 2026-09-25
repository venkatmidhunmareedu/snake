class_name Sfx
extends Node
## Procedurally synthesised retro sound effects: no audio files needed.
## Each sound is rendered once at startup into a 16-bit AudioStreamWAV.

const RATE := 22050
const VOICES := 8

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = -10.0
		add_child(p)
		_players.append(p)

	_streams[&"eat"] = _render([_tone(0.09, 520, 1040, "square", 0.35)])
	_streams[&"combo"] = _render([_tone(0.06, 880, 880, "square", 0.3), _tone(0.06, 1175, 1175, "square", 0.3), _tone(0.12, 1760, 1760, "square", 0.3)])
	_streams[&"powerup"] = _render([
		_tone(0.06, 523, 523, "square", 0.3), _tone(0.06, 659, 659, "square", 0.3),
		_tone(0.06, 784, 784, "square", 0.3), _tone(0.25, 1047, 2093, "tri", 0.45),
	])
	_streams[&"spawn"] = _render([_tone(0.3, 1400, 2200, "sine", 0.18)])
	_streams[&"expire"] = _render([_tone(0.18, 700, 300, "tri", 0.35)])
	_streams[&"shield"] = _render([_tone(0.35, 500, 120, "saw", 0.45, 0.5)])
	_streams[&"death"] = _render([_tone(0.9, 440, 35, "saw", 0.5, 0.45)])
	_streams[&"launch"] = _render([_tone(0.45, 160, 1100, "sine", 0.4, 0.25)])
	_streams[&"blip"] = _render([_tone(0.05, 660, 660, "tri", 0.3)])


func play(sound: StringName, pitch := 1.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


## One note with an exponential pitch glide, optional noise, fast attack and
## quadratic decay. Returns raw samples in -1..1.
func _tone(duration: float, f0: float, f1: float, wave: String, volume: float, noise := 0.0) -> PackedFloat32Array:
	var n := int(RATE * duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += f0 * pow(f1 / f0, t) / RATE
		var x := fmod(phase, 1.0)
		var s: float
		match wave:
			"square":
				s = 1.0 if x < 0.5 else -1.0
			"saw":
				s = 2.0 * x - 1.0
			"tri":
				s = 4.0 * absf(x - 0.5) - 1.0
			_:
				s = sin(TAU * x)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := minf(1.0, i / (RATE * 0.004)) * pow(1.0 - t, 2.0)
		out[i] = s * env * volume
	return out


func _render(parts: Array[PackedFloat32Array]) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for part in parts:
		samples.append_array(part)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
