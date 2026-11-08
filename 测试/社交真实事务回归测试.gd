extends SceneTree

const BACKEND_SCRIPT := preload("res://脚本/单例/后端连接.gd")
# 同伴角色名由夹具给：服务端限 2-12 位（"CodexSocialPeer" 有 15 位建不出来），
# 而加好友是按名字查找的，名字不一致就永远找不到对方。
const PEER_NAME_FALLBACK := "社交同伴"

var _primary
var _peer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var PEER_NAME := OS.get_environment("NW_SOCIAL_PEER_NAME")
	if PEER_NAME.is_empty():
		PEER_NAME = PEER_NAME_FALLBACK
	_primary = root.get_node_or_null("BackendConnection")
	if _primary == null:
		_fail("缺少主后端连接单例")
		return
	_primary.sync_character()
	if not await _wait_until(func(): return _primary.in_game and int(_primary.character_id) == 1, 10000):
		_fail("主角色无法进入真实后端：%s - %s" % [_primary.status, _primary.detail])
		return

	_peer = BACKEND_SCRIPT.new()
	_peer.name = "SocialPeerBackend"
	root.add_child(_peer)
	_peer.connect_backend("naruto", "123456", false)
	var peer_id := int(OS.get_environment("NW_SOCIAL_PEER_ID"))
	if peer_id <= 0:
		_fail("夹具没有提供临时角色编号")
		return
	if not await _wait_until(func(): return _peer.authenticated, 10000):
		_fail("第二连接无法登录测试账号")
		return
	if _find_character_id(_peer, PEER_NAME) <= 0:
		_peer.characters.append({"id": peer_id, "name": PEER_NAME})
	if not _peer.select_character(peer_id):
		_fail("第二连接无法选择临时角色")
		return
	if not await _wait_until(func(): return _peer.in_game and int(_peer.character_id) == peer_id, 10000):
		_fail("临时角色无法进入游戏")
		return

	_primary.request_friend_list()
	_peer.request_friend_list()
	if not await _wait_until(func(): return _primary.authoritative_friends.is_empty() and _peer.authoritative_friends.is_empty(), 4000):
		_fail("夹具没有提供干净的好友状态")
		return
	# 服务端加好友收角色编号（原版 requestAddFriend(int) 亦然），不是名字。
	if not _primary.request_friend_add(peer_id):
		_fail("好友申请请求未发送")
		return
	if not await _wait_until(func(): return _has_friend_request(_peer, 1), 5000):
		_fail("好友申请没有持久化并推送给临时角色")
		return
	if not _peer.request_friend_accept(1):
		_fail("接受好友请求未发送")
		return
	if not await _wait_until(func(): return _has_friend(_primary, peer_id) and _has_friend(_peer, 1), 5000):
		_fail("接受后没有生成双向好友关系")
		return
	if not _primary.request_friend_delete(peer_id):
		_fail("删除好友请求未发送")
		return
	if not await _wait_until(func(): return not _has_friend(_primary, peer_id) and not _has_friend(_peer, 1), 5000):
		_fail("删除好友没有清理双向关系")
		return
	if not _primary.request_friend_block(peer_id):
		_fail("拉黑请求未发送")
		return
	if not await _wait_until(func(): return _has_blocked(_primary, peer_id), 5000):
		_fail("黑名单没有由服务端持久化")
		return
	if not _primary.request_friend_unblock(peer_id):
		_fail("解除拉黑请求未发送")
		return
	if not await _wait_until(func(): return not _has_blocked(_primary, peer_id), 5000):
		_fail("解除黑名单没有更新权威状态")
		return

	if not _primary.request_party_create("CodexSocialTeam"):
		_fail("创建队伍请求未发送")
		return
	if not await _wait_until(func(): return bool(_primary.authoritative_party.get("joined", false)), 5000):
		_fail("服务端没有创建单人队伍")
		return
	var party_id := int(_primary.authoritative_party.get("id", 0))
	if party_id <= 0 or not _primary.request_party_invite(PEER_NAME):
		_fail("队伍编号无效或邀请请求未发送")
		return
	if not await _wait_until(func(): return _has_party_invite(_peer, party_id), 5000):
		_fail("组队邀请没有持久化并推送给临时角色")
		return
	if not _peer.request_party_accept(party_id):
		_fail("接受组队邀请请求未发送")
		return
	if not await _wait_until(func(): return _party_member_count(_primary) == 2 and _party_member_count(_peer) == 2, 5000):
		_fail("接受邀请后双方没有收到两人队伍快照")
		return
	if not _primary.request_party_change_leader(peer_id):
		_fail("移交队长请求未发送")
		return
	if not await _wait_until(func(): return int(_primary.authoritative_party.get("leader_id", 0)) == peer_id and int(_peer.authoritative_party.get("leader_id", 0)) == peer_id, 5000):
		_fail("队长移交没有同步到全队")
		return
	if not _primary.request_party_leave():
		_fail("离队请求未发送")
		return
	if not await _wait_until(func(): return not bool(_primary.authoritative_party.get("joined", true)) and _party_member_count(_peer) == 1, 5000):
		_fail("离队没有保留新队长的单人队伍")
		return
	if not _peer.request_party_disband():
		_fail("解散队伍请求未发送")
		return
	if not await _wait_until(func(): return not bool(_peer.authoritative_party.get("joined", true)), 5000):
		_fail("队长没有解散队伍")
		return

	print("社交真实事务回归测试：通过（好友申请/接受/删除/黑名单、队伍创建/邀请/接受/换队长/离开/解散）")
	_primary.disconnect_backend()
	_peer.disconnect_backend()
	quit(0)

func _find_character_id(backend, character_name: String) -> int:
	for character in backend.characters:
		if String(character.get("name", "")) == character_name:
			return int(character.get("id", 0))
	return 0

func _has_friend(backend, character_id: int) -> bool:
	for friend in backend.authoritative_friends:
		if int(friend.get("character_id", 0)) == character_id:
			return true
	return false

func _has_friend_request(backend, character_id: int) -> bool:
	for request in backend.authoritative_friend_requests:
		if int(request.get("character_id", 0)) == character_id:
			return true
	return false

func _has_blocked(backend, character_id: int) -> bool:
	for entry in backend.authoritative_blocked:
		if int(entry.get("character_id", 0)) == character_id:
			return true
	return false

func _has_party_invite(backend, party_id: int) -> bool:
	for invite in backend.authoritative_party.get("invites", []):
		if int(invite.get("party_id", 0)) == party_id:
			return true
	return false

func _party_member_count(backend) -> int:
	return (backend.authoritative_party.get("members", []) as Array).size()

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _fail(message: String) -> void:
	push_error("社交真实事务回归测试：失败 - %s" % message)
	if _primary != null:
		_primary.disconnect_backend()
	if _peer != null:
		_peer.disconnect_backend()
	quit(1)
