@tool
extends Node3D

@onready var _sign: MeshInstance3D = %SpeedLimit25Sign

enum SignType
{
	NO_PARKING = 0,
	STOP_LIGHT = 1,
	SPEED_LIMIT_25 = 2,
	SPEED_LIMIT_30 = 3,
	SPEED_LIMIT_55 = 4,
}

const _SIGN_TYPE_TO_MATERIAL: Dictionary[SignType, Material] = {
	(SignType.NO_PARKING) : preload("uid://dd3tnj0kwvvdq"),
	(SignType.STOP_LIGHT) : preload("uid://rx823tvchp81"),
	(SignType.SPEED_LIMIT_25) : preload("uid://5r85erjwmgkk"),
	(SignType.SPEED_LIMIT_30) : preload("uid://b37pju0ojdemy"),
	(SignType.SPEED_LIMIT_55) : preload("uid://dg2vrbkw6qals"),
}

@export
var sign_type:SignType = SignType.NO_PARKING:
	set(value):
		sign_type = value
		if is_node_ready():
			_apply_material()

func _ready() -> void:
	_apply_material()
	
func _apply_material() -> void:
	var material: Material = _SIGN_TYPE_TO_MATERIAL.get(sign_type)
	if material:
		_sign.material_override = material
