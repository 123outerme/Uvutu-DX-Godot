extends Resource
class_name OverworldEnemyData

@export var combatant: Combatant = null
@export var position: Vector2 = Vector2()
@export var disableMovement: bool = false
@export var encounter: EnemyEncounter = null

# NOTE: for saving data, the complete filepath comes from the EnemySpawner itself to preserve spawner state
# so all that needs to be used for save/load functionality is the save_path coming through

func _init(
	i_combatant = null,
	i_pos = Vector2(),
	i_disableMove = false,
	i_encounter = null,
):
	combatant = i_combatant
	position = i_pos
	disableMovement = i_disableMove
	encounter = i_encounter
