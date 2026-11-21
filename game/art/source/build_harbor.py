"""Render the selectable fog harbour from editable Blender geometry.

    blender --background --factory-startup --python build_harbor.py
"""

import json
import math
import random
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


ART = Path(__file__).resolve().parents[1]
rng = random.Random(57216)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
materials = {}
pieces = {}


def color(hex_value):
    rgb = [int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(value / 12.92 if value < 0.04045 else ((value + 0.055) / 1.055) ** 2.4
                 for value in rgb) + (1,)


def paint(hex_value):
    if hex_value not in materials:
        mat = bpy.data.materials.new(hex_value)
        mat.diffuse_color = color(hex_value)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = mat.diffuse_color
        bsdf.inputs["Roughness"].default_value = 0.77
        materials[hex_value] = mat
    return materials[hex_value]


def faces(pigment, vertices, polygons):
    verts, polys = pieces.setdefault(pigment, ([], []))
    offset = len(verts)
    verts.extend(tuple(v) for v in vertices)
    polys.extend(tuple(offset + i for i in face) for face in polygons)


def box(at, dims, shade, angle=0):
    w, d, h = (v * 0.5 for v in dims)
    c, s = math.cos(angle), math.sin(angle)
    verts = [(at[0] + x*c - y*s, at[1] + x*s + y*c, at[2] + z)
             for z in (-h, h) for x, y in [(-w, -d), (w, -d), (w, d), (-w, d)]]
    faces(shade, verts, [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])


def tube(start, end, radius, shade, tip=None, n=8):
    start, end = Vector(start), Vector(end)
    axis = (end - start).normalized()
    tangent = axis.cross(Vector((0, 0, 1)))
    if tangent.length < 0.001:
        tangent = axis.cross(Vector((0, 1, 0)))
    tangent.normalize()
    side = axis.cross(tangent)
    verts = []
    for center, r in [(start, radius), (end, radius if tip is None else tip)]:
        for i in range(n):
            a = 2*math.pi*i/n
            verts.append(center + (math.cos(a)*tangent + math.sin(a)*side)*r)
    faces(shade, verts, [tuple(reversed(range(n))), tuple(range(n, 2*n))] +
          [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])


wood = ["b47e53","bd8e62","ce9867","ba8259","9e6b50"]
rock = ["355866","506977","697d83","486471","38576a","788a87"]
grass = ["648876","799b79","839d78","739575"]
roof = ["af5946","c76649","b95d45","d57c51"]
cream, brass, ink, orange = "f1dcc0", "d5a553", "273d46", "d56542"


def island(x, y, w, d, height):
    n = 15
    ring = []
    for i in range(n):
        a = 2 * math.pi * i/n
        r = rng.uniform(.85,1.09)
        ring.append((math.cos(a)*w*r, math.sin(a)*d*r))
    levels = [(-.34,1.02),(.27,1.03),(height-.16,.91),(height,.89)]
    rings = [[(x+dx*f,y+dy*f,z) for dx,dy in ring] for z,f in levels]
    for h in range(3):
        for i in range(n):
            j = (i+1)%n
            faces(rng.choice(rock if h < 2 else grass), [rings[h][i],rings[h][j],rings[h+1][j],rings[h+1][i]], [(0,1,2,3)])
    faces(rng.choice(grass), rings[-1], [tuple(range(n))])
    return height


def pier(x, y, w, d, z):
    count = max(3, round(d/.24))
    for i in range(count):
        box((x,y-d/2+(i+.5)*d/count,z),(w,d/count-.018,.14),rng.choice(wood))
    for sx in (-1,1):
        box((x+sx*w*.39,y,z-.16),(.18,d+.08,.24),"685249")
        for sy in (-1,1):
            tube((x+sx*w*.43,y+sy*d*.42,-.24),(x+sx*w*.43,y+sy*d*.42,z+.22),.086,"645044")


def house(x,y,z,w=1.2,d=1,h=1,painted=cream,top=orange):
    box((x,y,z+h/2),(w,d,h),painted)
    for sx in (-1,1):
        xx=x+sx*(w/2+.12)
        faces(top,[(xx,y-d/2-.12,z+h-.03),(xx,y+d/2+.12,z+h-.03),
                   (x,y+d/2+.12,z+h+.48),(x,y-d/2-.12,z+h+.48)],[(0,1,2,3)])
    for sy in (-1,1):
        yy=y+sy*d/2
        faces(painted,[(x-w/2,yy,z+h),(x+w/2,yy,z+h),(x,yy,z+h+.48)],[(0,1,2)])
    box((x+w*.17,y-d*.505,z+.35),(.25,.035,.7),"36545a")
    box((x-w*.23,y-d*.514,z+h*.6),(.24,.036,.26),"474e47")
    box((x-w*.23,y-d*.535,z+h*.6),(.18,.026,.18),"e4b967")
    box((x+w*.32,y+d*.22,z+h+.35),(.2,.23,.52),"68594b")


def tree(x,y,z,h):
    tube((x,y,z),(x,y,z+h*.71),h*.055,"79664d",h*.038)
    for i in range(3):
        bottom=z+h*(.20+i*.19)
        tube((x,y,bottom),(x,y,bottom+h*(.52-i*.06)),h*(.26-i*.052),
             ["395e54","507660","6d896b"][i],.004,7)


def flag(x,y,z,h,shade):
    tube((x,y,z),(x,y,z+h),.035,ink)
    faces(shade,[(x,y,z+h-.04),(x+.40,y+.07,z+h-.07),(x+.72,y+.03,z+h-.15),
                 (x+.4,y+.07,z+h-.27),(x,y,z+h-.39)],[(0,1,3,4),(1,2,3)])


def crate(x,y,z,s):
    box((x,y,z+s/2),(s,s*.78,s),"b78151")
    for dx in (-.32,.32):
        box((x+dx*s,y,z+s*.51),(.065,s*.82,s*1.03),"d0a476")


def vessel(x,y,scale,heading,hull,deckhouse=True):
    def local(a,b,z):
        return (x+scale*(math.cos(heading)*a-math.sin(heading)*b),
                y+scale*(math.sin(heading)*a+math.cos(heading)*b),scale*z)
    outline=[(0,-1.12),(.30,-.82),(.42,-.36),(.38,.67),(.23,.96),(-.23,.96),(-.38,.67),(-.42,-.36),(-.30,-.82)]
    upper=[local(a,b,.35) for a,b in outline]
    lower=[local(a*.62,b*.88,.016) for a,b in outline]
    n=len(outline)
    faces(hull,lower+upper,[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
    faces("ae835c",upper,[tuple(range(n))])
    for i in range(n):
        tube(upper[i],upper[(i+1)%n],.03*scale,cream,n=5)
    if deckhouse:
        for z,w,d,shade in [(.56,.49,.70,cream),(.73,.4,.52,"6d9a9b"),(.83,.63,.83,orange)]:
            box(local(0,.04,z),(w*scale,d*scale,.15*scale),shade,heading)
        tube(local(0,.34,.85),local(0,.34,1.18),.079*scale,ink)
    else:
        for b in (-.58,-.07,.51):
            box(local(0,b,.39),(.63*scale,.13*scale,.06*scale),cream,heading)


def lighthouse(x,y,z,h,accent):
    levels=[(0,.88,"818777"),(.12,.82,cream),(.24,.74,accent),(.39,.67,cream),
            (.56,.58,accent),(.70,.52,cream),(.81,.50,ink),(.84,.48,"f2ca77")]
    for i,(fraction,radius,shade) in enumerate(levels):
        stop,tip=(levels[i+1][0],levels[i+1][1]) if i+1<len(levels) else (.98,.48)
        tube((x,y,z+h*fraction),(x,y,z+h*stop),radius,shade,tip,14)
    tube((x,y,z+h*.81),(x,y,z+h*.835),.69,ink,n=16)
    for i in range(10):
        a=i*math.tau/10
        xx,yy=x+.48*math.cos(a),y+.48*math.sin(a)
        tube((xx,yy,z+h*.835),(xx,yy,z+h*.98),.028,ink,n=4)
    tube((x,y,z+h*.98),(x,y,z+h+.42),.70,accent,.03,14)
    tube((x,y,z+h+.42),(x,y,z+h+.73),.03,brass)
    box((x,y-.79,z+.43),(.32,.11,.75),"31505b")
    for fraction in (.34,.65):
        box((x+.13,y-.69+.20*fraction,z+h*fraction),(.17,.18,.30),ink)


# The instrument wharf. Each of the five keys is a distinct piece with a pivot.
z=island(-6.3,1.8,4.5,2.75,1.09)
house(-7.85,2.45,z,2.05,1.5,1.43,"dbba91","557e7c")
house(-5.67,3.40,z,1.3,1.0,.99,cream,"9a5448")
for x,y,h in [(-9,2.0,1.6),(-8.7,3.4,1.15),(-6.5,3.75,1.2)]:
    tree(x,y,z,h)
pier(-5.9,-.05,5.1,1.8,1.04)
for i in range(5):
    xx=-7.7+.82*i
    box((xx,.65,z+.12),(.59,1.6,.20),"4b5c5c")
    box((xx,.60,z+.32),(.70,1.65-i*.16,.15),["b87e44","daad66","c8954f","dbac61","bd8c4e"][i])
    tube((xx,.9,z+.42),(xx,.9,z+.47),.065,"f4d58f")
for xx in (-8.1,-3.95):
    tube((xx,1.17,z),(xx,1.17,z+1.82),.085,"6b5348")
tube((-8.2,1.17,z+1.82),(-3.85,1.17,z+1.82),.075,"896343")
for xx in (-6.06,-5.23):
    tube((xx,1.17,z+1.46),(xx,1.17,z+1.8),.024,ink)
    tube((xx,1.17,z+1.17),(xx,1.17,z+1.51),.21,brass,.07,10)
flag(-4.05,-.34,1.07,1.57,"cb6948")
vessel(-4.25,-1.52,.88,-.51,"9e4e3e",False)

# Two staffed light stations, with different roofs to aid navigation.
for x,y,w,d,zz,h,accent in [(-.35,7.0,2.55,1.85,1.31,4.0,"a74734"),
                               (3.78,7.5,1.78,1.50,.90,3.05,"407e78")]:
    island(x,y,w,d,zz)
    lighthouse(x,y,zz,h,accent)
    house(x-.87,y-.35,zz,.77,.65,.65,"d2bb91",accent)
    pier(x+.70,y-1.6,1.06,1.14,.60)
    tree(x+.89,y+.36,zz,.95)

# Low wind station and a narrow passage between basalt needles.
z=island(8.25,.95,3.30,2.3,.88)
house(8.55,1.0,z,1.54,1.20,1.28,cream,"bd6240")
house(9.78,1.78,z,.98,.83,.8,"b6c7ac","577b79")
pier(7.35,-.68,1.65,2.30,.68)
tube((7.5,.79,z),(7.5,.79,z+2.55),.055,ink)
box((7.53,.79,z+2.46),(.93,.09,.12),orange)
faces(cream,[(7.81,.79,z+2.26),(7.81,.79,z+2.73),(8.28,.79,z+2.44)],[(0,1,2)])
for xx,yy,ww,hh in [(5.55,-.61,.49,1.52),(5.0,1.13,.46,1.02),(5.12,-.04,.31,.55),
                      (10.5,.47,.65,1.65),(9.66,-.33,.31,.57)]:
    tube((xx,yy,-.4),(xx+.13,yy+.07,hh),ww,rng.choice(rock),ww*.49,6)
for xx,yy in [(3.92,1.08),(4.47,.06),(5.05,-1.70),(5.65,-2.65)]:
    tube((xx,yy,.06),(xx,yy,.37),.14,orange,.09,9)
    tube((xx,yy,.37),(xx,yy,.60),.032,cream)
vessel(7.6,-2.05,1.16,.83,"437675")

# Ship-to-shore gantry with a loaded barge and a flatbed on the pier.
z=island(-2.75,-4.9,4.35,2.30,.78)
house(-4.20,-4.74,z,1.65,1.16,1.05,"e7bd89","b55e43")
house(-5.30,-3.96,z,1.20,.88,.93,"ded0b4","71958b")
house(-2.7,-4.70,z,.99,1.02,.91,cream,"537e7d")
pier(-1.45,-3.72,2.73,2.18,.81)
pier(.65,-5.25,1.87,1.14,.70)
for xx in (-1.9,-.45):
    for yy in (-4.08,-3.23):
        box((xx,yy,1.94),(.15,.16,2.26),"bb7141")
    tube((xx,-4.08,.88),(xx,-3.23,2.84),.052,"cc8a4d")
for yy in (-4.08,-3.23):
    box((-.39,yy,3.08),(3.69,.13,.19),"c57c43")
    for i in range(6):
        xa=-2.21+i*.60
        tube((xa,yy,3.15),(xa+.30,yy,3.48),.039,"d08b52")
        tube((xa+.30,yy,3.48),(xa+.60,yy,3.15),.039,"d08b52")
    box((-.41,yy,3.48),(3.67,.09,.10),"d08b52")
box((.83,-3.655,3.01),(.45,.95,.20),ink)
tube((.83,-3.65,2.94),(.83,-3.65,1.67),.024,ink)
crate(.83,-3.65,1.15,.52)
vessel(.91,-3.58,1.40,0,"456766",False)
box((-1.62,-3.71,1.15),(1.12,.43,.13),ink)
box((-2.29,-3.71,1.33),(.40,.44,.49),"8caa91")
for xx in (-2.27,-1.31):
    tube((xx,-3.95,1.01),(xx,-3.46,1.01),.15,ink,n=10)
for xx,yy in [(-.63,-5.14),(-1.12,-5.28),(-4.3,-5.72),(-3.77,-5.6)]:
    crate(xx,yy,z,.41)
flag(-2.7,-5.62,z,1.65,"da744c")

# Breakwaters, tide marks and sparse distant shores give the atlas depth.
for xx,yy,w,d,h in [(-11.5,7.5,1.65,.91,.68),(8.6,9.8,2.33,1.2,.92),
                      (11,-6.6,1.62,.95,.82),(-12.3,-5.1,1.17,.65,.44),
                      (-4.2,12.9,2.2,.97,.65),(13.0,6.5,1.25,.77,.45)]:
    island(xx,yy,w,d,h)
    for k in range(2):
        tree(xx+(k-.5)*.52,yy+.08,h,1.06+k*.35)
for j in range(390):
    xx,yy=rng.uniform(-17,17),rng.uniform(-13,17)
    length=rng.uniform(.05,.43)
    box((xx,yy,.012+rng.random()*.006),(length,rng.uniform(.015,.031),.006),
        rng.choice(["5b9998","53908f","78a8a2","729e97"]),rng.uniform(-.25,.12))
for j in range(11):
    xx,yy,zz=rng.uniform(-10,10),rng.uniform(4.1,13),rng.uniform(2.3,3.7)
    for side in (-1,1):
        faces("f1e7c9",[(xx,yy,zz),(xx+side*.13,yy+.06,zz+.075),
                       (xx+side*.34,yy+.09,zz+.14),(xx+side*.13,yy,zz+.095)],[(0,1,2,3)])
for pigment,(verts,poly) in pieces.items():
    mesh=bpy.data.meshes.new("Timber and coast " + pigment)
    mesh.from_pydata(verts,[],poly)
    mesh.update()
    obj=bpy.data.objects.new("Harbour " + pigment,mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(paint(pigment))

bpy.ops.mesh.primitive_plane_add(size=290,location=(0,0,-.015))
sea=bpy.context.object
water=paint("377575")
sea.data.materials.append(water)
nodes=water.node_tree.nodes
links=water.node_tree.links
bsdf=nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value=.44
coord=nodes.new("ShaderNodeTexCoord")
noise=nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value=.39
noise.inputs["Detail"].default_value=2.6
links.new(coord.outputs["Object"],noise.inputs["Vector"])
ramp=nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color=color("386d76")
ramp.color_ramp.elements[1].color=color("8cb8aa")
links.new(noise.outputs["Fac"],ramp.inputs["Fac"])
links.new(ramp.outputs["Color"],bsdf.inputs["Base Color"])
bump=nodes.new("ShaderNodeBump")
bump.inputs["Strength"].default_value=.18
bump.inputs["Distance"].default_value=.11
links.new(noise.outputs["Fac"],bump.inputs["Height"])
links.new(bump.outputs["Normal"],bsdf.inputs["Normal"])

world=bpy.data.worlds.new("Warm mist")
world.use_nodes=True
world.node_tree.nodes["Background"].inputs["Color"].default_value=(.58,.73,.78,1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value=.56
scene.world=world
bpy.ops.object.light_add(type="SUN",location=(-8,-7,12))
sun=bpy.context.object
sun.rotation_euler=Vector((.48,.60,-.90)).to_track_quat("-Z","Y").to_euler()
sun.data.energy=3.0
sun.data.color=(1,.85,.66)
sun.data.angle=math.radians(11)
bpy.ops.object.camera_add(location=(0,-25,17.8))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,1.05,1.25))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"
camera.data.ortho_scale=27.1
scene.camera=camera
scene.render.resolution_x=1600
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.engine="CYCLES"
scene.cycles.samples=18
scene.cycles.use_denoising=True
scene.view_settings.view_transform="AgX"
scene.render.image_settings.file_format="WEBP"
scene.render.image_settings.quality=94
scene.render.filepath=str(ART/"harbor.webp")
bpy.context.view_layer.update()
markers={}
for key,xyz in {"chime":(-6,.05,1.3),"towers":(1.64,7.6,2.31),"wind":(7.8,.22,1.04),
                "loading":(-1.00,-3.72,2.79),"offshore":(2.8,3.55,.05),
                "berth":(-3.1,-.52,.09)}.items():
    point=world_to_camera_view(scene,camera,Vector(xyz))
    markers[key]=[round(point.x,6),round(1-point.y,6)]
(ART/"harbor_marks.json").write_text(json.dumps(markers,indent=2)+"\n",encoding="utf-8")
bpy.ops.render.render(write_still=True)
