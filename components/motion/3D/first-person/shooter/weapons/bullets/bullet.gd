class_name Bullet extends RigidBody3D

const GroupName = "bullets"

@export var damage: int = 10
@export var direction: Vector3
@export var speed: float = 100.0
@export var delete_after_seconds: float = 5.0

@onready var timer: Timer = $Timer

var origin_weapon: FireArmWeapon
var distance_traveled: float = 0
var collision_points: Array[Vector3] = []
var collision_normals: Array[Vector3] = []

## A different spawn position to create bullets on specific points for example on a hitscan collision
var initial_position: Vector3 = Vector3.ZERO

func _enter_tree() -> void:
	add_to_group(GroupName)
	
	body_entered.connect(on_body_collision)
	

func _ready() -> void:
	if origin_weapon == null or origin_weapon.weapon_configuration == null:
		set_physics_process(false)
		queue_free()
		return
	
	if delete_after_seconds > 0 and is_instance_valid(timer):
		timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		timer.wait_time = delete_after_seconds
		timer.one_shot = true
		timer.timeout.connect(on_timer_timeout)
		timer.start()
	
	collision_layer = GameGlobals.bullets_collision_layer
	collision_mask = GameGlobals.world_collision_layer | GameGlobals.enemies_collision_layer
	
	if direction == null:
		direction = Camera3DHelper.forward_direction(get_viewport().get_camera_3d())
	
	var spread_angle: float = deg_to_rad(origin_weapon.weapon_configuration.fire.bullet_spread_degrees)
	
	scale /= origin_weapon.weapon_mesh.scale
	position = Vector3.ZERO 

	if not initial_position.is_zero_approx():
		global_position = initial_position
		
		if spread_angle > 0:
			global_position += Vector3.ONE.rotated(Vector3.UP, randf_range(-spread_angle, spread_angle))
		
	if spread_angle > 0:
		position += Vector3.ONE.rotated(Vector3.UP, randf_range(-spread_angle, spread_angle))
	
	top_level = true
	lock_rotation = true
	
	apply_central_impulse(speed * direction)
	
	
func _physics_process(_delta: float) -> void:
	distance_traveled = NodePositioner.global_distance_to_v3(origin_weapon, self)


func _integrate_forces(state):
	collision_points.clear()
	collision_normals.clear()
	
	for i in range(state.get_contact_count()):
		## Collision points are on local space, we need to transform then into global space
		var to_collision_point: Vector3 = state.get_contact_collider_position(i) - state.transform.origin
		collision_points.append(to_global(to_collision_point))
		collision_normals.append(state.get_contact_local_normal(i))
	

func setup(weapon: FireArmWeapon, travel_direction: Vector3, spawn_position: Vector3 = Vector3.ZERO) -> void:
	origin_weapon = weapon
	## We adjust the direction to fit the spread angle in the projectile (for example, on shotguns)
	var spread_angle: float = deg_to_rad(weapon.weapon_configuration.fire.bullet_spread_degrees)
	spread_angle = randf_range(-spread_angle, spread_angle)
		
	direction = travel_direction.rotated(VectorHelper.directions_v3.pick_random(), spread_angle)
	initial_position = spawn_position

## Use as data when the hurtbox detects this hitbox to calculate the damage
func collision_damage() -> float:
	var total_damage = damage + origin_weapon.weapon_configuration.bullet.base_damage
	
	if distance_traveled <= origin_weapon.weapon_configuration.bullet.close_distance_to_apply_damage_multiplier:
		total_damage *= origin_weapon.weapon_configuration.bullet.close_distance_damage_multiplier
	
	if origin_weapon.weapon_configuration.fire.multiplier_for_distance_traveled.size() > 1:
		var distance_splitted: int = ceil(distance_traveled / origin_weapon.weapon_configuration.bullet.multiplier_for_distance_traveled[0])
		
		for i in range(distance_splitted):
			total_damage *= origin_weapon.weapon_configuration.bullet.multiplier_for_distance_traveled[1]
	
	return total_damage


func on_body_collision(other_body: Node) -> void:
	if other_body.collision_layer in [GameGlobals.world_collision_layer] and collision_points.size() > 0:
		
		#for collision_point: Vector3 in collision_points:
			#origin_weapon.fire_impact_hit(collision_point)
			#origin_weapon.fire_decal(collision_point, collision_normals[collision_points.find(collision_point)])
		#
		if other_body is RigidBody3D:
			other_body.apply_impulse(Vector3.ONE * direction, -collision_points.front())
	
	collision_mask = 0
	freeze = true
	hide()
	

func on_timer_timeout() -> void:
	if not is_queued_for_deletion():
		queue_free()