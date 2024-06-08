extends StatusEffect
class_name Confusion

var statChangesDict: Dictionary = {
	Potency.NONE: StatChanges.new(1, 1, 1, 1, 1),
	Potency.WEAK: StatChanges.new(1, 0.7, 1, 1, 1),
	Potency.STRONG: StatChanges.new(1, 0.6, 1, 1, 1),
	Potency.OVERWHELMING: StatChanges.new(1, 0.5, 1, 1, 1),
}

var reverseStatChangesDict: Dictionary = {
	Potency.NONE: StatChanges.new(1, 1, 1, 1, 1),
	Potency.WEAK: StatChanges.new(1, 1.3, 1, 1, 1),
	Potency.STRONG: StatChanges.new(1, 1.4, 1, 1, 1),
	Potency.OVERWHELMING: StatChanges.new(1, 1.5, 1, 1, 1),
}

const _icon: Texture2D = preload('res://graphics/ui/confusion.png')

func _init(
	i_potency = Potency.NONE,
	i_overwrites = false,
	i_turnsLeft = 0
):
	super(Type.CONFUSION, i_potency, i_overwrites, i_turnsLeft)

func apply_status(combatant: Combatant, allCombatants: Array[Combatant], timing: BattleCommand.ApplyTiming) -> Array[Combatant]:
	if timing == BattleCommand.ApplyTiming.BEFORE_DMG_CALC:
		combatant.statChanges.stack(statChangesDict[potency])
	if timing == BattleCommand.ApplyTiming.AFTER_DMG_CALC:
		combatant.statChanges.stack(reverseStatChangesDict[potency])
	return super.apply_status(combatant, allCombatants, timing)
	
func get_status_effect_str(combatant: Combatant, allCombatants: Array[Combatant], timing: BattleCommand.ApplyTiming) -> String:
	return ''

func get_status_effect_tooltip():
	return 'A combatant with Confusion suffers a temporary debuff to their Magic Attack stat.'

func get_icon() -> Texture2D:
	return _icon

func copy() -> StatusEffect:
	return Confusion.new(
		potency,
		overwritesOtherStatuses,
		turnsLeft
	)
