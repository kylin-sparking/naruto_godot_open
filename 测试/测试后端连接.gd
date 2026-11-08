extends "res://脚本/单例/后端连接.gd"

var sent_requests: Array[Dictionary] = []

func send_game_request(opcode: int, content: String) -> bool:
	sent_requests.append({"opcode": opcode, "content": content})
	return true

func send_game_packet(opcode: int, payload := PackedByteArray()) -> bool:
	sent_requests.append({"opcode": opcode, "content": payload.hex_encode(), "payload": payload.duplicate()})
	return true
