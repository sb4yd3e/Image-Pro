#!/usr/bin/env python3
import hashlib
import json
import pathlib
import sys

output_dir = pathlib.Path(sys.argv[1])
manifest_dir = pathlib.Path(sys.argv[2])
base_url = sys.argv[3].rstrip("/")
catalog_path = pathlib.Path(sys.argv[4])

packages = []
for manifest_path in sorted(manifest_dir.glob("*.json")):
    package = json.loads(manifest_path.read_text())
    archive = output_dir / f"{package['id']}.zip"
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        while chunk := stream.read(4 * 1024 * 1024):
            digest.update(chunk)
    packages.append({
        "package": package,
        "archiveURL": f"{base_url}/{archive.name}",
        "archiveSHA256": digest.hexdigest(),
        "archiveBytes": archive.stat().st_size,
        "releaseNotes": "Initial separate model pack"
    })

catalog = {
    "schemaVersion": 1,
    "updatedAt": "2026-07-16",
    "packages": packages
}
catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
