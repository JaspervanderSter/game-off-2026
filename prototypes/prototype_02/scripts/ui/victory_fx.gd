extends RefCounted
## Screen-space victory particles, drawn behind the crown and replay button.

enum Kind { CONFETTI, STREAMER, STAR, SPARK }

const COLORS := [
	Color("#ffd36b"), Color("#fa778f"), Color("#7de6db"),
	Color("#bd9bff"), Color("#ffa86c"),
]

class Particle:
	var kind: Kind
	var origin: Vector2
	var velocity: Vector2
	var delay: float
	var lifetime: float
	var size: float
	var spin: float
	var color: Color

var age := 0.0
var _particles: Array[Particle] = []
var _rng := RandomNumberGenerator.new()


func start(crown: Vector2) -> void:
	clear()
	# Two party poppers and a second wave of paper falling from above.
	for side in [-1, 1]:
		var origin := Vector2(250 if side == -1 else 1030, 535)
		for i in 60:
			var direction := Vector2(_rng.randf_range(0.15, 0.95) * -side, -1.0).normalized()
			_add(Kind.CONFETTI, origin, direction * _rng.randf_range(400, 770),
				_rng.randf_range(0.0, 0.26), _rng.randf_range(1.9, 3.2), _rng.randf_range(3, 7))
		for i in 12:
			var direction := Vector2(_rng.randf_range(0.25, 0.85) * -side, -1.0).normalized()
			_add(Kind.STREAMER, origin, direction * _rng.randf_range(370, 650),
				_rng.randf_range(0.08, 0.48), _rng.randf_range(1.7, 2.7), _rng.randf_range(12, 23))
	for i in 72:
		_add(Kind.CONFETTI, Vector2(_rng.randf_range(35, 1245), -12),
			Vector2(_rng.randf_range(-42, 42), _rng.randf_range(55, 110)),
			_rng.randf_range(0.28, 2.3), _rng.randf_range(2.5, 3.6), _rng.randf_range(2, 5))
	# A golden burst around the crown, followed by twinkling stars above it.
	for i in 44:
		var direction := Vector2.from_angle(TAU * i / 44.0 + _rng.randf_range(-0.06, 0.06))
		_add(Kind.SPARK, crown + direction * 48, direction * _rng.randf_range(120, 370),
			_rng.randf_range(0.0, 0.18), _rng.randf_range(0.38, 0.85), _rng.randf_range(9, 21))
	for i in 38:
		var offset := Vector2(_rng.randf_range(-240, 240), _rng.randf_range(-82, 90))
		_add(Kind.STAR, crown + offset, Vector2(offset.x * 0.2, _rng.randf_range(-83, -34)),
			_rng.randf_range(0.04, 1.1), _rng.randf_range(0.65, 1.55), _rng.randf_range(4, 12))


func _add(kind: Kind, origin: Vector2, velocity: Vector2, delay: float, lifetime: float, size: float) -> void:
	var particle := Particle.new()
	particle.kind = kind
	particle.origin = origin
	particle.velocity = velocity
	particle.delay = delay
	particle.lifetime = lifetime
	particle.size = size
	particle.spin = _rng.randf_range(-9.0, 9.0)
	particle.color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
	_particles.append(particle)


func clear() -> void:
	age = 0.0
	_particles.clear()


func advance(dt: float) -> void:
	age = minf(age + dt, 6.0)
	if age >= 6.0:
		_particles.clear()


func draw(canvas: CanvasItem) -> void:
	for particle in _particles:
		var t := age - particle.delay
		if t < 0.0 or t >= particle.lifetime:
			continue
		var fade := 1.0 - smoothstep(0.58, 1.0, t / particle.lifetime)
		var color := Color(particle.color, fade)
		var size := particle.size
		var pos := particle.origin + particle.velocity * t
		match particle.kind:
			Kind.CONFETTI:
				var flutter := sin(t * 5.0 + particle.spin)
				pos += Vector2(flutter * 18.0, 135.0 * t * t)
				var width := size * (0.22 + 0.78 * absf(flutter))
				canvas.draw_set_transform(pos, particle.spin * t)
				canvas.draw_rect(Rect2(-width, -size * 0.5, width * 2.0, size), color)
				canvas.draw_set_transform(Vector2.ZERO)
			Kind.STREAMER:
				pos.y += 126.0 * t * t
				var points := PackedVector2Array()
				for i in 13:
					var wave := Vector2(sin(i * 0.8 + t * 7.0) * size * 0.42, i * size * 0.2)
					points.append(pos + wave.rotated(sin(particle.spin + t * 2.5)))
				canvas.draw_polyline(points, Color(color, fade * 0.85), 3.0, true)
			Kind.STAR:
				var twinkle := sin(PI * t / particle.lifetime)
				Icons.star(canvas, pos, size * twinkle, Color(color.lightened(0.4), fade * twinkle))
			Kind.SPARK:
				var tail := particle.velocity.normalized() * size * fade
				canvas.draw_line(pos - tail, pos, Color(Icons.GOLD, fade * 0.8), 2.4, true)
				canvas.draw_circle(pos, 2.0 * fade, Color(1.0, 0.97, 0.8, fade), true)
