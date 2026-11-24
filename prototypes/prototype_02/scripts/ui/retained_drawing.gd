extends Node2D
## A retained canvas layer. Painting runs only on creation or invalidation;
## position, scale and modulation can change without rebuilding its geometry.
var paint: Callable
var paints := 0

static func make(parent: Node, painter: Callable) -> Node2D:
	var layer := preload("res://scripts/ui/retained_drawing.gd").new()
	layer.paint = painter
	parent.add_child(layer)
	return layer

func _draw() -> void:
	paints += 1
	paint.call(self)
