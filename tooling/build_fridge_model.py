"""Build the compact, texture-free ViNeat refrigerator GLB asset."""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "models" / "vineat-smart-fridge.glb"


MATERIALS = [
    ("Porcelain enamel", (0.91, 0.95, 0.92, 1.0), 0.18, 0.28),
    ("Warm white door", (0.98, 0.99, 0.98, 1.0), 0.12, 0.24),
    ("Mint accent", (0.08, 0.57, 0.39, 1.0), 0.22, 0.25),
    ("Brushed stainless steel", (0.48, 0.57, 0.53, 1.0), 0.78, 0.23),
    ("Dark glass", (0.055, 0.15, 0.14, 1.0), 0.42, 0.12),
    ("Soft graphite", (0.15, 0.20, 0.19, 1.0), 0.35, 0.35),
    ("Fresh leaf green", (0.17, 0.68, 0.39, 1.0), 0.08, 0.38),
    ("Warm brass", (0.76, 0.60, 0.32, 1.0), 0.72, 0.25),
]


class Scene:
    def __init__(self) -> None:
        self.geometry = {
            name: {"positions": [], "normals": [], "indices": []}
            for name, *_ in MATERIALS
        }

    def _face(self, material: str, vertices, normal) -> None:
        target = self.geometry[material]
        start = len(target["positions"]) // 3
        for vertex in vertices:
            target["positions"].extend(vertex)
            target["normals"].extend(normal)
        target["indices"].extend(
            (start, start + 1, start + 2, start, start + 2, start + 3)
        )

    def box(self, material: str, low, high) -> None:
        x0, y0, z0 = low
        x1, y1, z1 = high
        faces = [
            ((0, 0, 1), ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))),
            ((0, 0, -1), ((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0))),
            ((1, 0, 0), ((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1))),
            ((-1, 0, 0), ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0))),
            ((0, 1, 0), ((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0))),
            ((0, -1, 0), ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1))),
        ]
        for normal, vertices in faces:
            self._face(material, vertices, normal)

    def cylinder(self, material: str, center, axis, radius: float, length: float, segments: int = 14) -> None:
        def normalize(vector):
            size = math.sqrt(sum(value * value for value in vector))
            return tuple(value / size for value in vector)

        direction = normalize(axis)
        helper = (0.0, 1.0, 0.0) if abs(direction[1]) < 0.9 else (1.0, 0.0, 0.0)
        u = normalize(
            (
                direction[1] * helper[2] - direction[2] * helper[1],
                direction[2] * helper[0] - direction[0] * helper[2],
                direction[0] * helper[1] - direction[1] * helper[0],
            )
        )
        v = (
            direction[1] * u[2] - direction[2] * u[1],
            direction[2] * u[0] - direction[0] * u[2],
            direction[0] * u[1] - direction[1] * u[0],
        )
        start = tuple(center[i] - direction[i] * length / 2 for i in range(3))
        end = tuple(center[i] + direction[i] * length / 2 for i in range(3))

        def ring_point(origin, angle):
            return tuple(
                origin[i] + radius * (u[i] * math.cos(angle) + v[i] * math.sin(angle))
                for i in range(3)
            )

        for step in range(segments):
            a0 = 2 * math.pi * step / segments
            a1 = 2 * math.pi * (step + 1) / segments
            amid = (a0 + a1) / 2
            normal = tuple(u[i] * math.cos(amid) + v[i] * math.sin(amid) for i in range(3))
            self._face(
                material,
                (ring_point(start, a0), ring_point(start, a1), ring_point(end, a1), ring_point(end, a0)),
                normal,
            )

        for origin, normal, reverse in ((end, direction, False), (start, tuple(-n for n in direction), True)):
            for step in range(segments):
                a0 = 2 * math.pi * step / segments
                a1 = 2 * math.pi * (step + 1) / segments
                left, right = ring_point(origin, a0), ring_point(origin, a1)
                vertices = (origin, right, left) if reverse else (origin, left, right)
                start_index = len(self.geometry[material]["positions"]) // 3
                for point in vertices:
                    self.geometry[material]["positions"].extend(point)
                    self.geometry[material]["normals"].extend(normal)
                self.geometry[material]["indices"].extend(
                    (start_index, start_index + 1, start_index + 2)
                )

    def build(self) -> bytes:
        binary = bytearray()
        views, accessors, primitives = [], [], []

        def append_view(data: bytes, target: int):
            while len(binary) % 4:
                binary.append(0)
            offset = len(binary)
            binary.extend(data)
            view_index = len(views)
            views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
            return view_index

        for material_index, (material_name, *_rest) in enumerate(MATERIALS):
            geometry = self.geometry[material_name]
            positions = geometry["positions"]
            normals = geometry["normals"]
            indices = geometry["indices"]
            if not indices:
                continue
            position_bytes = struct.pack(f"<{len(positions)}f", *positions)
            normal_bytes = struct.pack(f"<{len(normals)}f", *normals)
            index_bytes = struct.pack(f"<{len(indices)}H", *indices)
            position_view = append_view(position_bytes, 34962)
            normal_view = append_view(normal_bytes, 34962)
            index_view = append_view(index_bytes, 34963)
            vertices = list(zip(*(iter(positions),) * 3))
            accessor_position = len(accessors)
            accessors.append(
                {
                    "bufferView": position_view,
                    "componentType": 5126,
                    "count": len(vertices),
                    "type": "VEC3",
                    "min": [min(vertex[i] for vertex in vertices) for i in range(3)],
                    "max": [max(vertex[i] for vertex in vertices) for i in range(3)],
                }
            )
            accessor_normal = len(accessors)
            accessors.append(
                {"bufferView": normal_view, "componentType": 5126, "count": len(vertices), "type": "VEC3"}
            )
            accessor_indices = len(accessors)
            accessors.append(
                {
                    "bufferView": index_view,
                    "componentType": 5123,
                    "count": len(indices),
                    "type": "SCALAR",
                    "min": [min(indices)],
                    "max": [max(indices)],
                }
            )
            primitives.append(
                {
                    "attributes": {"POSITION": accessor_position, "NORMAL": accessor_normal},
                    "indices": accessor_indices,
                    "material": material_index,
                    "mode": 4,
                }
            )

        gltf = {
            "asset": {"version": "2.0", "generator": "ViNeat procedural fridge model"},
            "scene": 0,
            "scenes": [{"nodes": [0]}],
            "nodes": [{"name": "ViNeat Smart Fridge", "mesh": 0}],
            "meshes": [{"name": "Mint and porcelain refrigerator", "primitives": primitives}],
            "materials": [
                {
                    "name": name,
                    "pbrMetallicRoughness": {
                        "baseColorFactor": color,
                        "metallicFactor": metallic,
                        "roughnessFactor": roughness,
                    },
                }
                for name, color, metallic, roughness in MATERIALS
            ],
            "buffers": [{"byteLength": len(binary)}],
            "bufferViews": views,
            "accessors": accessors,
        }
        json_chunk = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        json_chunk += b" " * ((-len(json_chunk)) % 4)
        bin_chunk = bytes(binary) + b"\0" * ((-len(binary)) % 4)
        total_length = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
        return b"glTF" + struct.pack("<II", 2, total_length) + struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk + struct.pack("<II", len(bin_chunk), 0x004E4942) + bin_chunk


