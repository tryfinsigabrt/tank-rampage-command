extends Control

@onready var visible_sprite: Sprite2D = %VisibleSprite
@onready var explored_sprite: Sprite2D = %ExploredSprite


func _ready() -> void:
	await get_tree().create_timer(0.2).timeout
	
	var fog_of_war:FogOfWar = get_parent() as FogOfWar
	if not fog_of_war:
		push_error("%s: Not added to fog of war parent" % name)
		return
	if not fog_of_war.enable:
		hide()
		return
		
	visible_sprite.texture = fog_of_war.visible_area_viewport.get_texture()
	explored_sprite.texture = fog_of_war.explored_area_viewport.get_texture()
