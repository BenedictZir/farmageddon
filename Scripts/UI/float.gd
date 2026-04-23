extends Node2D

@export var amplitude: float = 20.0  # tinggi naik turun
@export var speed: float = 2.0       # kecepatan animasi

var time: float = 0.0
var start_y: float

func _ready():
	start_y = position.y

func _process(delta):
	time += delta * speed
	position.y = start_y + sin(time) * amplitude
