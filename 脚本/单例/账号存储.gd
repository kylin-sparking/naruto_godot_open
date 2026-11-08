extends Node

const SAVE_PATH := "user://launcher.json"
const KEY := "HYSJ-LAUNCHER-1"

var server_url := "http://127.0.0.1:19280"
var bgm_muted := false
var accounts: Array = []


func _ready() -> void:
	load_config()


func load_config() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	server_url = String(data.get("server_url", server_url))
	bgm_muted = bool(data.get("bgm_muted", bgm_muted))
	var raw: Variant = data.get("accounts", [])
	if typeof(raw) == TYPE_ARRAY:
		accounts = raw


func save_config() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"server_url": server_url,
		"bgm_muted": bgm_muted,
		"accounts": accounts,
	}, "    "))


func account_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in accounts:
		if typeof(entry) == TYPE_DICTIONARY:
			names.append(String(entry.get("username", "")))
	return names


func index_of(username: String) -> int:
	for i in accounts.size():
		if String(accounts[i].get("username", "")) == username:
			return i
	return -1


func peek_password(username: String) -> String:
	var i := index_of(username)
	if i < 0:
		return ""
	return _decode(String(accounts[i].get("password", "")))


func remember(username: String, password: String) -> void:
	var i := index_of(username)
	var entry := {"username": username, "password": _encode(password)}
	if i < 0:
		accounts.append(entry)
	else:
		accounts[i] = entry
	save_config()


func forget(username: String) -> void:
	var i := index_of(username)
	if i >= 0:
		accounts.remove_at(i)
		save_config()


# 混淆而非加密：只是为了不在磁盘上留下明文密码。
func _encode(text: String) -> String:
	return _to_hex(_xor(text.to_utf8_buffer()))


func _decode(cipher: String) -> String:
	return _xor(_from_hex(cipher)).get_string_from_utf8()


func _to_hex(buf: PackedByteArray) -> String:
	var out := ""
	for byte in buf:
		out += "%02x" % byte
	return out


func _from_hex(hex_text: String) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i + 1 < hex_text.length():
		out.append(hex_text.substr(i, 1).hex_to_int() << 4 | hex_text.substr(i + 1, 1).hex_to_int())
		i += 2
	return out


func _xor(buf: PackedByteArray) -> PackedByteArray:
	var key_bytes := KEY.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(buf.size())
	for i in buf.size():
		out[i] = buf[i] ^ key_bytes[i % key_bytes.size()]
	return out
