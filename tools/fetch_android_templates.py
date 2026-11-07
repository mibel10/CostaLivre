"""Fetch only Android APKs from the official Godot export-template ZIP."""
import hashlib
import io
import json
import urllib.request
import zipfile
from pathlib import Path

URL = "https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
TARGET = Path(__file__).resolve().parents[1] / ".build-tools" / "godot-4.7.2"


class RemoteZip(io.RawIOBase):
    def __init__(self):
        super().__init__()
        self.position = 0
        self.cached_start = -1
        self.cached = b""
        request = urllib.request.Request(URL, headers={"Range": "bytes=0-0"})
        with urllib.request.urlopen(request, timeout=90) as response:
            if response.status != 206:
                raise RuntimeError("Server did not support byte ranges")
            self.length = int(response.headers["Content-Range"].split("/")[-1])

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.length + offset)
        return self.position

    def read(self, count=-1):
        if count < 0:
            count = self.length - self.position
        count = min(count, self.length - self.position)
        if count <= 0:
            return b""
        if not (self.cached_start <= self.position and self.position + count <= self.cached_start + len(self.cached)):
            self.cached_start = self.position
            end = min(self.length - 1, self.position + max(count, 4 * 1024 * 1024) - 1)
            request = urllib.request.Request(URL, headers={"Range": f"bytes={self.position}-{end}"})
            with urllib.request.urlopen(request, timeout=90) as response:
                if response.status != 206:
                    raise RuntimeError("Server ignored a range request")
                self.cached = response.read()
        start = self.position - self.cached_start
        data = self.cached[start:start+count]
        self.position += len(data)
        return data


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    manifest = {"source": URL, "version": "4.7.2.stable", "files": {}}
    with zipfile.ZipFile(RemoteZip()) as archive:
        for filename in ("android_debug.apk", "android_release.apk"):
            item = next(info for info in archive.infolist() if info.filename.endswith("/" + filename))
            destination = TARGET / filename
            if not destination.exists() or destination.stat().st_size != item.file_size:
                temporary = destination.with_suffix(".apk.part")
                print(f"Downloading {filename}: {item.file_size / 1048576:.1f} MiB", flush=True)
                count = 0
                with archive.open(item) as source, temporary.open("wb") as output:
                    while chunk := source.read(1024 * 1024):
                        output.write(chunk)
                        count += len(chunk)
                        if count % (8 * 1024 * 1024) == 0:
                            print(f"  {count / 1048576:.0f} MiB", flush=True)
                temporary.replace(destination)
            digest = hashlib.file_digest(destination.open("rb"), "sha256").hexdigest()
            manifest["files"][filename] = {"bytes": destination.stat().st_size, "sha256": digest}
            print(f"Ready: {filename}", flush=True)
    (TARGET / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
