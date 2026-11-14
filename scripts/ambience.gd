extends AudioStreamPlayer
class_name IndustrialAmbience

var phase_a: float = 0.0
var phase_b: float = 0.0
var phase_c: float = 0.0
var phase_d: float = 0.0
var pulse_phase: float = 0.0
var modulation_phase: float = 0.0
var noise_state: float = 0.0
var playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.42
	stream = generator
	bus = "Music"
	volume_db = -25.0
	play()

func _process(_delta: float) -> void:
	if not playing:
		return
	if playback == null:
		playback = get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var rate := 22050.0
	for i in range(frames):
		var slow_breath := 0.62 + 0.38 * sin(modulation_phase)
		var sub_drone := sin(phase_a) * 0.34
		var dark_interval := sin(phase_b + sin(modulation_phase * 0.23) * 0.16) * 0.16
		var upper_harmonic := sin(phase_c) * 0.075
		var metallic_overtones := sin(phase_d) * (0.018 + absf(sin(modulation_phase * 0.31)) * 0.024)
		var heartbeat := maxf(0.0, sin(pulse_phase)) * maxf(0.0, sin(pulse_phase * 0.48)) * 0.045
		noise_state = lerpf(noise_state, randf_range(-1.0, 1.0), 0.012)
		var sample := (sub_drone + dark_interval + upper_harmonic + metallic_overtones + heartbeat + noise_state * 0.018) * slow_breath * 0.060
		buffer[i] = Vector2(sample, sample)
		phase_a = fmod(phase_a + TAU * 38.9 / rate, TAU)
		phase_b = fmod(phase_b + TAU * 46.3 / rate, TAU)
		phase_c = fmod(phase_c + TAU * 83.1 / rate, TAU)
		phase_d = fmod(phase_d + TAU * 129.7 / rate, TAU)
		pulse_phase = fmod(pulse_phase + TAU * 1.15 / rate, TAU)
		modulation_phase = fmod(modulation_phase + TAU * 0.075 / rate, TAU)
	playback.push_buffer(buffer)

func stop_ambience() -> void:
	stop()
	playback = null
