"""Download the small, attributed visual assets used by the game (no packages)."""
import concurrent.futures
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "assets"
BASE = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models"

def fetch(url, path):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "CostaLivrePrototype/1.0 (asset setup)"})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read()
    path.write_bytes(data)
    return f"{path.name}: {len(data)} bytes"

def main():
    jobs = []
    for name in ["CarConcept", "CesiumMan"]:
        jobs.append((f"{BASE}/{name}/glTF-Binary/{name}.glb", f"models/{name}.glb"))
        jobs.append((f"{BASE}/{name}/LICENSE.md", f"licenses/{name}.md"))
    for name, kind in [("asphalt_02", "texture"), ("concrete_wall_006", "texture"), ("kloppenheim_06_puresky", "sky")]:
        request = urllib.request.Request(f"https://api.polyhaven.com/files/{name}", headers={"User-Agent": "CostaLivrePrototype/1.0"})
        with urllib.request.urlopen(request, timeout=45) as response:
            info = json.load(response)
        if kind == "texture":
            for channel, api_key in [("diff", "Diffuse"), ("nor_gl", "nor_gl"), ("rough", "Rough")]:
                formats = info[api_key]["1k"]
                ext = "jpg" if "jpg" in formats else "png"
                jobs.append((formats[ext]["url"], f"textures/{name}_{channel}.{ext}"))
        else:
            jobs.append((info["hdri"]["1k"]["hdr"]["url"], "sky/coast.hdr"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for result in executor.map(lambda pair: fetch(*pair), jobs):
            print(result)

if __name__ == "__main__":
    main()
