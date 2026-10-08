# Costruisce in Blender lo scheletro e i pezzi di un lottatore da rig.json (#195).
# Uso, con Blender 4.2:
#   blender --background --python tools/blender/costruisci_rig.py -- public/assets/characters/bonobot/rig bonobot_rig.blend
# oppure dal pannello Scripting di Blender, cambiando CARTELLA qui sotto.
# Crea: un'armatura nel piano XZ (si guarda dal davanti, -Y), un piano per ogni pezzo appeso al suo osso,
# il contorno d'inchiostro come piano separato, le IK di braccia e gambe con il loro polo, una camera ortografica.
# Le animazioni si fanno ruotando le ossa (o spostando i controlli ik_*); esporta_animazioni.py le scrive in JSON.
import json
import math
import os
import sys

import bpy
from mathutils import Vector

CARTELLA = "public/assets/characters/bonobot/rig"
PX = 0.01  # metri di Blender per pixel del disegno a 2x
STEP_Z = 0.02  # distanza in profondità tra un livello e l'altro (davanti = verso la camera, -Y)


def art(x, y):
    """Da coordinate del disegno (y in giù) al piano XZ di Blender (z in su)."""
    return Vector((x * PX, 0.0, -y * PX))


def build(folder, out_path=None):
    rig = json.load(open(os.path.join(folder, "rig.json"), encoding="utf-8"))
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    # --- armatura
    arm_data = bpy.data.armatures.new(rig["character"] + "_rig")
    arm = bpy.data.objects.new(rig["character"] + "_rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig["bones"]:
        eb = arm_data.edit_bones.new(b["name"])
        eb.head = art(*b["head"])
        eb.tail = art(*b["tail"])
        eb.align_roll(Vector((0, -1, 0)))  # asse Z dell'osso verso la camera: si ruota attorno a Z, nel piano
        eb.use_deform = b.get("deform", True)
    for b in rig["bones"]:
        if b["parent"]:
            arm_data.edit_bones[b["name"]].parent = arm_data.edit_bones[b["parent"]]
    bpy.ops.object.mode_set(mode="OBJECT")

    # Solo rotazione nel piano: le altre assi bloccate, così chi anima non esce dal 2D per sbaglio
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.lock_rotation = (True, True, False)
        pb.lock_location = (False, True, False) if pb.name == "root" or pb.name.startswith(("ik_", "pole_")) else (True, True, True)
        pb.lock_scale = (True, True, True)

    # --- IK di braccia e gambe: il polo che lascia la posa a riposo com'è
    for ik in rig.get("ik", []):
        end = arm.pose.bones[ik["chain"][-1]]
        c = end.constraints.new("IK")
        c.target = arm
        c.subtarget = ik["target"]
        c.pole_target = arm
        c.pole_subtarget = ik["pole"]
        c.chain_count = len(ik["chain"])
        best = None
        for angle in range(-180, 180, 5):
            c.pole_angle = math.radians(angle)
            bpy.context.view_layer.update()
            err = sum((arm.pose.bones[n].matrix.to_translation() - arm.data.bones[n].head_local).length
                      + (arm.pose.bones[n].tail - arm.data.bones[n].tail_local).length for n in ik["chain"])
            # un osso girato su se stesso manderebbe i pezzi dietro al corpo: quella soluzione si scarta
            if any(arm.pose.bones[n].matrix.col[2].y > -0.99 for n in ik["chain"]):
                err += 100.0
            if best is None or err < best[0]:
                best = (err, angle)
        c.pole_angle = math.radians(best[1])
    bpy.context.view_layer.update()

    # --- pezzi: un piano con l'immagine, appeso al suo osso; il contorno è un altro piano
    for p in rig["pieces"]:
        layers = [("image", p["z"])]
        if "ink" in p:
            layers.append(("ink", p["inkZ"]))
        for key, z in layers:
            name = p["name"] + ("_ink" if key == "ink" else "")
            img = bpy.data.images.load(os.path.abspath(os.path.join(folder, p[key])), check_existing=True)
            mesh = bpy.data.meshes.new(name)
            x0, y0, w, h = p["x"], p["y"], p["width"], p["height"]
            depth = -z * STEP_Z
            corners = [art(x0, y0 + h), art(x0 + w, y0 + h), art(x0 + w, y0), art(x0, y0)]
            mesh.from_pydata([c + Vector((0, depth, 0)) for c in corners], [], [(0, 1, 2, 3)])
            uv = mesh.uv_layers.new()
            for i, co in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
                uv.data[i].uv = co
            mesh.materials.append(_material(name, img))
            obj = bpy.data.objects.new(name, mesh)
            bpy.context.scene.collection.objects.link(obj)
            # appeso all'osso senza spostarsi: il genitore è l'osso, la matrice inversa tiene la posa a riposo
            obj.parent = arm
            obj.parent_type = "BONE"
            obj.parent_bone = p["bone"]
            bone = arm.data.bones[p["bone"]]
            obj.matrix_parent_inverse = (arm.matrix_world @ bone.matrix_local @ _tail_offset(bone)).inverted()

    # --- camera ortografica dal davanti, inquadra il personaggio
    cam_data = bpy.data.cameras.new("camera")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 3.2
    cam = bpy.data.objects.new("camera", cam_data)
    cam.location = (0.2, -10, 1.1)
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    bpy.context.scene.render.film_transparent = True
    # Tanti piani trasparenti uno sopra l'altro: con il limite di Cycles (8) i pezzi in fondo diventano neri
    bpy.context.scene.cycles.transparent_max_bounces = 256
    bpy.context.scene.cycles.max_bounces = 256
    bpy.context.scene.render.fps = 24
    if out_path:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(out_path))
    return arm


def _tail_offset(bone):
    # Con parent_type BONE il figlio parte dalla CODA dell'osso: si compensa
    from mathutils import Matrix
    return Matrix.Translation(Vector((0, bone.length, 0)))


def _material(name, img):
    """Il disegno così com'è: colore come emissione (non prende luce), trasparenza dall'alfa del PNG."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    if hasattr(mat, "surface_render_method"):  # EEVEE di Blender 4.2: trasparenza vera per i bordi morbidi
        mat.surface_render_method = "BLENDED"
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 1.0
    links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    return mat


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(args[0] if args else CARTELLA, args[1] if len(args) > 1 else None)
