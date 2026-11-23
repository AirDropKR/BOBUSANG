class_name SceneLighting
extends RefCounted
## 하늘색 배경, 주변광, 해(그림자). 모든 이동 씬이 같은 조명을 쓴다.

const SKY_COLOR: Color = Color(0.72, 0.82, 0.9)
const AMBIENT_COLOR: Color = Color(0.75, 0.75, 0.7)
const AMBIENT_ENERGY: float = 0.6
const SUN_ENERGY: float = 1.1
const SUN_ROTATION_DEG: Vector3 = Vector3(-50.0, 30.0, 0.0)
const SHADOW_DISTANCE: float = 30.0


static func add_to(parent: Node) -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	parent.add_child(sun)
