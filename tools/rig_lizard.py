# Rig Sean's lizard.blend (run in background Blender on a COPY; his file is never saved over).
# Outputs: <GameAssets>/lizard_rigged.blend, game/assets/models/lizard.glb, preview renders in the job tmp dir.
import bpy
import math
import sys
from mathutils import Vector, Matrix, Quaternion

OUT_BLEND = r'C:\Users\seanm\Nextcloud2\Gamedev\GameAssets\3d-models\lizard_animated.blend' # never lizard_rigged.blend: that holds the owner's hand pose
OUT_GLB = r'C:\Users\seanm\Nextcloud2\Gamedev\GodotGames\bugs-and-lizards\game\assets\models\lizard.glb'
RENDER_DIR = r'C:\Users\seanm\.claude\jobs\f01bd18f\tmp'
LENGTH_M = 1.6

arm = bpy.data.objects['Armature']
body = bpy.data.objects['Cube']
eyes = [bpy.data.objects['Sphere'], bpy.data.objects['Sphere.001']]


def select_only(objs, active):
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = active


# 1. Bake the subdivision into the mesh, drop the old (unweighted) armature modifier, join the eyes into the body.
bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
for m in list(body.modifiers):
	if m.type == 'ARMATURE':
		body.modifiers.remove(m)
select_only([body], body)
for m in list(body.modifiers):
	bpy.ops.object.modifier_apply(modifier=m.name)
for e in eyes:
	mw = e.matrix_world.copy()
	e.parent = None
	e.matrix_world = mw
select_only([body] + eyes, body)
bpy.ops.object.join()

# 2. Fix the skeleton: remove the zero-length bone, hang the neck and both front legs off the front spine bone.
select_only([arm], arm)
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
if 'Bone.007' in eb:
	eb.remove(eb['Bone.007'])
for n in ('Bone.008', 'Bone.006', 'Bone.015'):
	eb[n].parent = eb['Bone']
	eb[n].use_connect = False
bpy.ops.object.mode_set(mode='OBJECT')

# 3. Turn the nose to +Y (glTF -Z, the game's forward), scale to LENGTH_M, centred; apply.
pts = [body.matrix_world @ v.co for v in body.data.vertices]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
k = LENGTH_M / (mx.y - mn.y)
centre = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
T = Matrix.Scale(k, 4) @ Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Translation(-centre)
for o in (arm, body):
	o.matrix_world = T @ o.matrix_world
select_only([arm, body], arm)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 4. Skin with automatic weights.
select_only([body, arm], arm)
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
empty_groups = [g.name for g in body.vertex_groups if not any(g.index in [x.group for x in v.groups] for v in body.data.vertices)]
print('RIG: vertex groups', len(body.vertex_groups), 'empty', empty_groups)
unweighted = sum(1 for v in body.data.vertices if not any(x.weight > 0.001 for x in v.groups))
print('RIG: unweighted vertices', unweighted, 'of', len(body.data.vertices))

# 4b. Stand the lizard up in a low sprawl, copied from the owner's hand-posed hind leg (lizard_rigged.blend, frame 1):
#     thigh out and about 20 degrees down, shin out and about 45 degrees down, foot down and forward. Front legs alike.
#     bake that pose into the mesh, make it the rest pose, then put the feet on z = 0.
FWD = Vector((0, 1, 0))
UP = Vector((0, 0, 1))
select_only([arm], arm)
bpy.ops.object.mode_set(mode='POSE')
pose = arm.pose.bones
for pb in pose:
	pb.rotation_mode = 'QUATERNION'


def side_of(name):
	return 1.0 if arm.data.bones[name].tail_local.x > 0 else -1.0


def aim(name, d):
	pb = pose[name]
	cur = pb.matrix.to_3x3().col[1].normalized()
	r = cur.rotation_difference(d.normalized()).to_matrix().to_4x4()
	head = pb.matrix.translation.copy()
	m = r @ pb.matrix
	m.translation = head
	pb.matrix = m
	bpy.context.view_layer.update()


# Front chains: shoulder (kept), upper arm, forearm, hand. Hind chains: thigh, shin, foot.
FRONT_CHAINS = [['Bone.006', 'Bone.012', 'Bone.013', 'Bone.014'], ['Bone.015', 'Bone.016', 'Bone.017', 'Bone.018']]
HIND_CHAINS = [['Bone.019', 'Bone.020', 'Bone.021'], ['Bone.022', 'Bone.023', 'Bone.024']]
# The front legs are much shorter than the hind ones, so the front legs set the body height (forearm about
# 60 degrees down) and each hind shin is angled so its foot lands on the same ground. Thigh and foot as posed.
HAND = Vector((0.5, 1.0, -0.35)).normalized()
for ch in FRONT_CHAINS:
	s = side_of(ch[1])
	aim(ch[1], Vector((s * 1.0, 0.1, -0.36)))
	aim(ch[2], Vector((s * 0.5, 0.05, -0.87)))
	aim(ch[3], Vector((s * HAND.x, HAND.y, HAND.z)))
ground = min(pose[ch[3]].tail.z for ch in FRONT_CHAINS)
FOOT = Vector((0.037, 0.041, -0.041)).normalized()
for ch in HIND_CHAINS:
	s = side_of(ch[0])
	aim(ch[0], Vector((s * 0.205, -0.007, -0.078)))
	knee = pose[ch[1]].head
	drop = knee.z - ground - pose[ch[2]].length * -FOOT.z
	sin_a = max(0.0, min(1.0, drop / pose[ch[1]].length))
	aim(ch[1], Vector((s * math.sqrt(1.0 - sin_a * sin_a), 0.02, -sin_a)))
	aim(ch[2], Vector((s * FOOT.x, FOOT.y, FOOT.z)))
	print('RIG: hind foot z %.3f, front hand z %.3f, shin %.0f deg down' % (pose[ch[2]].tail.z, ground, math.degrees(math.asin(sin_a))))