def make_model() -> bytes:
    scene = Scene()
    # Cabinet and beveled-looking layered door faces.
    scene.box("Porcelain enamel", (-0.52, -0.94, -0.34), (0.52, 0.94, 0.34))
    scene.box("Brushed stainless steel", (-0.55, 0.86, -0.36), (0.55, 0.97, 0.38))
    scene.box("Soft graphite", (-0.52, -0.86, 0.33), (0.52, -0.78, 0.41))
    scene.box("Warm white door", (-0.48, 0.07, 0.34), (0.48, 0.82, 0.40))
    scene.box("Warm white door", (-0.48, -0.75, 0.34), (0.48, -0.02, 0.40))
    scene.box("Brushed stainless steel", (-0.50, -0.015, 0.39), (0.50, 0.045, 0.42))

    # Hinges and rounded vertical pull handles.
    for y in (0.56, 0.28, -0.24, -0.58):
        scene.cylinder("Brushed stainless steel", (0.50, y, 0.30), (0, 1, 0), 0.035, 0.10, 12)
    scene.cylinder("Brushed stainless steel", (0.385, 0.46, 0.45), (0, 1, 0), 0.022, 0.36, 18)
    scene.cylinder("Brushed stainless steel", (0.385, -0.38, 0.45), (0, 1, 0), 0.019, 0.25, 18)

    # Water/ice recess, touch display and subtle ViNeat leaf badge.
    scene.box("Brushed stainless steel", (-0.34, 0.15, 0.402), (-0.055, 0.55, 0.425))
    scene.box("Dark glass", (-0.315, 0.19, 0.425), (-0.08, 0.50, 0.434))
    scene.box("Soft graphite", (-0.29, 0.22, 0.436), (-0.105, 0.31, 0.452))
    scene.box("Brushed stainless steel", (-0.285, 0.33, 0.436), (-0.11, 0.35, 0.447))
    scene.box("Dark glass", (-0.30, 0.62, 0.402), (-0.07, 0.72, 0.417))
    for x in (-0.255, -0.205, -0.155, -0.105):
        scene.cylinder("Mint accent", (x, 0.67, 0.423), (0, 0, 1), 0.012, 0.009, 10)
    scene.cylinder("Mint accent", (-0.30, 0.77, 0.408), (0, 0, 1), 0.045, 0.016, 18)
    scene.box("Fresh leaf green", (-0.32, 0.755, 0.423), (-0.28, 0.785, 0.431))

    # Discreet food-note magnets on the lower door.
    scene.box("Mint accent", (-0.32, -0.54, 0.405), (-0.19, -0.42, 0.416))
    scene.box("Warm brass", (-0.16, -0.54, 0.405), (-0.03, -0.42, 0.416))
    scene.box("Brushed stainless steel", (0.01, -0.54, 0.405), (0.14, -0.42, 0.416))
    for x in (-0.28, -0.23, -0.12, -0.07, 0.05, 0.10):
        scene.box("Warm white door", (x, -0.63, 0.405), (x + 0.025, -0.61, 0.415))

    # Base feet and a narrow side ventilation grille.
    for x in (-0.39, 0.39):
        for z in (-0.24, 0.24):
            scene.cylinder("Soft graphite", (x, -0.97, z), (0, 1, 0), 0.045, 0.10, 12)
    for y in (-0.68, -0.62, -0.56, -0.50, -0.44):
        scene.box("Brushed stainless steel", (-0.558, y, -0.20), (-0.55, y + 0.018, 0.20))
    return scene.build()


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(make_model())
    print(f"Wrote {OUTPUT} ({OUTPUT.stat().st_size:,} bytes)")
