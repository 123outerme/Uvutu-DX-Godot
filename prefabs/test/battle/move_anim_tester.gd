extends Node2D

signal combatant_finished_moving
signal combatants_play_hit
signal combatant_finished_animating

@export var moveAnimation: MoveAnimation = null
@export var playSurge: bool = false
@export var itemSprite: Texture2D = null

@onready var userNode: CombatantNode = get_node('UserNode')
@onready var targetNode: CombatantNode = get_node('TargetNode')
@onready var button: Button = get_node('Button')

@onready var globalMarker: Marker2D = get_node('GlobalMarker')
@onready var userTeamMarker: Marker2D = get_node('UserTeamMarker')
@onready var enemyTeamMarker: Marker2D = get_node('EnemyTeamMarker')

const moveSpriteScene = preload('res://prefabs/battle/move_sprite.tscn')

func _ready():
	SceneLoader.audioHandler = get_node('AudioHandler')
	userNode.load_combatant_node()
	targetNode.load_combatant_node()

func _on_button_pressed():
	button.disabled = true
	userNode.play_animation(moveAnimation.combatantAnimation)
	userNode.play_particles(moveAnimation.userParticlePreset)
	userNode.moveSpriteTargets = [targetNode]
	userNode.useItemSprite = itemSprite
	userNode.play_move_sprites(moveAnimation.surgeMoveSprites if playSurge else moveAnimation.chargeMoveSprites)
	targetNode.play_particles(moveAnimation.targetsParticlePreset)
	if moveAnimation.makesContact:
		userNode.tween_to(targetNode.onAttackMarker.global_position)
		userNode.move_animation_callback(_move_tween_done)
	else:
		userNode.move_animation_callback(_move_tween_done)
		combatant_finished_moving.emit()
		
func _move_tween_done():
	button.disabled = false

func _on_swap_button_pressed():
	var temp = userNode
	userNode = targetNode
	targetNode = temp
