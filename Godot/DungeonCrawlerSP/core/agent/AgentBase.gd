extends Node
class_name AgentBase

const AgentMetaName = "agentRef"

var _units := SetWrapper.new()         setget deleted, getUnits
var _unitsInTree := []


func deleted(_a):
	assert(false)


func _init():
	_units.connect( "changed", self, "_updateActiveUnits" )


func addUnit( unit : UnitBase ):
	assert( unit )

	if unit.has_meta( AgentMetaName ):
		var agent : AgentBase = unit.get_meta( AgentMetaName ).get_ref()

		if agent != null:
			var removed = agent.removeUnit( unit )
			assert( removed == true )
			Debug.info( self, "Removed agent %s from unit %s" % [agent.name, unit.name] )

	_units.add( [unit] )
	unit.connect( "tree_entered", self, "_setActive",   [unit] )
	unit.connect( "tree_exited" , self, "_setInactive", [unit] )
	unit.connect( "predelete",    self, "removeUnit",   [unit] )
	if unit.is_inside_tree():
		_setActive( unit )

	unit.set_meta( AgentMetaName, weakref(self) )


func removeUnit( unit : UnitBase ) -> bool:
	if not _units.container().has( unit ):
		Debug.info( self, "Agent %s has no unit named %s" % [self.name, unit.name] )
		return false

	_units.remove( [unit] )
	unit.set_meta( AgentMetaName, null )
	return true


func _setActive( unit : UnitBase ):
	if not _unitsInTree.has( unit ):
		_unitsInTree.append( unit )


func _setInactive( unit : UnitBase ):
	_unitsInTree.remove( _unitsInTree.find( unit ) )


func _updateActiveUnits( units : Array ):
	var newUnitsInTree := []
	for activeUnit in _unitsInTree:
		if units.has( activeUnit ):
			newUnitsInTree.append( activeUnit )

	_unitsInTree = newUnitsInTree


func getUnits():
	return _units.container()