bpy.ops.object.mode_set(mode='OBJECT')
select_only([body], body)
for m in list(body.modifiers):
	if m.type == 'ARMATURE':
		bpy.ops.object.modifier_apply(modifier=m.name)
select_only([arm], arm)
bpy.ops.object.mode_set(mode='POSE')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
mod = body.modifiers.new('Armature', 'ARMATURE')
mod.object = arm
min_z = min((body.matrix_world @ v.co).z for v in body.data.vertices)
for o in (arm, body):
	o.matrix_world = Matrix.Translation((0, 0, -min_z)) @ o.matrix_world
select_only([arm, body], arm)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
top = max((body.matrix_world @ v.co).z for v in body.data.vertices)
print('RIG: standing height %.3f m (feet raised body by %.3f)' % (top, -min_z))

# 5. Animations, relative to the standing rest pose. Rotations are about armature-space axes.
bones = arm.data.bones
for pb in pose:
	pb.rotation_mode = 'QUATERNION'


def rot(name, axis_world, angle):
	rest = bones[name].matrix_local.to_3x3()
	return Quaternion((rest.inverted() @ axis_world).normalized(), angle)


SPINE = ['Bone', 'Bone.001']
TAIL = ['Bone.002', 'Bone.003', 'Bone.004', 'Bone.005']
NECK = ['Bone.008', 'Bone.009']
# Limb that swings (upper arm / thigh) -> limb below it.
LIMBS = {'Bone.012': 'Bone.013', 'Bone.016': 'Bone.017', 'Bone.019': 'Bone.020', 'Bone.022': 'Bone.023'}
FRONT = ['Bone.012', 'Bone.016']


def phase(name):
	# Diagonal pairs move together: front-right with hind-left.
	return 0.0 if (side_of(name) > 0) == (name in FRONT) else math.pi


def key_all(frame):
	for pb in pose:
		pb.keyframe_insert('rotation_quaternion', frame=frame)


def reset_pose():
	for pb in pose:
		pb.rotation_quaternion = Quaternion()


def new_action(name):
	act = bpy.data.actions.new(name)
	act.use_fake_user = True
	if arm.animation_data is None:
		arm.animation_data_create()
	arm.animation_data.action = act
	return act


# Walk: one stride in 16 frames (0.67 s at 24 fps), looping. The game speeds it up with the lizard's speed.
walk = new_action('walk')
N = 16
for f in range(N + 1):
	t = f / N * 2 * math.pi
	reset_pose()
	for i, n in enumerate(SPINE):
		pose[n].rotation_quaternion = rot(n, UP, 0.14 * math.sin(t + i * 0.8))
	for i, n in enumerate(TAIL):
		pose[n].rotation_quaternion = rot(n, UP, 0.16 * math.sin(t - 1.2 - i * 0.7))
	pose[NECK[0]].rotation_quaternion = rot(NECK[0], UP, -0.12 * math.sin(t))
	for upper, lower in LIMBS.items():
		s = side_of(upper)
		ph = t + phase(upper)
		out = Vector((s, 0, 0))
		swing = 0.6 * math.sin(ph) # + = foot forward
		lift = 0.45 * max(0.0, math.cos(ph)) # raised while it swings forward
		pose[upper].rotation_quaternion = rot(upper, UP, -s * swing) @ rot(upper, out.cross(UP), lift) # + raises the limb (out x up turns out toward up)
		pose[lower].rotation_quaternion = rot(lower, out.cross(UP), -0.4 * lift)
	key_all(f + 1)

# Idle: slow breathing nod and a lazy tail sway over 48 frames.
idle = new_action('idle')
N2 = 48
for f in range(N2 + 1):
	t = f / N2 * 2 * math.pi
	reset_pose()
	for i, n in enumerate(TAIL):
		pose[n].rotation_quaternion = rot(n, UP, 0.06 * math.sin(t - i * 0.5))
	pose[NECK[0]].rotation_quaternion = rot(NECK[0], Vector((1, 0, 0)), 0.05 * math.sin(t))
	key_all(f + 1)

arm.animation_data.action = walk
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = N + 1
bpy.context.scene.render.fps = 24

# 6. Save the rigged copy and export the glb (both actions).
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, copy=True)
select_only([arm, body], arm)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_animation_mode='ACTIONS',
	export_apply=False, export_yup=True)
print('RIG: exported', OUT_GLB)

# 7. Preview renders: walk frames from the side, the front and above.
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.render.resolution_x = 480
scene.render.resolution_y = 360
cam = bpy.data.objects['Camera']
scene.camera = cam
views = {'side': (Vector((2.6, 0.0, 0.15)), (math.radians(90), 0, math.radians(90))),
	'front': (Vector((0, 2.4, 0.15)), (math.radians(90), 0, math.radians(180))),
	'top': (Vector((0, 0.05, 3.4)), (0, 0, 0))}
for vname, (loc, r) in views.items():
	cam.location = loc
	cam.rotation_euler = r
	for f in (1, 5, 9, 13):
		scene.frame_set(f)
		scene.render.filepath = '%s\liz_%s_%02d.png' % (RENDER_DIR, vname, f)
		bpy.ops.render.render(write_still=True)
print('RIG: done')
