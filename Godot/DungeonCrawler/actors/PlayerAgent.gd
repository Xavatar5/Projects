extends "res://actors/Agent.gd"

const UnitGd = preload("res://units/unit.gd")

const PlayersActions = [
	["move_up", "move_down", "move_left", "move_right"]
]

var m_moveUpAction    
var m_moveDownAction  
var m_moveLeftAction  
var m_moveRightAction
var m_movement = Vector2(0, 0)


func deleted():
	assert(false)

func _unhandled_input(event):
	if (event.is_action_pressed(m_moveDownAction)  or event.is_action_released(m_moveUpAction)):
		m_movement.y += 1
	if (event.is_action_pressed(m_moveUpAction)    or event.is_action_released(m_moveDownAction)):
		m_movement.y -= 1
	if (event.is_action_pressed(m_moveLeftAction)  or event.is_action_released(m_moveRightAction)):
		m_movement.x -= 1
	if (event.is_action_pressed(m_moveRightAction) or event.is_action_released(m_moveLeftAction)):
		m_movement.x += 1


func copyState(node):
	.copyState(node)
	node.m_moveUpAction = m_moveUpAction
	node.m_moveDownAction = m_moveDownAction
	node.m_moveLeftAction = m_moveLeftAction
	node.m_moveRightAction = m_moveRightAction


func setActions( actions ):
	assert( actions.size() >= PlayersActions.size() )
	m_moveUpAction = actions[0]
	m_moveDownAction  = actions[1]
	m_moveLeftAction  = actions[2]
	m_moveRightAction  = actions[3]


func processMovement(delta):
	if ( get_tree().is_network_server() ):
		m_unit.setMovement(m_movement)
	else:
		m_unit.rpc_id(1, "setMovement", m_movement)


func assignToUnit( unit ):
	.assignToUnit( unit )
	
