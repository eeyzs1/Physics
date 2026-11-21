"""Build the four original Wind Isles models with Blender 5.1.

    blender --background --factory-startup --python build_models.py
    blender --background --factory-startup --python build_models.py -- manta

All dimensions are metres. Blender +Y is the nose, +X is starboard and +Z is
up. glTF export converts these to Godot -Z, +X and +Y, respectively.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector


DESTINATION = Path(__file__).resolve().parents[1]
TAU = math.tau
V = Vector
PALETTE = {
    "ink": "263c43", "slate": "476669", "petrol": "255557",
    "teal": "368a81", "lagoon": "64b6a3", "mint": "b4d7bc",
    "foam": "e6eaca", "linen": "f5e8bd", "ivory": "fff3cd",
    "sand": "d6b477", "gold": "eab75c", "flame": "e68254",
    "coral": "d75f43", "brick": "b65b43", "auburn": "8a5642",
    "bark": "694e3c", "wood": "a57b52", "reed": "bc995e",
    "rockdeep": "524f4b", "rockcool": "69716a", "rockshade": "8e725b",
    "ochre": "b48766", "clay": "c79570", "chalk": "e0b98a",
    "turf": "7fa876", "sage": "a6bd83", "moss": "658c61",
    "jade": "48816b", "pine": "356857", "leaf": "82ad77",
    "berry": "e8a56b", "raydeep": "2e666d", "ray": "47888a",
    "raylight": "79b1a1", "raybelly": "b5d0b3", "lume": "d1efbc",
}
MATERIALS = {}


def linear_color(key):
    rgb = PALETTE.get(key, key)
    srgb = [int(rgb[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1,)


COLORS = {name: linear_color(name) for name in PALETTE}


def material(kind):
    if kind in MATERIALS:
        return MATERIALS[kind]
    names = {
        "paint": "Harbour pigments", "cloth": "Woven sailcloth",
        "metal": "Hammered fittings", "lume": "Ray phosphor", "lamp": "Beacon glass",
    }
    mat = bpy.data.materials.new(names[kind])
    mat.use_nodes = True
    mat.use_backface_culling = kind != "cloth"
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = {"metal": .39, "lume": .52, "lamp": .34}.get(kind, .87)
    if kind == "metal":
        bsdf.inputs["Metallic"].default_value = .34
    if kind in ("lume", "lamp"):
        bsdf.inputs["Emission Color"].default_value = COLORS["mint" if kind == "lume" else "gold"]
        bsdf.inputs["Emission Strength"].default_value = .45 if kind == "lume" else 1.15
    paint = nodes.new("ShaderNodeVertexColor")
    paint.layer_name = "Paint"
    mat.node_tree.links.new(paint.outputs["Color"], bsdf.inputs["Base Color"])
    MATERIALS[kind] = mat
    return mat


class MeshPart:
    """Collect disconnected pieces into one editable mesh and one draw per material."""

    def __init__(self, name, pivot=(0, 0, 0)):
        self.name = name
        self.pivot = V(pivot)
        self.vertices = []
        self.faces = []
        self.paints = []

    def add(self, vertices, faces, colors, kind="paint", *, center=None, normal=None):
        vertices = [V(p) for p in vertices]
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        center = V(center) if center is not None else None
        normal = V(normal) if normal is not None else None
        for i, indices in enumerate(faces):
            indices = list(indices)
            if center is not None or normal is not None:
                a, b, c = (vertices[j] for j in indices[:3])
                outward = normal if normal is not None else sum((vertices[j] for j in indices), V((0, 0, 0))) / len(indices) - center
                if (b - a).cross(c - a).dot(outward) < 0:
                    indices.reverse()
            self.faces.append(tuple(j + offset for j in indices))
            self.paints.append((colors if isinstance(colors, str) else colors[i], kind))

    def bake(self, root):
        mesh = bpy.data.meshes.new(self.name + " mesh")
        mesh.from_pydata([v - self.pivot for v in self.vertices], [], self.faces)
        mesh.update()
        kinds = list(dict.fromkeys(kind for _, kind in self.paints))
        for kind in kinds:
            mesh.materials.append(material(kind))
        attributes = mesh.color_attributes.new(name="Paint", type="FLOAT_COLOR", domain="CORNER")
        for polygon, (color, kind) in zip(mesh.polygons, self.paints):
            polygon.material_index = kinds.index(kind)
            for index in polygon.loop_indices:
                attributes.data[index].color = COLORS[color]
        mesh.color_attributes.active_color = attributes
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        obj.location = self.pivot
        return obj


def tube(part, points, radii, color, sides=6, kind="paint"):
    points = [V(p) for p in points]
    if isinstance(radii, (int, float)):
        radii = [radii] * len(points)
    verts = []
    last_u = None
    for i, (p, radius) in enumerate(zip(points, radii)):
        direction = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if last_u is None or abs(direction.dot(last_u)) > .93:
            ref = V((0, 0, 1)) if abs(direction.z) < .88 else V((1, 0, 0))
            u = direction.cross(ref).normalized()
        else:
            u = (last_u - direction * direction.dot(last_u)).normalized()
        v = direction.cross(u).normalized()
        last_u = u
        for j in range(sides):
            a = TAU * j / sides
            verts.append(p + radius * (math.cos(a) * u + math.sin(a) * v))
    faces = []
    for ring in range(len(points) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((ring * sides + j, ring * sides + k, (ring + 1) * sides + k, (ring + 1) * sides + j))
    faces += [tuple(reversed(range(sides))), tuple(range(len(verts) - sides, len(verts)))]
    part.add(verts, faces, color, kind)


def rod(part, a, b, radius, color, end=None, kind="paint", sides=6):
    tube(part, [a, b], [radius, radius if end is None else end], color, sides, kind)


def ellipsoid(part, center, size, colors, segments=10, rings=5, kind="paint", rotation=0):
    center = V(center)
    sx, sy, sz = size
    ca, sa = math.cos(rotation), math.sin(rotation)
    verts = [center + V((0, 0, -sz))]
    for i in range(1, rings):
        lat = math.pi * (i / rings - .5)
        z, r = math.sin(lat), math.cos(lat)
        for j in range(segments):
            a = TAU * j / segments
            x, y = sx * r * math.cos(a), sy * r * math.sin(a)
            verts.append(center + V((x * ca - y * sa, x * sa + y * ca, sz * z)))
    verts.append(center + V((0, 0, sz)))
    faces, paint = [], []
    for j in range(segments):
        k = (j + 1) % segments
        faces.append((0, 1 + k, 1 + j))
        for i in range(rings - 2):
            base = 1 + i * segments
            faces.append((base + j, base + k, base + segments + k, base + segments + j))
        last = 1 + (rings - 2) * segments
        faces.append((last + j, last + k, len(verts) - 1))
        for i in range(rings):
            paint.append(colors(i, j) if callable(colors) else colors)
    part.add(verts, faces, paint, kind, center=center)


def mesh_strip(part, rows, colors, kind="paint", normal=(0, 0, 1)):
    vertices = [p for row in rows for p in row]
    count = len(rows[0])
    faces, tones = [], []
    for i in range(len(rows) - 1):
        for j in range(count - 1):
            a = i * count + j
            faces.append((a, a + count, a + count + 1, a + 1))
            tones.append(colors(i, j) if callable(colors) else colors)
    part.add(vertices, faces, tones, kind, normal=normal)


def flat(part, vertices, color, kind="cloth"):
    part.add(vertices, [tuple(range(len(vertices)))], color, kind)


def lookup(samples, value):
    for i in range(len(samples) - 1):
        a, b = samples[i], samples[i + 1]
        if value <= b[0] or i == len(samples) - 2:
            t = min(1, max(0, (value - a[0]) / (b[0] - a[0])))
            return tuple(x + (y - x) * t for x, y in zip(a[1:], b[1:]))


def ring_path(part, points, radius, color, kind="paint"):
    tube(part, [*points, points[0]], radius, color, 6, kind)


def make_root(name):
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    return root


def glider():
    root = make_root("Glider")
    body = MeshPart("Cockpit")
    # A hollow clinker hull with a coaming around the actual opening.
    stations = [
        (-1.98, .06, .07, .12), (-1.43, .17, .14, .10),
        (-.78, .36, .21, .05), (-.36, .45, .25, .045),
        (.10, .49, .28, .03), (.65, .43, .26, .02),
        (1.14, .37, .23, .025), (1.67, .21, .17, .06), (2.08, .035, .06, .09),
    ]
    ring = 12
    v = [(r * math.cos(TAU * j / ring), y, z + h * math.sin(TAU * j / ring)) for y, r, h, z in stations for j in range(ring)]
    faces, tones = [], []
    for i in range(len(stations) - 1):
        for j in range(ring):
            if 2 <= i < 5 and 1 <= j <= 4:
                continue
            k = (j + 1) % ring
            faces.append((i * ring + j, (i + 1) * ring + j, (i + 1) * ring + k, i * ring + k))
            height = math.sin(TAU * (j + .5) / ring)
            if height < -.60:
                color = "brick" if i < 2 else "coral"
            elif height < .1:
                color = "flame"
            elif i >= 5:
                color = "flame" if height > .80 and i < 7 else "coral"
            elif i < 2:
                color = "auburn" if height > .80 else "coral"
            else:
                color = "sand" if height > .63 else "wood"
            tones.append(color)
    faces.extend([tuple(range(ring)), tuple(range(len(v) - ring, len(v)))])
    body.add(v, faces, tones + ["bark", "coral"], center=(0, 0, .04))
    opening = [v[i * ring + 1] for i in range(2, 6)]
    opening += [v[5 * ring + j] for j in range(2, 6)]
    opening += [v[i * ring + 5] for i in (4, 3, 2)]
    opening += [v[2 * ring + j] for j in (4, 3, 2)]
    ring_path(body, opening, .027, "bark")
    ellipsoid(body, (0, -.10, -.01), (.34, .70, .09), "ink")
    ellipsoid(body, (0, -.46, .17), (.30, .13, .22), "petrol")
    for sign in (-1, 1):
        strake = [(sign * w * .99, y, z + .035) for y, w, h, z in stations]
        tube(body, strake, [.012, .022, .029, .031, .032, .03, .028, .018, .008], "gold", 5)
    # A pair of lashing bands around the enamelled foredeck.
    for y, w, height in [(1.18, .36, .22), (1.31, .32, .21), (-1.18, .215, .16)]:
        loop = [(w * math.cos(i * TAU / 14), y, .04 + height * math.sin(i * TAU / 14)) for i in range(14)]
        ring_path(body, loop, .021, "petrol")
    rod(body, (0, .63, .12), (0, .51, .32), .031, "bark")
    rod(body, (-.21, .51, .32), (.21, .51, .32), .032, "wood")
    ellipsoid(body, (0, .78, .28), (.14, .16, .065), "gold", kind="metal")
    ellipsoid(body, (0, .78, .322), (.082, .10, .028), "teal")
    # Pilot silhouette and two stitched scarf tails, visible from the chase camera.
    ellipsoid(body, (0, -.15, .245), (.24, .24, .24), "teal")
    ellipsoid(body, (0, -.09, .50), (.165, .155, .18), "ochre")
    ellipsoid(body, (0, -.13, .595), (.186, .187, .112), "gold")
    ellipsoid(body, (0, -.075, .574), (.179, .195, .043), "bark")
    for sign in (-1, 1):
        ellipsoid(body, (sign * .067, .075, .557), (.052, .043, .042), "lagoon", kind="metal")
        tube(body, [(sign * .20, -.1, .32), (sign * .23, .12, .23), (sign * .18, .46, .31)], [.068, .054, .038], "petrol")
    ellipsoid(body, (0, -.12, .393), (.19, .175, .054), "coral")
    for sign in (-1, 1):
        mesh_strip(body, [
            [(sign * .055, -.24, .42), (sign * .12, -.24, .42)],
            [(sign * .10, -.54, .38), (sign * .19, -.51, .39)],
            [(sign * .07, -.82, .42), (sign * .12, -.75, .4)],
        ], "coral", "cloth")
    # Fin and tailplane with inset wind marks.
    fin = [(0, -1.02, .18), (0, -1.55, .70), (0, -1.85, .77), (0, -1.84, .24)]
    flat(body, fin, "teal")
    flat(body, [(0.006, -1.47, .55), (.006, -1.55, .68), (.006, -1.81, .69), (.006, -1.82, .59)], "linen")
    tube(body, [(0, -1.03, .18), (0, -1.55, .72), (0, -1.85, .77)], [.032, .024, .016], "wood")
    for sign in (-1, 1):
        mesh_strip(body, [
            [(0, -1.31, .21), (0, -1.87, .22)],
            [(sign * .59, -1.48, .24), (sign * .61, -1.89, .25)],
            [(sign * .93, -1.66, .30), (sign * .87, -1.87, .29)],
        ], lambda i, j: "foam" if i == 0 else "coral", "cloth")
    body.bake(root)

    outline = [(0, .85, -.77, .21), (.20, .92, -.88, .34), (.48, .72, -.92, .49),
               (.75, .42, -.83, .47), (.9, .18, -.67, .42), (1, -.13, -.45, .35)]
    for sign, name in [(-1, "WingL"), (1, "WingR")]:
        wing = MeshPart(name, (sign * .34, .14, .19))

        def fabric(s, t, lift=0):
            leading, trailing, z = lookup(outline, s)
            chord = leading - trailing
            return (sign * (.34 + 2.67 * s), leading - t * chord,
                    z + chord * .115 * math.sin(math.pi * t) - .075 * t + lift)

        spans = [0, .11, .23, .35, .48, .62, .75, .87, .94, 1]
        chord_points = [0, .12, .39, .66, .84, 1]
        def panel(i, j):
            if i == 8:
                return "teal" if j < 4 else "lagoon"
            if j == 4 and i in (3, 4, 5, 6, 7):
                return "mint" if i < 6 else "lagoon"
            return "ivory" if (i + j) % 4 == 1 else "linen"
        mesh_strip(wing, [[fabric(s, t) for t in chord_points] for s in spans], panel, "cloth")
        # Painted wing marks follow the cambered fabric rather than floating above it.
        for start, stop, width, offset, tone in [(.30, .9, .055, .25, "teal"), (.42, .88, .022, .37, "gold")]:
            ribbon = []
            for i in range(10):
                f = i / 9
                s = start + (stop - start) * f
                t = offset + .19 * math.sin(f * math.pi * .78)
                half = .008 + width * math.sin(f * math.pi)
                ribbon.append([fabric(s, t - half, .008), fabric(s, t + half, .008)])
            mesh_strip(wing, ribbon, tone, "cloth")
        tube(wing, [fabric(s, 0, .011) for s in spans], [.042 - .019 * s for s in spans], "reed")
        tube(wing, [fabric(s, 1) for s in spans], .015, "wood", 5)
        for s in (.10, .35, .62, .87):
            tube(wing, [fabric(s, t, .006) for t in chord_points], .012, "sand", 5)
        for s in (.18, .70):
            a = fabric(s, 0)
            rod(wing, (a[0] - .049, a[1], a[2] + .004), (a[0] + .049, a[1], a[2] + .004), .047 - s * .013, "teal", sides=8)
        tube(wing, [(sign * .34, .25, -.13), fabric(.44, .49, -.07), fabric(.78, .08, -.04)], [.041, .033, .019], "wood")
        rod(wing, (sign * .34, -.42, -.07), fabric(.67, .82, -.01), .012, "bark", sides=4)
        ellipsoid(wing, (sign * .35, .14, .19), (.088, .11, .09), "gold", kind="metal")
        wing.bake(root)


def manta():
    root = make_root("CloudManta")
    body = MeshPart("RayBody")
    segments = 14
    stations = [(-1.26, .09, .10, .01), (-.89, .44, .19, .04), (-.34, .72, .28, .095),
                (.26, .82, .29, .11), (.73, .68, .23, .06), (1.05, .44, .145, .015),
                (1.16, .23, .10, -.015)]
    vertices = [(r * math.cos(j * TAU / segments), y, z + h * math.sin(j * TAU / segments))
                for y, r, h, z in stations for j in range(segments)]
    faces, tones = [], []
    for i in range(len(stations) - 1):
        for j in range(segments):
            a, k = i * segments + j, (j + 1) % segments
            faces.append((a, (i + 1) * segments + j, (i + 1) * segments + k, i * segments + k))
            h = math.sin((j + .5) * TAU / segments)
            tones.append("raybelly" if h < -.18 else "raylight" if h < .36 else "raydeep" if h > .86 else "ray")
    faces.extend([tuple(range(segments)), tuple(range(len(vertices) - segments, len(vertices)))])
    body.add(vertices, faces, tones + ["raydeep", "raybelly"], center=(0, 0, .05))
    # Rolled cephalic lobes and a supple tapering tail give the creature a readable front and rear.
    for sign in (-1, 1):
        tube(body, [(sign * .45, .87, .055), (sign * .49, 1.13, .018), (sign * .45, 1.39, .10),
                    (sign * .34, 1.54, .16)], [.17, .13, .092, .037], "raylight", 8)
        ellipsoid(body, (sign * .565, .79, .128), (.08, .10, .06), "gold")
        ellipsoid(body, (sign * .605, .835, .149), (.038, .048, .038), "ink")
        for i in range(3):
            tube(body, [(sign * (.36 + .06 * i), .66 - i * .13, -.13),
                        (sign * (.48 + .058 * i), .63 - i * .13, -.10)], .015, "raydeep", 4)
    spine = [(0, -1.02, .025), (.09, -1.47, .02), (.22, -1.98, .12),
             (.22, -2.48, .22), (.03, -2.95, .24), (-.21, -3.36, .36), (-.28, -3.65, .44)]
    tube(body, spine, [.15, .103, .073, .051, .037, .022, .010], "raydeep", 7)
    for i in range(5):
        ellipsoid(body, (0, .55 - .25 * i, .345 + .032 * math.sin(i)), (.044, .074, .019), "lume", kind="lume")
    body.bake(root)
    edge = [(0, 1.00, -1.07, .08), (.2, 1.04, -1.26, .14), (.42, .90, -1.32, .20),
            (.64, .55, -1.32, .26), (.82, .02, -1.16, .33), (1, -.86, -.97, .40)]
    for sign, name in [(-1, "FinL"), (1, "FinR")]:
        fin = MeshPart(name, (sign * .56, .01, .09))

        def skin(s, t, top=True, margin=0):
            lead, trail, z = lookup(edge, s)
            belly = math.sin(t * math.pi) ** .84
            thick = (.182 * (1 - s) + .01) * belly
            return (sign * (.47 + 3.10 * s), lead + (trail - lead) * t,
                    z + (.075 * math.sin(t * math.pi) - .085 * t) + (thick if top else -thick) + margin)

        ss = [0, .13, .27, .42, .55, .68, .80, .90, 1]
        ts = [0, .12, .37, .62, .83, 1]
        mesh_strip(fin, [[skin(s, t) for t in ts] for s in ss],
                   lambda i, j: "raylight" if j == 0 or i == 7 else "raydeep" if j == 3 and i < 5 else "ray")
        mesh_strip(fin, [[skin(s, t, False) for t in ts] for s in ss],
                   lambda i, j: "raybelly" if j < 4 else "raylight", normal=(0, 0, -1))
        # Mother-of-pearl spots are fitted to each wing and move with it.
        for s, t, rw, rh in [(.22, .35, .034, .044), (.33, .31, .026, .035), (.43, .32, .039, .052),
                              (.54, .40, .029, .046), (.61, .47, .022, .038), (.68, .55, .015, .029),
                              (.41, .49, .015, .021), (.19, .58, .021, .027)]:
            for top in (True, False):
                dz = .014 if top else -.014
                points = [skin(s, t, top, dz)]
                for j in range(8):
                    a = TAU * j / 8
                    points.append(skin(s + rw * math.cos(a), t + rh * math.sin(a), top, dz))
                fin.add(points, [(0, j + 1, (j + 1) % 8 + 1) for j in range(8)],
                        "lume", "lume", normal=(0, 0, 1 if top else -1))
        fin.bake(root)


def island():
    rng = random.Random(60817)
    root = make_root("Islet")
    land = MeshPart("WindcutBluff")
    count = 20
    angles = [TAU * (i + .12 * math.sin(i * 2.59)) / count for i in range(count)]
    outline = [5.55 * (1 + .065 * math.sin(3 * a + .8) + .052 * math.cos(5 * a - 1) + rng.uniform(-.025, .025)) for a in angles]
    layers = [
        (1.00, -.22, .00, .00), (1.015, -.52, -.02, .02),
        (.985, -1.12, -.05, .04), (.95, -1.66, -.10, .06), (.86, -2.23, -.12, .1),
        (.84, -2.52, -.17, .11), (.72, -3.54, -.30, .18),
        (.56, -4.43, -.53, .25), (.38, -5.12, -.65, .32), (.17, -5.94, -.79, .38),
    ]
    rings = []
    for k, (scale, z, dx, dy) in enumerate(layers):
        ring = []
        for j, (a, radius) in enumerate(zip(angles, outline)):
            sway = (.02 + min(k, 5) * .007) * math.sin(j * 2.2 + k * .85)
            r = radius * (scale + sway)
            # Continuous bedding planes read from a distance. Local chips split their edges.
            dz = (.12 + .035 * min(k, 6)) * math.sin(2 * a + .45) + (.025 + k * .01) * math.cos(4 * a + k)
            ring.append((dx + r * math.cos(a), dy + r * math.sin(a), z + dz))
        rings.append(ring)
    # The inner meadow is a flat landing area whose centre is the asset origin.
    ring_a = [(1.93 * math.cos(a), 1.93 * math.sin(a), 0.0) for a in angles]
    ring_b = [(r * .70 * math.cos(a), r * .70 * math.sin(a), 0.0) for a, r in zip(angles, outline)]
    for j in range(count):
        n = (j + 1) % count
        land.add([(0, 0, 0), ring_a[j], ring_a[n]], [(0, 1, 2)], "turf", normal=(0, 0, 1))
    for inner, outer, tones in [(ring_a, ring_b, ("turf", "turf", "sage")), (ring_b, rings[0], ("turf", "moss", "leaf"))]:
        for j in range(count):
            n = (j + 1) % count
            vertices = [inner[j], outer[j], outer[n], inner[n]]
            land.add(vertices, [(0, 1, 2), (0, 2, 3)], [tones[(j // 3) % 3], tones[((j + 1) // 3) % 3]], normal=(0, 0, 1))
    strata = [
        ("moss", "jade", "turf"), ("clay", "ochre", "rockshade"), ("chalk", "clay", "ochre"),
        ("ochre", "rockshade", "clay"), ("chalk", "clay", "ochre"), ("auburn", "rockshade", "ochre"),
        ("rockcool", "rockshade", "rockdeep"), ("rockshade", "rockcool", "auburn"), ("rockdeep", "rockcool", "rockshade"),
    ]
    for k, (upper, lower) in enumerate(zip(rings, rings[1:])):
        for j in range(count):
            n = (j + 1) % count
            vertices = [upper[j], lower[j], lower[n], upper[n]]
            bank = strata[k]
            stone = bank[(j // 3 + k // 2) % 3]
            split = rng.choice([stone, stone, bank[(j // 3 + k // 2 + 1) % 3]])
            land.add(vertices, [(0, 1, 2), (0, 2, 3)], [stone, split], normal=(math.cos(angles[j]), math.sin(angles[j]), -.15))
    point = (-.86, .4, -6.52)
    for j in range(count):
        land.add([rings[-1][j], point, rings[-1][(j + 1) % count]], [(0, 1, 2)], "rockdeep", center=(0, 0, -3.8))
    # Wind-polished crags emerging from the lower shelves.
    for j in [0, 3, 5, 8, 10, 14, 17]:
        p = V(rings[5][j])
        a = angles[j]
        radial = V((math.cos(a), math.sin(a), 0))
        p -= radial * .28
        tube(land, [p + V((0, 0, .3)), p + radial * .11 - V((0, 0, .5)), p - radial * .15 - V((0, 0, 1.3)),
                    p - radial * .5 - V((0, 0, rng.uniform(1.8, 2.65)))], [.22, .48, .26, .025],
             rng.choice(["ochre", "rockshade", "rockcool"]), 5)
    # Chalk and copper-green seams visible under the lip.
    for base in (2, 8, 14):
        lines = []
        for k in range(4):
            j = (base + k) % count
            p = V(rings[3][j]); p += V((math.cos(angles[j]) * .04, math.sin(angles[j]) * .04, .04))
            lines.append(p)
        tube(land, lines, [.026, .048, .046, .013], "lagoon", 5)
    for j in (1, 6, 11, 15, 18):
        rim = V(rings[0][j]); rim += V((.04 * math.cos(angles[j]), .04 * math.sin(angles[j]), .02))
        outside = V((math.cos(angles[j]), math.sin(angles[j]), 0))
        points = [rim, rim + outside * .13 + V((.05, .02, -.50)), rim + outside * .04 + V((-.13, .06, -.96)),
                  rim - outside * .12 + V((.04, .08, -1.50))]
        tube(land, points, [.046, .04, .031, .012], "pine", 5)
        for k in range(1, 3):
            ellipsoid(land, points[k], (.11, .14, .10), "jade", 6, 3)
    land.bake(root)

    growing = MeshPart("Clifftop")
    # Tufted saltgrass, bending away from the same prevailing wind.
    for _ in range(58):
        a = rng.uniform(0, TAU)
        radius = rng.uniform(2.35, 4.85)
        x, y = radius * math.cos(a), radius * math.sin(a)
        ground = -.014 - max(0, radius - 3.9) * .13
        for _ in range(rng.randint(3, 6)):
            bx = x + rng.uniform(-.13, .13); by = y + rng.uniform(-.12, .12)
            height = rng.uniform(.12, .41); width = rng.uniform(.024, .058)
            tilt = rng.uniform(.06, .21)
            flat(growing, [(bx - width, by, ground), (bx + width, by + .014, ground), (bx + tilt, by + .06, ground + height)],
                 rng.choice(["moss", "sage", "leaf", "reed"]))

    def crown(z_level, facet):
        return ("pine", "jade", "leaf", "sage")[min(z_level, 3)] if facet % 4 else ("pine", "moss", "leaf", "sage")[min(z_level, 3)]

    for x, y, scale in [(3.35, 2.15, 1.0), (4.12, 1.12, .67), (-3.52, -.96, .71)]:
        z = -.035
        def P(a, b, c):
            return (x + a * scale, y + b * scale, z + c * scale)
        tube(growing, [P(0, 0, 0), P(.02, 0, .48), P(.19, .03, 1.08), P(.41, .05, 1.70), P(.58, .06, 1.92)],
             [.14 * scale, .12 * scale, .095 * scale, .055 * scale, .024 * scale], "bark", 7)
        for bx, by, bz, lateral, depth in [(.06, .04, .77, -.42, .16), (.26, .035, 1.24, .64, -.22), (.44, .06, 1.61, .22, .22)]:
            end = P(bx + lateral, by + depth, bz + .15)
            rod(growing, P(bx, by, bz), end, .067 * scale, "wood", .026 * scale, sides=5)
            ellipsoid(growing, (end[0] + .09 * scale, end[1], end[2] + .06 * scale),
                      ((.48 + abs(lateral) * .34) * scale, .42 * scale, .26 * scale), crown, 8, 4, rotation=.27)
        ellipsoid(growing, P(.61, .07, 1.91), (.46 * scale, .34 * scale, .26 * scale), crown, 8, 4)

    for x, y, size in [(-3.3, 2.02, .65), (-3.75, 1.54, .44), (2.87, 2.84, .54), (3.55, -.51, .42),
                        (-2.72, -2.42, .54), (1.89, -3.48, .43), (3.91, -1.70, .38)]:
        ellipsoid(growing, (x, y, .13), (size, .64 * size, .57 * size), crown, 7, 4, rotation=x)
        for i in range(3):
            a = i * 2.12 + x
            ellipsoid(growing, (x + .32 * size * math.cos(a), y + .33 * size * math.sin(a), .13 + .45 * size),
                      (.055, .049, .054), "berry", 6, 3)

    for i in range(16):
        a = rng.uniform(0, TAU); r = rng.uniform(2.45, 4.48)
        x, y = r * math.cos(a), r * math.sin(a)
        width = rng.uniform(.09, .33)
        ellipsoid(growing, (x, y, -.012), (width, width * rng.uniform(.65, .9), width * .57),
                  lambda j, k: "rockshade" if j < 1 else "ochre" if j < 2 else "chalk", 7, 3, rotation=a)
    # A weathered tide pennant set outside the landing area.
    x, y = -2.75, 3.05
    rod(growing, (x, y, -.08), (x + .06, y, 1.50), .042, "wood", .026)
    mesh_strip(growing, [
        [(x + .06, y, 1.43), (x + .05, y, 1.07)],
        [(x + .36, y + .09, 1.39), (x + .34, y + .085, 1.08)],
        [(x + .71, y + .04, 1.31), (x + .70, y + .04, 1.12)],
        [(x + .98, y + .03, 1.22), (x + .96, y + .03, 1.17)],
    ], lambda i, j: "coral" if i == 0 else "linen", "cloth", normal=(0, -1, 0))
    growing.bake(root)


def drum(part, profile, colors, count=8, kind="paint", phase=0):
    vertices = [(radius * math.cos(j * TAU / count + phase), radius * math.sin(j * TAU / count + phase), z)
                for z, radius in profile for j in range(count)]
    faces, tones = [], []
    for i in range(len(profile) - 1):
        for j in range(count):
            n = (j + 1) % count
            faces.append((i * count + j, i * count + n, (i + 1) * count + n, (i + 1) * count + j))
            tones.append(colors(i, j) if callable(colors) else colors)
    faces += [tuple(reversed(range(count))), tuple(range(len(vertices) - count, len(vertices)))]
    tones += [tones[0], tones[-1]]
    part.add(vertices, faces, tones, kind)


def beacon():
    root = make_root("WindBeacon")
    tower = MeshPart("BeaconStand")
    drum(tower, [(0, .88), (.12, 1.0), (.30, .92), (.38, .73)],
         lambda i, j: ("rockcool", "ochre", "chalk")[i], 8, phase=math.pi / 8)
    drum(tower, [(.33, .73), (.47, .75), (.57, .63)], lambda i, j: "petrol" if i == 0 else "teal", 8)
    drum(tower, [(.52, .27), (.88, .25), (2.80, .17), (3.10, .27)], "wood", 8)
    for i in range(3):
        a = TAU * i / 3 + math.pi / 6
        def anchor(r, h, offset=0):
            return (r * math.cos(a + offset), r * math.sin(a + offset), h)
        tube(tower, [anchor(.64, .45), anchor(.65, 1.05), anchor(.39, 2.32), anchor(.52, 3.20)],
             [.12, .105, .084, .068], "wood", 7)
        rod(tower, anchor(.63, .84), anchor(.43, 2.35, TAU / 3), .037, "petrol", sides=5)
        rod(tower, anchor(.62, 1.12), anchor(.33, 2.61), .044, "gold", kind="metal")
        tube(tower, [anchor(.61, .50), anchor(.61, .67)], .128, "slate", 8, "metal")
    drum(tower, [(2.85, .28), (3.08, .62), (3.23, .69), (3.35, .48), (3.46, .25)],
         lambda i, j: ("teal", "petrol", "gold", "teal")[i], 8, "metal")
    ring_center = V((0, 0, 4.43))
    for angle, radius, height, paint in [(.03, .90, 1.02, "lagoon"), (math.pi / 2 + .03, .67, 1.00, "gold")]:
        axis = V((math.cos(angle), math.sin(angle), 0))
        points = [ring_center + axis * (radius * math.cos(i * TAU / 16)) + V((0, 0, height * math.sin(i * TAU / 16))) for i in range(16)]
        ring_path(tower, points, .063, paint, "metal")
    drum(tower, [(5.39, .19), (5.50, .25), (5.66, .115), (5.97, .025)], lambda i, j: "gold" if i == 1 else "teal", 8, "metal")
    # Three tapered aluminium vanes curl around the lantern like a whorl of air.
    for i in range(3):
        a = i * TAU / 3 + .21
        def vane(r, ang, z):
            return (r * math.cos(a + ang), r * math.sin(a + ang), z)
        rows = [[vane(.38, -.05, 3.15), vane(.38, -.05, 3.37)],
                [vane(.65, -.26, 3.32), vane(.72, -.24, 3.68)],
                [vane(.86, -.53, 3.64), vane(.92, -.45, 3.97)],
                [vane(.96, -.70, 3.92), vane(.98, -.65, 4.02)]]
        mesh_strip(tower, rows, lambda j, k: "ivory" if j < 2 else "flame", "cloth",
                   normal=(math.cos(a), math.sin(a), 0))
        tube(tower, [row[0] for row in rows], [.032, .03, .025, .012], "wood", 5)
    tower.bake(root)
    light = MeshPart("BeaconLight", ring_center)
    drum(light, [(3.66, .035), (4.08, .23), (4.47, .37), (4.86, .21), (5.19, .028)],
         lambda i, j: "ivory" if i == 2 and j % 3 else "gold" if i > 0 else "flame", 8, "lamp", math.pi / 8)
    light.bake(root)


def main():
    if not bpy.app.background:
        raise RuntimeError("Use Blender in background mode with --factory-startup.")
    models = {"glider": glider, "manta": manta, "island": island, "beacon": beacon}
    selected = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else list(models)
    if not selected or any(name not in models for name in selected):
        raise ValueError("Model names are glider, manta, island and beacon.")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in selected:
        for obj in list(bpy.context.scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        models[name]()
        bpy.context.view_layer.update()
        output = DESTINATION / (name + ".glb")
        result = bpy.ops.export_scene.gltf(
            filepath=str(output), export_format="GLB", export_yup=True,
            export_animations=False, export_cameras=False, export_lights=False,
            export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_texcoords=False,
        )
        if "FINISHED" not in result:
            raise RuntimeError("Could not write " + str(output))
        print("BUILT", name, output.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
