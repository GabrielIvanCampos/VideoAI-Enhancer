import site
from pathlib import Path

def patch_file(p):
    p = Path(p)
    if not p.exists():
        return False
    s = p.read_text(encoding="utf-8")
    old = "from torchvision.transforms.functional_tensor import rgb_to_grayscale"
    new = "from torchvision.transforms.functional import rgb_to_grayscale"
    if old in s:
        p.write_text(s.replace(old, new), encoding="utf-8")
        return True
    return False

roots = []
try:
    roots += site.getsitepackages()
except Exception:
    pass
try:
    roots.append(site.getusersitepackages())
except Exception:
    pass

found = False
for root in roots:
    p = Path(root)
    if p.exists():
        for f in p.rglob("degradations.py"):
            if f.parent.name == "data" and f.parent.parent.name == "basicsr":
                found = patch_file(f) or found

print("BasicSR/torchvision: OK" if found else
      "BasicSR/torchvision: linha antiga nao encontrada; sem patch necessario.")
