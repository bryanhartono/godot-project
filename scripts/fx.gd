class_name Fx

static func burst(pos: Vector2, col: Color, count: int, speed: float, parent: Node) -> void:
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.global_position = pos
	p.amount = count
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = col
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime * 2.5).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
