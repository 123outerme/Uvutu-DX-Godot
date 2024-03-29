extends StatusEffect
class_name Bleed

const PERCENT_DAMAGE_DICT: Dictionary = {
	Potency.NONE: 0.0,
	Potency.WEAK: 0.1,
	Potency.STRONG: 0.15,
	Potency.OVERWHELMING: 0.2
}

func _init(
	i_potency = Potency.NONE,
	i_turnsLeft = 0,
):
	super(Type.BLEED, i_potency, i_turnsLeft)

func get_bleed_damage(combatant: Combatant) -> int:
	return roundi(combatant.stats.maxHp * Bleed.PERCENT_DAMAGE_DICT[potency])

func apply_status(combatant: Combatant, allCombatants: Array[Combatant], timing: BattleCommand.ApplyTiming) -> Array[Combatant]:
	var dealtDmgCombatants: Array[Combatant] = []
	if timing == BattleCommand.ApplyTiming.AFTER_ROUND:
		combatant.currentHp = max(combatant.currentHp - get_bleed_damage(combatant), 0)
		dealtDmgCombatants = [combatant]
	dealtDmgCombatants.append_array(super.apply_status(combatant, allCombatants, timing))
	return dealtDmgCombatants
	
func get_status_effect_str(combatant: Combatant, allCombatants: Array[Combatant], timing: BattleCommand.ApplyTiming) -> String:
	if timing == BattleCommand.ApplyTiming.AFTER_ROUND:
		return combatant.disp_name() + ' takes ' + str(get_bleed_damage(combatant)) + ' bleed damage from ' + status_effect_to_string() + '!'
	return ''

func copy() -> StatusEffect:
	return Bleed.new(
		potency,
		turnsLeft
	)
