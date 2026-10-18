# Reactio Draw naming helper: one SMILES per line in, one JSON line out.
# It only calls openclatura (MIT, https://github.com/lamalab-org/openclatura), installed with: pip install openclatura
import json
import sys


def say(o):
    sys.stdout.write(json.dumps(o) + "\n")
    sys.stdout.flush()


try:
    import openclatura
except Exception as e:  # not installed in this Python
    say({"err": "nopython", "msg": str(e)[:300]})
    sys.exit(3)

say({"ready": getattr(openclatura, "__version__", "?")})
for line in sys.stdin:
    smi = line.strip()
    if not smi:
        say({})
        continue
    try:
        r = openclatura.name(smi)
        ok = bool(getattr(r, "ok", False)) and bool(getattr(r, "name", ""))
        say({"name": r.name if ok else "", "msg": "" if ok else str(getattr(r, "error", "") or "no name")[:300]})
    except Exception as e:
        say({"name": "", "msg": str(e)[:300]})
