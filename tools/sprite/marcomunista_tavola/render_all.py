import sys, time, pickle; sys.path.insert(0, '/home/claude/marco2')
import numpy as np
from anim import SECTIONS
only = sys.argv[1].split(',') if len(sys.argv) > 1 else None
for name, fn in SECTIONS:
    if only and name not in only: continue
    t = time.time()
    frames = fn()
    np.save(f'/home/claude/marco2/out/frames_{name.replace(" ", "_").replace("(", "").replace(")", "")}.npy', np.stack(frames).astype(np.uint8))
    print(name, len(frames), f'{time.time() - t:.1f}s', flush=True)
