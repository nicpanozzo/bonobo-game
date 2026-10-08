# Esporta le azioni dello scheletro (#195) in animazioni.json: per ogni osso l'angolo rispetto al riposo
# a ogni fotogramma, e lo spostamento della radice. È il formato che legge la prova di #196 in Godot.
# Le IK sono già "cotte": si leggono le pose calcolate da Blender, non le chiavi.
# Uso, con Blender 4.2:
#   blender bonobot_rig.blend --background --python tools/blender/esporta_animazioni.py -- animazioni.json
import json
import math
import sys

import bpy

PX = 0.01  # deve essere lo stesso di costruisci_rig.py


def art_angle(v):
    """Angolo di un vettore del piano XZ visto nel disegno (y in giù), in gradi."""
    return math.degrees(math.atan2(-v.z, v.x))


def wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def export(path):
    scene = bpy.context.scene
    arm = next(o for o in scene.objects if o.type == "ARMATURE")
    bones = [b for b in arm.data.bones if b.use_deform]
    rest = {}
    for b in bones:
        own = art_angle(b.tail_local - b.head_local)
        par = art_angle(b.parent.tail_local - b.parent.head_local) if b.parent else 0.0
        rest[b.name] = own - par
    root_rest = arm.data.bones["root"].head_local.copy()
    fps = scene.render.fps / scene.render.fps_base
    out = {"character": arm.name.replace("_rig", ""), "units": "gradi rispetto al riposo; radice in pixel a 2x", "animations": {}}
    keep = arm.animation_data.action if arm.animation_data else None
    if not arm.animation_data:
        arm.animation_data_create()
    for action in bpy.data.actions:
        arm.animation_data.action = action
        start, end = (int(f) for f in action.frame_range)
        tracks = {b.name: {"rot": []} for b in bones}
        tracks["root"]["pos"] = []
        for f in range(start, end + 1):
            scene.frame_set(f)
            t = round((f - start) / fps, 4)
            for b in bones:
                pb = arm.pose.bones[b.name]
                own = art_angle(pb.tail - pb.head)
                par = art_angle(pb.parent.tail - pb.parent.head) if pb.parent else 0.0
                tracks[b.name]["rot"].append([t, round(wrap(own - par - rest[b.name]), 3)])
            d = arm.pose.bones["root"].head - root_rest
            tracks["root"]["pos"].append([t, round(d.x / PX, 3), round(-d.z / PX, 3)])
        # niente tracce piatte: pesano e non servono
        for name in list(tracks):
            for key in list(tracks[name]):
                vals = [k[1:] for k in tracks[name][key]]
                if all(v == vals[0] for v in vals) and all(abs(x) < 1e-3 for x in vals[0]):
                    del tracks[name][key]
            if not tracks[name]:
                del tracks[name]
        loop = action.use_cyclic if hasattr(action, "use_cyclic") else action.name in ("idle", "walk", "fall", "ledge", "tumble")
        out["animations"][action.name] = {"length": round((end - start) / fps, 4), "loop": bool(loop), "tracks": tracks}
    if keep:
        arm.animation_data.action = keep
    json.dump(out, open(path, "w", encoding="utf-8"), separators=(",", ":"))
    print(f"Scritto {path}: {len(out['animations'])} animazioni")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    export(args[0] if args else "animazioni.json")
