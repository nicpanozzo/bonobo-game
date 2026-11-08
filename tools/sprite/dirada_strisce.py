#!/usr/bin/env python3
# Uso: python3 tools/sprite/dirada_strisce.py <id> [--max 8192]   poi npm run export:godot
#
# Le strisce troppo larghe non si caricano: oltre il limite delle texture della scheda video (8192 px su molti
# telefoni, 16384 sui computer) il lottatore diventa un quadrato colorato. Lo script tiene un fotogramma ogni k
# finché la striscia sta nel limite, sempre compreso il fotogramma d'impatto (hitFrame), e riscrive in
# src/shared/characters.ts fps, hitFrame, startFrame e activeEnd di quello stato, così i tempi restano uguali.
import json, math, os, re, sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))
TS = os.path.join(ROOT, "src/shared/characters.ts")


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit("uso: dirada_strisce.py <id> [--max 8192]")
    cid = a[0]
    limit = int(a[a.index("--max") + 1]) if "--max" in a else 8192
    sprite = json.load(open(os.path.join(ROOT, "godot/data/game.json")))["characters"][cid]["sprite"]
    fw, folder = sprite["frameWidth"], os.path.join(ROOT, "public", sprite["dir"])
    per = limit // fw  # fotogrammi che stanno nel limite
    src = open(TS, encoding="utf-8").read()
    start = src.index(f'id: "{cid}"')
    end = src.index("\n  },", start)
    start = re.compile(r"animations: (\w+\()?\{").search(src, start).start()  # le animazioni, non le zone dei colpi
    if start > end:
        sys.exit(f"{cid}: non trovo le animazioni in characters.ts")
    block = src[start:end]
    for state, anim in sprite["animations"].items():
        if anim["src"] != state:
            continue
        path = os.path.join(folder, f"{state}.png")
        img = Image.open(path).convert("RGBA")  # le strisce sono a palette: si riquantizzano dopo
        n = img.width // fw
        if img.width <= limit:
            continue
        k = math.ceil(n / per)
        hit = int(anim.get("hitFrame", 0))
        keep = [i for i in range(n) if (i - hit) % k == 0]
        while len(keep) > per:
            keep = keep[:-1] if keep[-1] != hit else keep[1:]
        out = Image.new(img.mode, (len(keep) * fw, img.height))
        for j, i in enumerate(keep):
            out.paste(img.crop((i * fw, 0, (i + 1) * fw, img.height)), (j * fw, 0))
        out.quantize(256, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)
        # il punto della presa degli oggetti (docs/clip-flow/pose-oggetti.md): un punto per fotogramma, gli stessi tenuti
        mani = os.path.join(folder, "mani.json")
        hands = json.load(open(mani)) if os.path.exists(mani) else {}
        if len(hands.get(state, [])) == n:
            hands[state] = [hands[state][i] for i in keep]
            with open(mani, "w") as f:
                f.write("{\n" + ",\n".join(f' "{s}": {json.dumps(v, separators=(",", ":"))}' for s, v in sorted(hands.items())) + "\n}\n")

        def near(f):  # il fotogramma tenuto più vicino, senza superare
            return max(j for j, i in enumerate(keep) if i <= f) if f >= keep[0] else 0

        new = {"fps": max(1, round(anim["fps"] / k))}
        for key in ("hitFrame", "startFrame", "activeEnd"):
            if key in anim:
                new[key] = keep.index(hit) if key == "hitFrame" else near(int(anim[key]))
        m = re.search(rf"(\n\s+{state}: \{{)([^}}]*)(\}})", block)
        if m:
            body = m.group(2)
            for key, v in new.items():
                body = re.sub(rf"{key}: [0-9.]+", f"{key}: {v}", body)
            block = block[: m.start(2)] + body + block[m.end(2):]
        else:  # lo stato viene da communitySprite: una riga nuova in cima alle animazioni
            keys = ", ".join(f"{k}: {v}" for k, v in new.items())
            loop = "true" if anim.get("loop") else "false"
            spread = block.find("...")  # dopo le animazioni di communitySprite, che altrimenti la sovrascrivono
            at = block.index("\n", spread if spread >= 0 else block.index("{"))
            line = f"\n        {state}: {{ {keys.replace(f'fps: {new['fps']}', f'fps: {new['fps']}, loop: {loop}')} }}, // un fotogramma ogni pochi (tools/sprite/dirada_strisce.py)"
            block = block[:at] + line + block[at:]
        print(f"{state}: {n} -> {len(keep)} fotogrammi (uno ogni {k}), {new}")
    open(TS, "w", encoding="utf-8").write(src[:start] + block + src[end:])


main()
