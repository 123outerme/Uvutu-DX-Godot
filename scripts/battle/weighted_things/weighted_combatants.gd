extends WeightedThing
class_name WeightedCombatant

@export var combatant: Combatant = null
@export var statAllocationStrategy: StatAllocationStrategy = null
@export var weightedEquipment: CombatantEquipment = null

func _init(i_weight = 0.0, i_combatant = null, i_statAllocStrat = null, i_weightedEquipment = null):
	super(i_weight)
	combatant = i_combatant
	statAllocationStrategy = i_statAllocStrat
	weightedEquipment = i_weightedEquipment
