#!/usr/bin/env python3
"""Capture the original backend's post-login packet stream as reference data.

Speaks the text/AMF3 wire mode of tools/fake_flash_server.py: register an
account, create a character, select it, log in, then record every server packet
until the stream goes quiet.
"""

from __future__ import annotations

import json
import socket
import struct
import sys
import time
from pathlib import Path

XOR_KEY = "nehc6666123.."
HOST = "127.0.0.1"
PORT = 18684


def xor_crypt(text: str) -> str:
    return "".join(
        chr(ord(char) ^ ord(XOR_KEY[index % len(XOR_KEY)]))
        for index, char in enumerate(text)
    )


def encode_u29(value: int) -> bytes:
    if value < 0x80:
        return bytes([value])
    if value < 0x4000:
        return bytes([((value >> 7) & 0x7F) | 0x80, value & 0x7F])
    if value < 0x200000:
        return bytes([
            ((value >> 14) & 0x7F) | 0x80,
            ((value >> 7) & 0x7F) | 0x80,
            value & 0x7F,
        ])
    return bytes([
        ((value >> 22) & 0x7F) | 0x80,
        ((value >> 15) & 0x7F) | 0x80,
        ((value >> 8) & 0x7F) | 0x80,
        value & 0xFF,
    ])


def inline_string(value: str) -> bytes:
    encoded = value.encode("utf-8")
    return encode_u29((len(encoded) << 1) | 1) + encoded


def build_client_packet(opcode: int, read_str: str) -> bytes:
    """Mirror build_amf3_client_packet: dynamic object with opCode and readStr."""
    payload = b"".join((
        b"\x0a\x0b\x01",
        inline_string("opCode"),
        b"\x04",
        encode_u29(opcode),
        inline_string("readStr"),
        b"\x06",
        inline_string(xor_crypt(read_str)),
        b"\x01",
    ))
    return struct.pack(">I", len(payload)) + payload


def read_u29(data: bytes, pos: int) -> tuple[int, int]:
    value = 0
    for shift in range(3):
        byte = data[pos]
        pos += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, pos
    value = (value << 8) | data[pos]
    return value, pos + 1


def decode_server_packet(payload: bytes) -> str:
    """Decode one AMF3 string packet body into its plaintext readStr."""
    if not payload or payload[0] != 0x06:
        return f"<non-string amf3: {payload[:32].hex()}>"
    length, pos = read_u29(payload, 1)
    if length & 1:
        text = payload[pos:pos + (length >> 1)].decode("utf-8", "replace")
        return xor_crypt(text)
    return f"<string ref {length >> 1}>"


class Probe:
    def __init__(self) -> None:
        self.sock = socket.create_connection((HOST, PORT), timeout=5)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.buffer = bytearray()
        self.packets: list[str] = []

    def send(self, opcode: int, read_str: str) -> None:
        self.sock.sendall(build_client_packet(opcode, read_str))

    def pump(self, seconds: float) -> list[str]:
        """Collect complete length-prefixed packets for a fixed window."""
        deadline = time.monotonic() + seconds
        fresh: list[str] = []
        while time.monotonic() < deadline:
            self.sock.settimeout(max(0.05, deadline - time.monotonic()))
            try:
                chunk = self.sock.recv(65536)
            except socket.timeout:
                break
            except OSError as exc:
                fresh.append(f"<socket error: {exc}>")
                break
            if not chunk:
                fresh.append("<server closed connection>")
                break
            self.buffer.extend(chunk)
            while len(self.buffer) >= 4:
                size = struct.unpack(">I", self.buffer[:4])[0]
                if len(self.buffer) < 4 + size:
                    break
                body = bytes(self.buffer[4:4 + size])
                del self.buffer[:4 + size]
                text = decode_server_packet(body)
                fresh.append(text)
                self.packets.append(text)
        return fresh

    def close(self) -> None:
        try:
            self.sock.close()
        except OSError:
            pass


def stamp() -> str:
    return str(int(time.time() * 1000))


def main() -> int:
    username = sys.argv[1] if len(sys.argv) > 1 else "probe001"
    password = sys.argv[2] if len(sys.argv) > 2 else "probe123"
    # ⚠ 不要写回 `原版协议抓包.json`：那是 `测试/后端协议回归测试.gd` 读 PacketBuilder 样本的
    # **夹具**（2026-10-09 我跑了一次探针就把它覆盖掉，那道门当场因为 samples 越界而红）。
    # 探针自己的抓取另起一个文件名，要并回夹具得人工挑步骤、别自动覆盖。
    out_path = Path(__file__).with_name("原版协议抓包_探针最新.json")

    probe = Probe()
    trace: list[dict[str, object]] = []

    def step(label: str, opcode: int | None, read_str: str | None, wait: float) -> None:
        if opcode is not None and read_str is not None:
            probe.send(opcode, read_str)
        received = probe.pump(wait)
        trace.append({
            "step": label,
            "sent": None if opcode is None else {"opCode": opcode, "readStr": read_str},
            "received": received,
        })
        print(f"--- {label} --- ({len(received)} packets)")
        for line in received:
            print(f"    {line[:400]}")

    step("hello", 1, f"1:79:{stamp()}", 1.0)
    credentials = json.dumps(
        {"userName": username, "password": password, "register": 1},
        ensure_ascii=False,
        separators=(",", ":"),
    )
    step("login", 6, f"6:{credentials}:{stamp()}", 2.0)
    step("serverstatus", 5, f"5:{stamp()}", 1.0)
    step("charlist", 9, f"9:1:{stamp()}", 2.0)

    # Discover the character id offered by the charlist response.
    character_id = 8
    for text in probe.packets:
        if '"jylx":10' in text:
            try:
                character_id = int(json.loads(text).get("id", character_id))
            except (ValueError, TypeError):
                pass
    print(f"\n[probe] using character id {character_id}\n")

    step("charselect", 10, f"10:{character_id}:1:{stamp()}", 2.0)
    # This is the packet that triggers enter_game and the full HUD bootstrap.
    step("playerloggedin", 11, f"11:{character_id}:{stamp()}", 8.0)
    step("idle", None, None, 4.0)

    out_path.write_text(
        json.dumps(trace, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nwrote {out_path}")
    probe.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
