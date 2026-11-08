extends Node

## 协议层：与一键端通信、把回包解成权威状态、发请求。
##
## 通信通道（**动这个文件之前先读这一段**）
## ----------------------------------------
## 本客户端与一键端**恒走 AMF3 通道**，不发也不收原始 Flash 二进制帧：
##   * **出**：`_send_bridge_request()` 发的永远是 AMF3 对象（首字节 `0x0a`）。
##   * **入**：`_read_available_packets()` → `_handle_amf_frame()` 只认 AMF3 字符串，
##     解密后要么是 JSON 字典（`_handle_bridge_dictionary`），要么是冒号文本（`_handle_bridge_text`）。
##   * **服务端侧**：`fake_flash_server.py:12021` 的 `_parse_and_handle` 只在"包首字节为 0"时
##     切到 `wire_mode="original"`；AMF3 包恒留在 `amf3` 模式，只回文本/JSON，
##     **从不下发 `data` 字节数组**。
##   * 客户端自己的状态栏也写着「已连接原版游戏服 AMF3 通道」（见 `_process` 里的 `_set_status`）。
##
## ⚠️ 所以 2026-09-25 把**整条原始二进制路删掉了**：`_handle_packet` 及其 18 个分支、
##    `_send_packet`、`_parse_character`、`DECODE_BOX` 逆表…… 共 **26 个函数 / 347 行**。
##    它们本来就是**不可达**的，但看着像活的 —— 曾害人按"两条路要人肉对齐"去判断。
##    真值仍在 `2.2.3\tools\fake_flash_server.py`，要查协议去那里，别照这段历史写。
##
## 字段真值出处
## ------------
## 字段号 / 字段序 / opcode 一律**以服务端为准**（`fake_flash_server.py` 的
## `StatType` :1058、`ServerOpcode` :788、`ClientOpcode` :656）；
## 原版 AS3 的 `CocoStatType.as` / `SendOpCodes.as` / `ReceiveOpCodes.as` 可交叉校验。
## ⚠️ `测试/原版协议抓包.json` **只覆盖登录握手**（1/5/6/9/10/11），不能当字段序基线。

const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const 禁寻路地图 := preload("res://脚本/地图/禁寻路地图.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 获得提示文案 := preload("res://脚本/界面/获得提示文案.gd")
const 头顶飘字规则 := preload("res://脚本/界面/头顶属性飘字.gd")

signal connection_status_changed(status: String, detail: String)
signal character_received(payload: Dictionary)
signal stats_received(payload: Dictionary)
signal skill_received(skill_id: int, level: int, master_level: int)
## 心法熟练度涨了（`DataCenter.as:1578-1588` 那一个 `if` 同时喂的两处之一）：
## 角色头顶那行蓝字（`世界` 侧消费）与右下角那一行（`获得提示`）都由它驱动。
signal 心法熟练度增加(名: String, 增量: int)
## 属性帧里某一档变了 ⇒ 头顶飘字（`DataCenter.as:2416-2781` 那 12 个 `case` 里的第一句话）。
## 判据（哪一档飘 / 只增还是都飘 / 吃不吃"进游戏 5 秒"那个抑制 / 什么颜色）全在
## `脚本/界面/头顶属性飘字.gd` 那张表里，这里只负责"先减旧值再问表"。
signal 属性飘字(前缀: String, 数值: int, 是增: bool, 颜色: Color)
signal npc_dialog_received(npc_id: int, message: String)
signal inventory_received(items: Array, equipment: Dictionary)
signal inventory_delta_received(flag: int, fields: Array)
signal item_change_result_received(opcode: int, result: Dictionary)
signal item_effect_received(kind: String, state: Dictionary)
signal npc_shop_received(shop: Dictionary)
## 神秘商店（`OPEN_SECRET_SHOP 324`）专属回帧。原版把这张货架解成
## `SecretShopInfo`（独立对象），和 NPC 商店的 `NPCShopInfo` 完全不是一回事 ——
## 本工程以前挤进 `authoritative_npc_shop`，结果**上一个 NPC 的货架被整片盖掉**。
## 消费者：`窗口管理._on_mystery_shop` → `功能窗口._render_mystery_shop`。
signal mystery_shop_received(shop: Dictionary)
signal shop_transaction_received(code: int)
signal storage_received(items: Array, gold: int, capacity: int)
## 「仓库被服务端**开**出来了」（`330:1` 那一串分块全部到齐）⇒ 只有这一条该开窗，
## 存取/整理那些后续帧**不**重开（原版 `Client.as:4263-4273 onOpenStorage` 只挂在
## `OpenStorageInfo` 上，别的 Storage 帧走别的路）。背包那颗「随身仓库」等的是这一帧。
signal storage_opened()
## 背包扩充回包（服务端复用 1084 那条 opCode，见下方 OP_CASH_CATEGORY_CAPACITY 分支）。
signal bag_capacity_received(capacity: int)
signal storage_full_received()
signal pets_received(pets: Array, capacity: int)
signal pet_spawned(state: Dictionary)
signal pet_removed(character_id: int, pet_unique_id: int, position: int)
signal pet_action_received(action: int, result: Dictionary)
signal chat_received(message: Dictionary)
signal quest_received(opcode: int, fields: Array)
signal cultivation_received(kind: String, state: Dictionary)
signal copy_state_received(state: Dictionary)
signal hang_state_received(state: Dictionary)
## 1283 回帧：服务端把 45 个配置值 + keyData + 13 个扩展值按**位置**发来（无键名），
## 解成字典再发出去（`_handle_char_config_text`）。
signal char_config_received(config: Dictionary)
signal cash_shop_received(items: Array, total: int, source: String)
signal cash_shop_capacity_received(capacity: int)
signal cash_item_info_received(item: Dictionary)
signal guild_state_received(state: Dictionary)
## 族长邀我入族（`1552:16`）。字段名照 `FamillyManager.onAcceptFamillyInvite:331-338`
## 那六行赋值抄 —— `charId` 是**族长角色号**（托盘去重比的就是它，见 `邀请托盘.去重键`），
## `id` 才是拿去同意/拒绝的**家族 id**，两位混用会一发都换不回。
signal family_invite_received(邀: Dictionary)
## 有人申请加入我的家族（`1552:8`，服务端只推给族长）。
## 字段照原版 `FamillyManager.onFamillyApply:148-160` 那四行赋值：`name` / `id`（申请者角色号）/
## `face` / `level`；另外补 `playerName` / `famillyName` / `charId` 给共用渲染器认。
signal family_apply_received(申请: Dictionary)
## 家族商城权威商品列表与购买结果（`1552:23` / `1552:20`）。
signal guild_shop_received(items: Array, contribution: int)
## 玩家搜索结果（家族搜索窗）
signal char_search_received(results: Array)
## 地图族旗列表（`1815` action 0；家族旗帜窗的「势力对比」用它）
signal flag_list_received(flags: Array)
## **当前地图上那面族旗**变了（生成/销毁/掉血）。空字典 = 这张图现在没有族旗。
## 真值：原版 `MapFlagProcessor.handleMapFlagAction`（`MapFlagProcessor.as:227-256`）的动作表 ——
##   1 = `actionSpawnMapFlag`（`flagOid` + `MapFlagInfo`）、2 = `actionDestroyMapFlag`、
##   4 = `actionChangeMapFlagHp`。`onFlag_spawnFlag` → `FlagHandler.addFlag`（`:134-159`）。
signal map_flag_changed(flag: Dictionary)
## Boss 房门确认（`1349 PORTAL_PANEL`）。服务端 `_request_boss_map_confirmation:15067` 对
## 「专门 Boss 房间」（`wang_boss_entries()` 的 11 张图 + 世界 Boss 图）**先把换图挂起**，
## 回一条 `1349:<request_id>:<正文>`；客户端回 `<request_id>:<1|0>` 之后才 `_warp_to_map`。
## 正文是服务端给的整句（`fake_flash_server.py:15101-15104`），客户端只负责弹框、不造文案。
signal portal_panel_received(request_id: int, message: String)
## 家族重名检测结果（服务端 `1552:19:<0|1>`，原版
## `FamillyCreateWindow.checkNameResult(available)`）。1 = 可用、0 = 已被占用。
signal guild_name_checked(available: bool)
signal friend_state_received(state: Dictionary)
## 打探结算（`61:8`，回包形状由本工程服务端定：`8:<errorCode>[:<线>:<图>:<x>:<y>]`）。
## `errorCode`：0 = 探到了（带 `channel/map/x/y`），1 = 背包里没有乾坤密卷，2 = 对方不在线。
## 原版 `FriendProcessor.as` case 8 → `onFriend_findEnemyResult` → `FriendWindow2.daTanResult`
## → `MPromptWindow.updateDaTanView`（`MPromptWindow.as:313-347`），三档文案全在那边。
signal find_enemy_result_received(info: Dictionary)
signal party_state_received(state: Dictionary)
## 任务列表（`444` 的 action 3/4）。`accepted` 带进度与状态、`available` 只有 id
## —— 名字/类型/等级要到 `数据/任务.json` 里按 id 查（原版就是两处分开放的）。
signal quest_list_received(accepted: Array, available: Array)
## 单条任务的进度刷新（`444` 的 action 1/2）。
signal quest_progress_received(info: Dictionary)
## 随机名回帧（`1028 GENERATED_CHAR_NAME`）。原版 `Client.onGeneratedCharName` 是空函数，
## 名字真正落到 `CreateCharWindow3.setName()` ⇒ 由创角窗自己接。
signal char_name_generated(char_name: String)
## 建角成功回帧（`17 ADD_NEW_CHAR_ENTRY`）。原版 `LoginProcessor` 同一支。
signal character_created(character: Dictionary)
signal gift_state_received(state: Dictionary)
## 充值活动（`1814`）。四种子命令各自到达时发一次，`command` 是 cmd 号。
signal czhuodong_state_received(state: Dictionary)
signal exchange_state_received(state: Dictionary)
signal fudai_state_received(state: Dictionary)
## 亲热天堂（小地图「藏宝图」）的状态帧：格式见 `_handle_treasure_text`。
signal treasure_state_received(state: Dictionary)
## 排行榜（`1346` cmd 1/2）列表帧：`{"tab": 榜单号, "entries": 行数组, "rank": 服务端名次, "江湖": bool}`。
signal ranking_state_received(state: Dictionary)
## 头顶那摞"忍云"榜单徽记（`1346` cmd 0）：`角色号 → Array[int]`，元素是**榜单号**（menuId）。
## 原版链路 `PaiHangProcessor.handlePaiHangUpdateTitles:62-91` → `CharacterHandler.updatePaiHangTitle:765-773`
## → 那个人 `Character.updatePaiHangTitle:1184-1203`。自己那份登录就推（服务端 `:14338`），
## 别人那份在**有人打开排行榜**时由 `_send_ranking_title_update(visible=True)` 广播给视野内的号。
signal 榜单徽记收到(角色号: int, 榜号列表: Array)
signal achievement_state_received(state: Dictionary)
signal activity_state_received(state: Dictionary)
signal card_state_received(state: Dictionary)
signal chest_state_received(state: Dictionary)
signal buff_fusion_received(state: Dictionary)
signal heal_state_received(state: Dictionary)
## 服务端主动推的"目标信息"一帧（原版 `Client.onTargetInfo()` 的等价物）。
## 三种形状共用一个号，靠第 3 段 `type` 分档：0 怪、1 玩家、2 地图旗。
signal target_info_received(状: Dictionary)
## 「查看信息」点下去之后服务端回的**那个人**的完整档案（下行号 58、档 4：`58:4:<CharacterFullInfo>`）。
## 原版是 `Client.as:3009-3035 onCharInfo` → `CharacterFullInfo.decode:133` → 那扇别人的人物窗；
## 本工程叫法不同但同一件事：数据只在这一条帧里，本地 `map_players` 那份不够（只有外观与坐标）。
signal 他人详细信息收到(档: Dictionary)
## 八门「开通穴道」的延迟引爆倒计时（`1290:1`，原版 `Client.onMaiDelayExplode`）。
## 收到就该**关掉人物窗、N 秒后再开回来** —— 到点时服务端已结算完，重渲染会把穴位点亮。
signal 八门倒计时(秒: int)
## 别人的忍术境界总层数（下行 `1348:<角色号>:<总层数>`，原版 `UPDATE_CHAR_SKILL_LEVEL`：
## `AllInOneProcessor.handleUpdateCharAllSkillLevel:3377` → `CharacterHandler.onForeignCharAllskillLevel:801`
## → 那个人 `Character.setTotalSkillLevel`）。⚠ 这一帧原版**只按二进制发**；服务端文本腿
## 是本工程补的（`_skill_level_payload`），为了让人物头顶那枚境界图标也能出现在别人身上
## （用户 2026-10-20 报：忍术境界达标时形象下不显示境界标志）。
signal 他人忍术境界收到(角色号: int, 总层数: int)
## 赠花那一支的两条帧（#263，逐条出处见 `真值/窗口/赠花窗.md` §②）。
## `58:2:…` = 那个人的花档（`FlowerCharInfo` 的文本桥形态，服务端 `:20400-20448` 十个段）；
## 原版 `AllInOneProcessor.as:2627-2670` 把 cmd 2 交给 `onCharFlowerInfo` → `receiveRefreshFlowerWindow`。
signal 花档收到(档: Dictionary)
## `61:44:<发号>:<收号>:<发名>:<朵>:<花号>` ⇒ 送花结算（`FriendProcessor.as:391-393` → `onFriend_receiveFlower`）。
## ⚠ 两边都发这一条（服务端 `:23088-23095` 给发送方与目标各一份），**只有 `收号 == 我` 那一侧才塞托盘**
## （`MarryTableManager.as:206-214` 那两判）⇒ 消费者别判"来没来"，要判"是不是发给我的"。
signal 收花帧收到(条: Dictionary)
## 改名族（`CHANGE_NAMES 2330`，收/发同号）回帧。第 2 段是**结果码**，四档共用一个号：
## `0` 改名成功（消息=新名，原版 `Client` 侧随后要求重登）、`1` 失败（消息=原因）、
## `10` **自己**的历史名表、`12` **别人**的历史名表（消息=那个人的当前名）。
## 名单在第 4 段，服务端用 `@` 连接、空表写 `-`（`fake_flash_server.py:_send_change_name_result`）。
signal 改名回帧收到(结果: int, 消息: String, 名单: PackedStringArray)
## 羁绊（求婚）四条下行，全部 `61` = `OP_FRIEND_REQUEST` 同一族的子命令（bbe5521 解码器要用）：
## `14` = 我点了菜单「羁绊」⇒ 对面那份资料；`17` = 别人向我求羁绊；`18` = 被拒；`19`/`20` = 结成。
signal bond_preview_received(人: Dictionary)
signal bond_invite_received(邀: Dictionary)
signal bond_refused_received(拒: Dictionary)
signal bond_established_received(婚: Dictionary)
## 61:23 解除羁绊成功（**两边各发一条**）⇒ 消费者要关「配偶」那一侧的窗、撤托盘那一格。
signal bond_dissolved_received()
## 随身摊位（`STALL_ACTION 1296`，收/发同号）回帧。原版是 `StallDataManager` 那一套，
## 这里只把服务端给的**原样行表**拆开，不猜物品负载的字段含义（负载解码见 §行解码）。
signal stall_state_received(状: Dictionary)
## 摊位列表回帧（下行 `1296:0:<总数>:<行表>`，`StallProcessor.handleStallAction_listStalls:74-104`）。
## ⚠ 这一条**不开窗** —— 原版 `StallDataManager.onStallList:88-94` 只有一句
## `if (stallListWindow) setPageData(total, stalls)`：窗实例不在台上就整帧丢掉。
signal stall_list_received(总: int, 行表: Array)
## 摊主侧那三条**增量**帧（`StallProcessor.handlePetAction:106-126` 的 `switch(action)` 里 2/3/4 三支）。
## ⚠ 三条都**不开窗**：原版只往"已经在台上"的那扇里塞/摘行
## （`StallDataManager.onStallAddItem:80-86` 全文是 `if (myStallWindow) upShelf(item)`）。
signal stall_listing_added(行: Dictionary)
signal stall_listing_removed(摊主号: int, uid: int)
## 下行 `1296:4:<买家名>:<物品名>:<金币>:<元宝>`（`handleStallAction_addLog:185-208`）。
## 服务端**只发给摊主**（买家那边收到的是整条 `1296:1:` 重推）⇒ 这一条就是摊主「出售记录」的唯一来源。
signal stall_sale_log(买家名: String, 物品名: String, 金币: int, 元宝: int)
## 荣誉积分（`2323:8:<积分>`，下行动作 8 = `MuyeBattleProcessor.action_updateFamePoint:77-94`）。
## ⚠ 这是**唯一**能刷新荣誉积分的帧：原版 `MuYeDaZhanManager.onMuyeBattle_updateFamePoint:599-625`
## 是 12 个下行动作里**只往 `cashShopWindow.updateRongYu` 送的那一条**，其余动作号跟这扇窗无关
## ⇒ 商城开着时服务端没有"打开荣誉页就发一次积分"的帧，登录时显示 0 是原版行为，不是漏接。
## 兑换成功/失败/背包满**三条都回这一帧**（服务端 `:30031,30036,30046`）⇒ 客户端只更新计数，
## 不自己判成功（详见 `真值/窗口/商城窗口.md` 荣誉页一节）。
signal 荣誉积分帧(积分: int)
## 交易族（上行 119 / 下行 335，`fake_flash_server.py:710,858`）的四条事件。
## `trade_invite_received` 只带 `{id,name}` —— 原版这时候**不开窗**，往邀请托盘塞一格
## （`Client.as:6391-6398` → `CueManage.addMsg(CueGird.TYPE_TRADE, …)`）。
## `trade_started` = 服务端回了 `335:22`（双方成交开始），这时候才开窗（`Client.as:853-873`）。
signal trade_invite_received(邀: Dictionary)
signal trade_started(状: Dictionary)
signal trade_updated(状: Dictionary)
signal trade_closed(原因: String)
## 师徒族（`77`）。逐条出处见 `真值/窗口/师徒推荐窗.md` §⑤⑥。
## `tutor_recommended` 的 `数据` 就是原版 `CommendTeacherOrPrentice.setData()` 收的那个对象
## （师傅档 `{tutors:[…], online:n}` / 徒弟档 `{students:[…], count:n}`），
## `托盘类型` 直接给 `邀请托盘` 的 9/10，省得消费者再翻译一次。
signal tutor_recommended(托盘类型: int, 数据: Dictionary)
## 有人来拜/来收（`77:4` / `77:5`）⇒ 原版 `ShituListManage` 弹 `AgreestToturWindow`。
signal tutor_requested(档: int, 号: int, 名: String)
## 关系列表（`77:14`）：同意/拒绝之后**双方各回一条**，是玩家唯一看得见的结果
## （原版 `onTutor_addTutor/addStudent/refuse*` 全是空函数）。
signal tutor_list_received(师父: Dictionary, 徒弟们: Array)
signal jieyin_state_received(state: Dictionary)
## 升阶**结果帧**（动作 2）单拎一条出来，给「自动提升」那个**客户端循环**当心跳：
## 原版四族各自的成功/失败都从这一帧驱动（结印 = 2318:2 走 `jieyin_state_received`，
## 写轮眼/柔拳/轮回六道 = 1821/2307/2313 的动作 2 走这条）。
## 为什么不用 `cultivation_received` 判：那一发每帧都发（动作 0 是阶段/熟练度、1 是祝福值、
## 2 才是结果），而状态字典里**没有 `action` 字段**（八门与别族共用它，塞进去会污染界面口径）
## ⇒ 判据只能由解析处给，不能让宿主去猜。见 `功能窗口._收到修炼结果帧`。
signal 修炼结果帧(族: String, 成功: bool, 用神符: bool)
signal anqi_state_received(state: Dictionary)
signal server_message_received(message: String)
signal entered_game(character_id: int)
signal login_status_received(login_status: int)
signal character_list_received(characters: Array, max_characters: int)
signal player_spawned(state: Dictionary)
signal player_removed(character_id: int)
signal player_moved(state: Dictionary)
## 有人出招（服务端 `1328` PlayerAttackInfo 广播）。旁观者要据此让**他那具身体**播出手动作。
signal player_cast(state: Dictionary)
signal monster_spawned(state: Dictionary)
signal monster_removed(object_id: int)
signal monster_killed(object_id: int, animation: int)
signal monster_moved(state: Dictionary)
signal monster_attacked(state: Dictionary)
## `critical` = 服务端权威暴击位（来自 **184** 出手帧的 `damage*bsk`，见 `_handle_mob_attack_info_text`）。
## `受击动画` = 这条伤害要不要让怪播 `hit1`：**184 出手=true**、**243（DoT/相位跳伤）=false**
## ——原版 `addMonsterDamage` 只画数字、受击动画走出手特效（§3.88.4）。
## `由自己打出` / `打完还活着` 只 184（出手结算）那支给得出（帧里本来就带这两位）；
## 243（DoT/相位跳伤）两支都给 false/true —— 震屏与击飞的原版条件正是
## `isEarthquake && 是自己打出的` 与 `!damage.alive && bsk && !boss`
## （`AbstractSkillEffect.as:245-274`、`:321-324`），少了这两位在线就永远不抖、不飞
## （用户 2026-10-11 报「暴击了但没有震动」：离线腿接了，在线腿没接）。
signal monster_damaged(object_id: int, damage: int, critical: bool, 受击动画: bool,
		由自己打出: bool, 打完还活着: bool)
signal monster_skill_hit(object_id: int, skill_id: int, damage: int)
signal monster_hp_changed(object_id: int, hp_percent: int)
signal npc_spawned(state: Dictionary)
signal map_drop_spawned(state: Dictionary)
## `动画` = 原版 `RemoveItemInfo.animation`：0=过期 1=无动画 **2=拾取** 5=宠物捡。
## ⚠ 掉落物的**拾取动画要由这一帧驱动**（原版 `DropItemHandler.removeDropItem():401-422`：
##   `animation >= 2` 才起动画、并把 `picker` 设成 `cid` 那个角色/宠物），
##   原来只发 object_id ⇒ 客户端只能"点下去就自己播"，隔着半张地图也会把东西拽过来。
signal map_drop_removed(object_id: int, 动画: int, 角色号: int, 是宠物: bool)
signal player_damaged(state: Dictionary)
## 1291(LIANZHAN) 两条子命令（原版 `LianzhanProcessor.as:60-84`：cmd=1 是连斩数、cmd=2 是阶段）。
## 服务端发法：`1291:1:<count>`（`fake_flash_server.py:49194`）与
## `1291:2:<stage>:<expRate>:<remainSec>:<totalSec>:<characterId>`（`:49101`，走 `_send_visible` ⇒ 别人也收得到）。
signal lianzhan_count_changed(count: int)
signal lianzhan_stage_changed(阶段: int, 经验加成: int, 剩余秒: int, 总秒: int, 角色号: int)
## 199(UPDATE_CHAR_LOOK)：一条帧同时改「身体用哪套(face) / 肤色 / 性别 / 灵气脸 / 穿了哪些部位」。
## 服务端发法（现查 `fake_flash_server.py:17596 _send_character_look`，走 `_send_visible` ⇒ 别人也收得到）：
##   `199:<角色号>:0:0:<性别>:<肤色>:<脸>:0:0:<部位&物品@…>:-:<灵气脸>`
## 原版读法：`AllInOneProcessor.as:3398-3415` → `Client.as:10487-10490` → `CharacterHandler.as:283-358`。
## ⚠ 服务端把这条文本翻成二进制时（`:61241-61270`）第 11 段落进了 AS3 的 `itemEffect` 槽、
##   `lingEquip` 拿的是第 7 段(恒 0) ⇒ **真 Flash 客户端在 original 模式下读到的灵气脸会是错的**；
##   本工程读的是文本，按上面这个字段序取，不受影响。这条记进 #190 的未收口。
signal char_look_changed(角色号: int, 性别: int, 肤色: int, 脸: int, 灵气脸: int, 装备串: String)
## 199 的第 13 位（灵器颜色 id）。⚠ 不能加进 `char_look_changed`：头像面板那边
## 连着一条**固定 6 参**的 lambda，改信号参数个数会让它接不上（10-25）。
signal ling_color_changed(角色号: int, 颜色: int)
## 十拳剑「改变外观」——原版 `LingEquipProcessor` 的 4/5/6 三支。
## `灵器外观列表收到(脸表, 色表)`：4 的回帧；每行字典见 `_parse_ling_qi_*_rows`。
## `灵器外观结果(动作, 成功, 值)`：5=换脸、6=换色。
signal ling_qi_face_list_received(faces: Array, colors: Array)
signal ling_qi_appearance_result(action: int, success: bool, value: int)
signal vip_state_received(level: int)
signal pk_mode_received(character_id: int, mode: int)
signal weather_received(weather_type: int)
signal buffs_received(buffs: Array)
## 1811 系统增益：动作 0 = 上/刷新（剩余/总秒有效），1 = 收掉（只看类型）。
## 文本形态 `1811:0:<type>:<value>:<剩余秒>:<总秒>` / `1811:1:<type>`。
signal system_buff_received(动作: int, 类型: int, 值: float, 剩余秒: int, 总秒: int)
## 1825:0 跨服战场频道列表（`列表` 每项 `{channel_id,name,load}` + 帧尾那个 `最大载入`）。
signal war_panel_received(列表: Array, 最大载入: int)
## 2306 竞技场（`PK_ACTION`）一族。分派**照 AS3 那 12 档**（`PkProcessor.handlePkAction:306-357`）
## 解好字段名再发出去 ⇒ 窗那一侧只认名字、不再碰段序。`值` 的键按动作分：
## `0` 面板 `{已用,上限,冷却,连胜,距明天,排名,候选[],战报[]}`、`1/8/11 {排名…}`、`2 候选[]`、
## `3 战报[]`、`4 {已用,上限,冷却,连胜,距明天}`、`5/6 {秒}`、`7 {胜,阅历}`、`9 英雄[]`、`10 一条战报{}`。
## 字段名逐个对 `PkCandidate/PkCharInfo/PkHero/BattleReportItem.decode` 的原序（真值 §2B）。
signal 竞技场帧(动作: int, 值: Dictionary)
## 201/202：**别人**身上的 buff（旁观者侧）。`角色号` = 被施加者，`列表` 每项
## `{type,value,skill_id,skill_level,duration_ms}`（与 35 那一条同一行式，只是多了角色号这一段）。
signal foreign_buff_received(角色号: int, 列表: Array, 延迟毫秒: int)
signal foreign_buff_cancelled(角色号: int, 类型表: Array)
## 203 队伍成员状态帧：`<角色号>:<hp>:<maxhp>:<mp>:<maxmp>`（服务端 `_party_member_stats_payload`）。
signal party_member_stats_received(角色号: int, hp: int, 最大hp: int, mp: int, 最大mp: int)
## 1329 玩家打玩家（原版 `TakePlayerDamageInfo`）：段序照服务端 `PLAYER_DAMAGE_PLAYER` 那条拼装。
signal player_damage_by_player_received(信息: Dictionary)
## 1330 旁观者看到的别人血条（原版 `onPlayerHpInfo` ⇒ `setHpBarValue` + `showHpBar(true)`）。
signal player_hp_received(角色号: int, 最大hp: int, hp: int)
## 1313 双修合击（原版 `CoupleAttackInfo` → `AttackHandler.addAttack`）。
signal couple_attack_received(信息: Dictionary)
## 修行收益信息：累计秒数 / 可领经验 / 可领查克拉精华（原版 UI 的「人物精华储量」）
signal biguan_info_received(seconds: int, exp_gain: int, zq_gain: int)
## 系统消息倒计时：每项 {text: 描述, seconds: 剩余秒}
signal huodong_countdowns_received(rows: Array)
## 首领刷新列表（`WANG_LIST 1351` 回帧，夹具走 `send_json`）：
## 每项 = {index, mobId, mapId, alive, nextTime, name…, 其余静态列由夹具的 wang_boss_entries 带来}
signal wang_list_received(rows: Array)
## 秘笈合成结果（`1352:0:<0/1>`）。原版消费 `operationResultHandler:342-347`：**只在 true 时**
## 刷新页面（`itemDatachanged(null)`），失败不弹话、物品增减由通用背包帧表达。
signal can_juan_result_received(success: bool)
## 意志（Spirit）回帧族 `1823:<cmd>:<参数…>`（2026-10-03 接 `SPIRIT_ACTION 1823`）。
## 单点转发给会话拆状态（cmd 0/1/2/3/4/5/6/7/8 的字段表见 `游戏会话._on_backend_spirit_action`；
## 与原版 `SpiritProcessor.handleSpiritAction:181-220` 同名同序，text 通道把 binary 的
## `int/string 流`换成冒号/`&`/`@` 分隔——口径 = 项目内夹具 `handle_spirit_action` 一族）。
signal spirit_action_received(command: int, args: Array)
## 百炼忍传进度/阅历回帧 `1572:0:<progress>:<points>`（2026-10-19 意志完善计划 P0-1）。
## 服务端 `_send_pve_status`（实机 `fake_flash_server.py:30856`）：`pve_progress` = 已通关层数、
## `pve_points` = **阅历**（意志学习/卖灰色意志都花它，`_gain_spirit_from_teacher:22494` 扣
## `pve_points`、`_pick/_sell_spirit_panel_items` 灰色自动卖成阅历）。
## 原版 `PveActionProcessor` 同一条；本工程只取阅历那一格（进度归百炼页，不在本轮）。
## ⚠ 2026-10-19 前客户端**没有这条** ⇒ 学习页「阅历」恒 0、学习钮永远被「阅历不足」挡死
## （`意志窗口.gd` 原来读的 `player_stats.spirit_experience` 全工程没有任何地方写）。
signal pve_status_received(progress: int, points: int)
## 精英副本回帧 `1828:<cmd>:<参数…>` → 会话拆（cmd0=进入列表，cmd1=进本结果走地图帧/系统聊天，不在此拆）。
signal hero_action_received(command: int, args: Array)
## 服务端说"这个任务接上了"（42 且 questStatus=START、updateType=0）。
## 原版在这里弹 `MessageTipPane2.TYPE_ACCEPT_QUEST`，默认（设置没勾"关闭自动交接"）
## **根本不显示、直接自动点一次确定** ⇒ 自动赶路。见 `MessageTipPane2.as:386-424`。
signal quest_accepted(quest_id: int)
## 服务端说"这个任务交付了"（51）。原版 `QuestDataManager.showOverQuest()`：
## 先在屏幕上方挂一枚 `questOverTip` 大横幅，再走 `showCompleteTip` → 自动赶路去交付 NPC。
signal quest_completion_shown(quest_id: int)
## 服务端推了一行 `513 UPDATE_NPC_QUEST_STATUS`（某枚 NPC 的任务态变了）。
## ⚠ **必须有这条信号**：原版是 `NPCHandler.as:133-140 updateQuestStatusPacket` 收到就**当场**
## `NPC.setQuestStatus()` + `SmallMapHandler.setNpcStatus()` 两头一起换皮。本工程小地图那边是
## 0.5 秒轮询所以看着是对的，而**头顶那枚只在"生成时"与"点过一次之后"算** ⇒ 513 晚到（进图时
## NPC 先生成、状态包后到）或交付后重推，头顶都不动 —— 用户 2026-10-09 实机报的正是这两下。
signal npc_quest_status_updated(object_id: int, status: int)
## 右下角那列「获得提示」（原版 `NoticePnl.addNotice`）的一条文本，已经是 BBCode。
##
## 原版不是"谁获得谁自己画"，而是**两处算差值、一处画**：
## * `DataCenter.updateOneStatu`（`DataCenter.as:2399-2792`）—— 属性包每来一条，拿**上一帧的值**算差；
## * `ItemManager`（`ItemManager.as:410-459 / 500-588` 等）—— 背包帧按 `fromDrop` 与数量差算获得/失去；
## 两边都只调 `API.ui.content.noticePnl.addNotice(文案)`，画由那块面板负责（`NoticePnl.as`）。
## ⇒ 本工程把这两处的**差值判定放在这里**（差值的旧值只有客户端这份权威镜像知道），
##   画交给 `脚本/界面/获得提示层.gd`，文案在 `脚本/界面/获得提示文案.gd`。
signal 获得提示(文本: String)
## 二级密码（2309）的下行帧。`动作` = 帧体第一个字节（**和上行动作号是两套编号**，
## 同 `1296` 那族「上行 1 是搜索、下行 1 是摊位内容」的坑）；`值` = 按 `handleAction:310-358`
## 那 11 个 `case` 读出来的数组（int 在前、utf 按各 case 的读序）。
## 消费者：`窗口管理._on_second_password`（逐条照 `Client.as` 那 11 个 `onSecondLevelPassword_*`）。
signal 二级密码帧(动作: int, 值: Array)

const CLIENT_VERSION := 79
const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 18684
const CONNECT_TIMEOUT := 6.0
const XOR_KEY := "nehc6666123.."

const OP_DISTRIBUTE_AP := 84
## 洗点（还原已花的潜能点）。⚠ 与 84 差一位、方向相反：84 是**加**点、83 是**还原**点。
## 原版 `SendOpCodes.REWASH_AP` → `AllInOneProcessor.requestRewashAp:1845-1853` 四个 short，
## 顺序 = `UI.as:1143-1146` 的 `apAtk, apDef, apDex, apPhy`。
const OP_REWASH_AP := 83
const OP_DISTRIBUTE_SP := 87
const OP_CHARACTER_INFO := 94
## 服务端 `ServerOpcode.TARGET_INFO = 1284`（`fake_flash_server.py:868`）。
## ⚠ 别和客户端的 `OP_BIGUAN_INFO = 1286` 混 —— 差两位、都是"信息帧"。
const OP_TARGET_INFO := 1284
## 目标信息条那排钮要用到的另三条（号 = 服务端 `ClientOpcode`：`PLAYER_INTERACTION=119`、
## `STALL_ACTION=1296`、`TUTOR=77`）。
const OP_PLAYER_INTERACTION := 119
## 交易族的**下行**号：`ServerOpcode.PLAYER_INTERACTION = 335`（`fake_flash_server.py:858`）。
## ⚠ 上行 119 / 下行 335 **不同号**（摆摊是收发同号 1296，别拿它当先例推交易）。
const OP_TRADE_RESPONSE := 335
const OP_STALL_ACTION := 1296
## Boss 房门确认，**收发同号 1349**（原版 `ReceiveOpCodes.PORTAL_PANEL = SendOpCodes.PORTAL_PANEL = 1349`；
## 服务端 `ClientOpcode.PORTAL_PANEL = ServerOpcode.PORTAL_PANEL = 1349`，`fake_flash_server.py:791,956`）。
const OP_PORTAL_PANEL := 1349
## 木叶大战／荣誉兑换（`MUYE_BATTLE`，**收发同号 2323**：服务端
## `ClientOpcode.MUYE_BATTLE = ServerOpcode.MUYE_BATTLE = 2323`，`fake_flash_server.py:762,939`）。
## 上行动作 0/1/2/3 = 进战场/要面板/离场/兑换（`MuyeBattleProcessor.as:63-75,38-45`）；
## 下行动作号 0..11 是另一套含义（`handleZhongQiuHuodongAction:135-186` 的 switch）
## ⇒ **同号不同义**，别拿上行号去猜下行（同摆摊 `1296:1:` 那对反例）。
const OP_MUYE_BATTLE := 2323
const OP_TUTOR := 77
const OP_QUEST_ACTION := 104
## 任务列表的**请求**（`SendOpCodes.QUEST_INFO`）。回包走 `444 QUEST_INFO_UPDATE`
## ——原版 `QuestProcessor.requestCanStartQuestInfo`（`:179-184`）发 byte 2 要"可接列表"，
## byte 1 要"已接列表"。**443 只是请求号，客户端不会收到 443**。
const OP_QUEST_INFO := 443
## 两条**任务回帧**，本工程以前一条都没接（`match opcode` 里没有 42 也没有 51）：
## · `42 SHOW_STATUS_INFO`（`ReceiveOpCodes.as:52`）—— 接任务那条。`AllInOneProcessor.as:4051`
##   先 `readUnsignedByte()` 取 infoType（`StatusInfoType.QUEST = 1`），再 `QuestData.decode`
##   （`data/quest/QuestData.as:44-62`：int questId、ubyte questStatus、…），
##   `:4196-4203` 在 `questStatus == START(1) && updateType == 0` 时 `onStartQuest(questId)`
##   → `Client.as:997-1001` → `QuestDataManager.startQuest()` → 那条提示/自动赶路就出生在这里。
## · `51 SHOW_QUEST_COMPLETION`（`ReceiveOpCodes.as:132`）—— 交付那条。
##   `QuestProcessor.as:46-63` 只 `readInt()` 一个 questId → `Client.as:1191-1195`
##   → `QuestDataManager.showOverQuest()`（`:737-756`：横幅 + `showCompleteTip`）。
const OP_SHOW_STATUS_INFO := 42
const OP_SHOW_QUEST_COMPLETION := 51
## `StatusInfoType.as:6-22` 与 `QuestStatus.as:6-10`
const STATUS_INFO_QUEST := 1
const QUEST_STATUS_START := 1
## 任务动作，逐条照 `QuestActionType.as`（服务端 `QuestAction` 同值）。
const QUEST_ACTION_START := 1
const QUEST_ACTION_COMPLETE := 2
const QUEST_ACTION_FORFEIT := 3
const OP_ITEM_MOVE := 68
const OP_ITEM_SORT := 66
## 拆分堆叠（`SendOpCodes.as:204`）。2.2.3 服务端 handle_item_split 读 fields[0]/[1]。
const OP_ITEM_SPLIT := 1332
const OP_CHAT := 1536
## `MessagePosition.CHAR_NOTICE`（`com/mxw/data/chat/MessagePosition.as:24`）——
## 服务端所有玩法拒绝/告知用的那一位（黄字浮动提示，**不是**聊天记录）。
const POS_CHAR_NOTICE := 512
const OP_SKILL_CHANGE := 1330
const OP_MAI := 1287
# 修行（闭关）收益：请求 1284，回应 1286 BIGUAN_INFO。包形按**原版**（不是服务端方言）：
# `AllInOneProcessor.as:3271-3276` 查询 = `byte 2`；`:4272-4278` 领取 = `byte 1` + `byte(双倍?1:0)`；
# `:3882-3889` 答随机问 = `byte 3` + `int`。下行四 int = seconds/expGain/zqGain/problem（`:1899-1922`）。
# 服务端同源实现：`fake_flash_server.py:17946 handle_biguan`、`:18022 _send_biguan_info`；
# 收益口径 `:18004 _calculate_biguan_rewards`：经验 = 分钟 × 等级 × 50，精华 = 分钟 × 等级 ÷ 10，上限 12 小时。
# 左侧「系统消息」那列活动倒计时。请求 1809:0，回应 1809:2:<描述>&<剩余秒>@<描述>&<剩余秒>…
# 依据 2.2.3 tools/fake_flash_server.py:27683 _send_huodong_countdowns()：
#   text 模式下 encoded = "@".join(f"{description}&{remaining}")，帧形如 "1809:2:<encoded>"。
const OP_HUODONG_ACTION := 1809
const OP_BIGUAN := 1284
const OP_BIGUAN_INFO := 1286
const OP_AN_QI := 1817
const OP_XIE_LUN_YAN := 1821
const OP_ROU_QUAN := 2307
const OP_LUN_HUI_YAN := 2313
const OP_JIE_YIN := 2318
const OP_ITEM_CHANGE := 1040
const OP_STONE_MERGE_RESPONSE := 1042
## 已装备的寄坏虫四格整包（原版 `ReceiveOpCodes.EQUIPED_KUNCHONG = 2054`，
## `AllInOneProcessor.handleEquipedKunChongPacket` → `Client.onEquipedKunChong`
## → `KunChongManager.onRecieveKunChongList`）。上线一份（`_send_client_full_init_state`
## 末尾）+ 每次穿/卸/强化后都补一份（`_send_equipped_kun_chong`）。
## ⚠️ 2052 那份装备快照**不含**它们：服务端 `EQUIPPED_INFO` 支只收 `-199 <= slot < 0`，
## 昆虫四位是 -200..-203 ⇒ 这条是寄坏虫回显的**唯一来源**（2026-10-17 巡检 #9）。
const OP_EQUIPED_KUNCHONG := 2054
## 首领（尾兽）刷新信息。请求=空 body；回帧夹具用 `send_json({"jylx":1351,"wanglist":"行json||行json"})`
## （`fake_flash_server.handle_wang_list`，与原版 `AllInOneProcessor.handleWangList` 的 5 字段同语义，
## 只是 text 通道把 binary 的 `<iiiBi` 换成 json 行）。
const OP_WANG_LIST := 1351
## 秘笈合成（原版 `JiNengCompositeWindow.composeMiji` → `requestCanJuanHeCheng`，
## `AllInOneProcessor.as:171-178`：`writeByte(0)+writeDouble(主残卷 uniqueId)+writeInt(幸运符张数)`）。
## text 通道请求体 = `0:<unique_id>:<符数>`；回帧 = `1352:0:<0/1>`（`readBoolean` 的等价，
## 夹具 `handle_can_juan_action`，物品增减另走通用背包帧）。
const OP_CAN_JUAN_ACTION := 1352
## 意志（Spirit）族：请求/回帧同 opcode（原版 `SendOpCodes.as:264` / `ReceiveOpCodes.as:384`）。
const OP_SPIRIT_ACTION := 1823
## 百炼忍传（PVE_ACTION = 1572，服务端 `ClientOpcode/ServerOpcode.PVE_ACTION:887`）。
## 请求 `1572:0` = 问状态（`handle_pve_action:30844` action 0）；回帧 `1572:0:<进度>:<阅历>`。
## 与意志的关系：**阅历是意志学习的货币** ⇒ 意志页开页时主动问一次（服务端学习/卖灰后也会重发）。
const OP_PVE_ACTION := 1572
## 精英副本（HERO_ACTION，2026-10-04 合并「纲手三页」+ 用户批准接通）。
## 回帧 `1828:0:<maxEnter>:<tabId&copyId~cnt,copyId~cnt@…>`；请求 `1828:0`（开窗自拉）
## 或 `1828:1:<copyId>`（进本，服务端校验等级/重复/次数后扣数传送）。
## 原版 `HeroProcessor.as:64-82`；服务端 `handle_hero_action`（项目内那份，两分支齐全）。
const OP_HERO_ACTION := 1828
const OP_EQUIP_INLAY_INFO := 1043
const OP_WASH_PLUS_VALUE_RESPONSE := 1819
const OP_EQUIP_FORGE_STRENGTH_RESULT := 2064
const OP_EQUIP_FORGE_ADDITIVE_RESULT := 2065
const OP_EQUIP_KUNCHONG_STRENGTH_RESULT := 2066
const OP_BADGE_STONE_MERGE_RESPONSE := 2317
const OP_AUTO_CONSUME := 1292
const OP_DOUBLE_EXP := 1293
const OP_ATTRIBUTE_EFFECT := 1294
const OP_ITEM_MISC_RESPONSE := 1295
const OP_ITEM_MISC_REQUEST := 1568
const OP_STONE_MERGE_EFFECT := 2324
const OP_NPC_SHOP := 58
const OP_STORAGE := 59
const OP_PET_ACTION := 95
const OP_OPEN_SECRET_SHOP := 324
const OP_OPEN_NPC_SHOP := 326
const OP_CONFIRM_SHOP_TRANSACTION := 327
const OP_OPEN_STORAGE := 330
const OP_PET_ACTION_RESPONSE := 173
const OP_COPY_RESPONSE := 817
const OP_COPY_ACTION := 819
## 挂机配置（原版 `CharacterConfig.synch`）。**文本桥上载荷不带 opcode**：
## 查询 = `0`，保存 = 整个 JSON 对象 —— 服务端 `handle_char_config`
## （`fake_flash_server.py:17897`）先 `_strip_timestamp` 再判 `payload == "0"`，
## 不是 `0` 就直接 `json.loads(payload)`。多发一个 `1283:` 头会让查询和保存**都静默失败**
## （`json.loads("1283:0")` 抛错 ⇒ 整条 return，一条回帧都不发）。
const OP_CHAR_CONFIG := 1283
## 自动出售配置（`Client.as requestAutoSellConfig`，`:552`）。四个 int，第 1 个是位掩码
## `enabled?1|ingredients?2|fragments?4|books?8`（`GuaJiSettingWindow.as:551`）。
const OP_AUTO_SELL_CONFIG := 7779
const OP_HANG_ACTION := 1808
## 1283 回帧的**段序**就是服务端 `CHAR_CONFIG_FIELDS`（`fake_flash_server.py:2658`），
## 第 46 段是 keyData，后面 13 段是 `CHAR_CONFIG_EXTENDED_FIELDS`。顺序不能自己排，
## 名字里 `auot*` 是原版打错的拼写，服务端照抄 ⇒ 这里也必须照抄。
const 挂机配置字段 := [
	"isCollectMoney", "isCollectCaiLiao", "banghuiAutoAcceptMember", "autoUseChongWuEpDrug",
	"troopAutoAcceptInvite", "autoUseEpDrug", "autoDaZuo", "forbidFamilyInvite", "autoReplyHp",
	"isCollectDrug", "autoChongwuSkillId", "autoChongWuSkillType", "banghuiAutoAcceptInvite",
	"autoShouhu", "collectProfession", "auotReplyHpType", "collectLevelType", "forbidWhisper",
	"forbidAddFriend", "autoZaiSheng", "banghuiAutoEnterFlagWindow", "autoZhanYiEffect",
	"auotReplyMpType", "troopAutoAcceptApply", "forbidTradeInvite", "autoSkillType",
	"autoZhangXian", "autoAvoidBoss", "auotReplyHpValue", "autoUseZhenQiDrug", "closeCommitQuest",
	"autoBattleRange", "autoChongWuEat", "autoWulinEffect", "autoReply", "forbidTroopInvite",
	"autoBattleTime", "collectLevel", "isCollectQuestion", "auotReplyMpValue", "autoSkillId",
	"autoCollect", "autoReplyMp", "isCollectOthers", "collectQuality",
]
const 挂机扩展字段 := [
	"hideCharAnimation", "hideCharName", "hideOthersSkillEffect", "forbidEarthQuake",
	"forbidHeartBreak", "hideQuestTrackPane", "hideTroopInfoPane", "forbidMapBackgoundMusic",
	"forbidActionVoice", "bgmVolume", "sfxVolume", "isCloseLingQiTeXiao", "simplifiedChinese",
]
const OP_CASH_MONEY_REQUEST := 431
const OP_CASH_CATEGORY_REQUEST := 432
const OP_CASH_MONEY_RESPONSE := 1073
const OP_CASH_CATEGORY_RESPONSE := 1074
const OP_CASH_SEARCH := 1075
const OP_CASH_ITEM_INFO_RESPONSE := 1079
const OP_CASH_SHOPPING := 1081
const OP_CASH_CATEGORY_CAPACITY := 1084
## 仓库扩容 `CS_REQ_STORAGE_EXTEND`（`AllInOneProcessor.as:2906-2910`）。
## 服务端的**请求与回包用同一个数值**（`fake_flash_server.py:825` 的
## `ServerOpcode.CASH_STORAGE_CAPACITY = 1085`），回包是 `1085:容量`。
const OP_CASH_STORAGE_CAPACITY := 1085
const OP_CASH_ITEM_INFO_REQUEST := 1086
const OP_GUILD := 1552
## 地图族旗动作（`MAP_FLAG_ACTION = 1815`，`SendOpCodes.as:250`）。
## 服务端 `handle_map_flag_action`：只认 `action 0`（列出全部族旗，`1815:0:<行@行>`）。
const OP_MAP_FLAG_ACTION := 1815
## 玩家搜索（家族搜索窗「查询玩家」用）。服务端 `ClientOpcode.CHAR_SEARCH = 1282`。
const OP_CHAR_SEARCH := 1282
const OP_GUILD_BOSS := 2314
const OP_FRIEND_REQUEST := 127
const OP_FRIEND_RESPONSE := 61
const OP_PARTY_REQUEST := 120
const OP_PARTY_RESPONSE := 59
const OP_PARTY_MEMBER_STATE := 203
const OP_FUDAI_REQUEST := 1286
const OP_FUDAI_RESPONSE := 1289
const OP_GIFT := 1344
## 福利/礼包（`1344`）的 action。**逐条取自 `GiftProcessor.as` 的 `writeByte`**，
## 不是编的 —— 2026-09-27 之前客户端发的是 `90`/`91`，服务端 `handle_gift_query`
## 里根本没有这两个 action，于是**每一条查询与领取都石沉大海**（收包侧又按 90/91 解，
## 于是连回包形状也是错的）。这一组常量取代那套自造编号。
##
## ⚠️ 「每日签到」就是这张表里的 43/42（`requestQueryEverydayGift` / `requestGainEverydayGift`），
##    不是什么独立的签到协议；「线上有礼」是 31/32（月度在线时长）。分页 ↔ action 的对应见
##    `活动窗口.gd` 的 `_填签到` / `_填线上有礼`。
const GIFT_QUERY_FIRST := 2          # 查首次登录礼包 → 1344:1:<index>:<remaining>:<total>
const GIFT_GAIN_FIRST := 1           # 领首次登录礼包，参数是礼包下标
const GIFT_QUERY_WEEKLY := 12        # 查周登录礼包 → 1344:2:7:<day&state@…>:<days>
const GIFT_GAIN_WEEKLY := 11         # 领周登录礼包，参数是累计天数
const GIFT_QUERY_LEVEL := 21         # 等级礼包 → 1344:3:<last_level>
const GIFT_QUERY_MONTHLY := 31       # 查线上(月度)礼包 → 1344:4:<上周分钟>:<上周奖励>:<本周分钟>:<bool>
const GIFT_GAIN_MONTHLY := 32        # 领线上(月度)礼包
const GIFT_CODE := 41                # 兑换码，参数是码 → 1344:6:<…>
const GIFT_GAIN_EVERYDAY := 42       # 领每日签到 → 1344:7 然后 1344:5:<claimed>:<accumulated>
const GIFT_QUERY_EVERYDAY := 43      # 查每日签到 → 1344:5:<claimed>:<accumulated>
## 充值活动（`CZHUODONG`）。`HuodongActionProcessor.as:50-56 requestCzHuodong_common`
## 是「writeInt(cmd) + writeObjectAsBuffer(params)」，AMF3 文本通道下即
## `1814:<cmd>:<JSON>`；服务端 `_parse_czhuodong_request` 正好按这个形状切。
const OP_CZHUODONG := 1814
const CZ_BOOTSTRAP := 2              # 拉全量：配置 + 三种 status
const CZ_GAIN_LIMIT := 1             # 领限时大奖 {huodongId, type:"each"|"total", gainId}
const CZ_GAIN_XINFU := 3             # 领新服有礼 {type:"<UPPER>", gainId}
const CZ_GAIN_FIRST_KILL := 4        # 领首杀礼包 {}
## 走到/传送到 NPC 所在图 `MOVETO_NPCMAP`（`SendOpCodes.as:138` = 4027）。
## 包体五段：`<npc模板id>:<地图id>:<portal id>:<用红纸鹤 0/1>:<到了自动对话 0/1>`
## （`PacketCreator.getMoveToNpcMapPacket:488-497`；服务端 `handle_move_to_npc_map:17192`）。
const OP_MOVE_TO_NPC_MAP := 4027
const OP_ACHIEVEMENT := 1345
const OP_EXCHANGE := 1820
## 临时忍术层数 `SKILL_CHANGE_TMP`（勾玉/玉链的「忍术 +N 层」）。**只走原始二进制帧** ——
## 服务端 `_send_skill_gem_bonuses`（`fake_flash_server.py:49669`）只在 `wire_mode == "original"` 时发。
## 包形 `<i 条数>` + 每行 `<ii 忍术号, 加成层>`（小端；`BaseClient.as:155` 把收帧 buffer 设成 LITTLE_ENDIAN）。
## 上游 AS3：`AllInOneProcessor.as:576-607 handleTmpSkillChange` → `Client.as:2637`
## → `DataCenter.setAddedSkillLevelList:566-578`（**先清空再填**，不是增量）。
const OP_SKILL_CHANGE_TMP := 1813
## 二级密码（`SECOND_LEVEL_PASSWORD 2309`，收/发同号）。**这一族的线格式与全工程其余 opcode 不同**：
## 上行 = `readStr` 里塞一段**裸 JSON** `{"action":N,"values":[...]}`（不带动作号前缀），
## 下行 = **原始二进制帧**（和 `1820 兑换` 同一族回法，走 `_handle_original_frame`）。
## 真值：上行形状 `SecondLevelPasswordProcessor.as:18-53/115-145/168-200/280-285`
## （`writeByte(action)` + N 根 `writeUTF`）；下行形状同文件 `handleAction:310-358`。
## ⚠️ 大小端：**Flash `ByteArray.writeInt/readInt` 与 `writeUTF` 的长度前缀都是大端**，
##   而本工程服务端（`fake_flash_server.py:21940-21967`）烘的是**小端**（`<i` / `<H`）⇒
##   这里按服务端读、并在 `_decode_second_password` 顶部写清楚，别照 AS3 改成大端。
const OP_SECOND_PASSWORD := 2309
## 十个**上行**动作号（同文件里各 `writeByte`）：
## `0 queryFirstTime:195-200` · `1 addPasswordFirstTime:18-25` · `2 sendContactInfo:45-53`
## `3 sendQuestionsAndAnswers:27-36` · `4 sendConformQA:136-145` · `5 requestDeletePassword:280-285`
## `6 conformDeletePassword:115-124` · `7 modifyPassword:126-134` · `8 releaseLock:168-174`
## `9 requestModifyPassword:38-43`。
const SP_QUERY_FIRST := 0
const SP_ADD_FIRST := 1
const SP_CONTACT := 2
const SP_QUESTIONS := 3
const SP_QUESTION_CONFORM := 4
const SP_REQUEST_DELETE := 5
const SP_DELETE_CONFORM := 6
const SP_MODIFY_PASSWORD := 7
const SP_RELEASE_LOCK := 8
const SP_REQUEST_MODIFY := 9
const OP_ACTIVITY := 2326
## ⚠️ **两个"排行榜"opcode 不是一回事，别再混**（用户报修 5 的第一层根因就在这个号上）：
## · `1346` = **本服排行榜**（`SendOpCodes.PAI_HANG:210` / `ReceiveOpCodes.PEI_HANG:304`，
##   处理器 `PaiHangProcessor.as`）⇒ 左侧那 23 个榜单、姓名/宠物主人列、"你的当前排名"都在这一条上。
## · `2329` = **跨服充值榜**（`SendOpCodes.GLOBLE_PAIHANG:326` / `ReceiveOpCodes.GLOBLE_PAIHANG:488`，
##   处理器 `GloblePaihangProcessor.as`，回帧只有一种 cmd 0 = `size` + `userId/jifen/name` 的
##   `ChargeRankInfo` 列表）⇒ 与 23 个榜单无关。旧代码把排行榜挂在 `2329` 上 ⇒
##   服务端那条 `1346` 从来没被读过（`奖励在线查询回归测试` 那条金丝雀从 2026-09-25 起就没绿过）。
##   ⇒ 2329 **本工程不发也不接**（跨服充值窗未移植），所以这里不给它留常量、别再加回来。
const OP_PAI_HANG := 1346
## ⚠️ `2329`（跨服充值榜）**照 HEAD 上面那段说明不建常量**——分支那行 `OP_GLOBAL_RANKING := 2329` 合并时已剔除。
## 跨服战场面板那一条（上行/回包**同号** = 1825；`SendOpCodes.as:268` / `ReceiveOpCodes.as:390`）。
## ⚠ 上下行的子命令号是**两张表**，逐条见 `_handle_war_panel_text` 头上那段。
## 本机服务端的文本形态：`1825:0:<行>:<最大载入>`（行 = `频道号&名&当前载入`，多行用 `@` 连）。
const OP_WAR_PANEL := 1825
## 竞技场那一族（`SendOpCodes.as:234` / `ReceiveOpCodes.as:342` **同号 = 2306**）。
## ⚠ 上行 0..6 与下行 0..11 是**两张独立编号表**（`PkProcessor.as`），抄错一位整族错位 ⇒ 逐条见
## `真值/窗口/竞技场.md` §2B。本机服务端 `fake_flash_server.py:28910 handle_pk_action` 七条全在处理。
const OP_ARENA_PK := 2306
## 护送那一族（`SendOpCodes`/`ReceiveOpCodes` 的 MIXIN = 2325）。上行文本形态 =
## `2325:<子命令>:<JSON>` —— 服务端 `handle_mixin:34363-34379` 先剥 `2325:`、再把第 2 段当 JSON 解。
const OP_MIXIN := 2325
const OP_HEAL := 86
const OP_HEAL_RESPONSE := 1288
const OP_CARD := 1392
const OP_BUFF_FUSION := 1822
const OP_CHEST := 1826
const OP_GIVE_BUFF := 35
const OP_CANCEL_BUFF := 36
## 1811 系统增益（`SKILL_SYSTEM_BUF`）：`cmd=0` 上/刷新、`cmd=1` 收掉。
## 原版 `SystemBuffProcessor.as:79-100` → `Client.onSysBuff_showBuff/removeBuff`
## → `SkillHandler.addSysBuff:816-841`（图标取 `Buff/System/<type>`，skillId = 10000000+type）。
## 服务端 `fake_flash_server.py:_send_system_activity_buffs` 在发（0=双倍经验、1=双倍精华），
## 客户端以前**没有这条的消费者** ⇒ 原版那两个「活动」图标一个都出不来。
const OP_SYSTEM_BUF_ACTION := 1811
## 别人身上那一条 buff 的"给旁观者看"版本（原版 `ReceiveOpCodes.as:102/104`）。
## ⚠ 与 35/36 不是一条：35/36 只发给**自己**（挂 HUD 状态排），201/202 发给**同屏其他人**
##   （`AllInOneProcessor:1043/515` → `SkillHandler.applyOtherPlayerBuff/cancelOhterPlayerBuff`），
##   载荷第一段是**被施加者的角色号**，所以必须分开解。
const OP_GIVE_FOREIGN_BUFF := 201
const OP_CANCEL_FOREIGN_BUFF := 202
## 1313/1329/1330（原版 `ReceiveOpCodes.as:286/290/292`）：合击、玩家打玩家的伤害、别人看到的血条。
const OP_COUPLE_ATTACK := 1313
const OP_PLAYER_DAMAGE_PLAYER := 1329
const OP_PLAYER_HP := 1330
const OP_OPEN_PVP_ACTION := 1792
const OP_VIP := 1818
## 改名族（服务端 `ClientOpcode.CHANGE_NAMES` / `ServerOpcode.CHANGE_NAMES` 同号，
## `fake_flash_server.py:772,948`）。上行三条与下行四档都靠**第 2 段的 action/结果字节**分。
const OP_CHANGE_NAMES := 2330
const OP_CHANGE_WEATHER := 1570
## NPC 头上的任务标记（`513 UPDATE_NPC_QUEST_STATUS`）：`QuestProcessor.handleUpdateQuestStatusPacket`
## → `NPCHandler.setNpcStatus(npcId,status,0)` → `SmallMapHandler.setNpcStatus` → `SmallMapWindow.setNpcStatus:1605-1650`。
## 帧体 = `<object_id>:<status>`，status 就是原版枚举（`NpcQuestStatus.as:7-12`：
## NONE 0 / QUEST_CAN_START 1 / QUEST_CAN_COMPLETE 2 / QUEST_IN_PROGRESS 3）。
## ⚠️ 本条 2026-10-15 并分支时按「认亲法」整条取分支那套（用户拍板）：字面 `513:` 分派
## → `_handle_npc_quest_status_text`。原本这里的 `OP_NPC_QUEST_STATUS` 常量与内联分支是另一套
## （会话再存一份表），已废 —— 别再把它接回来。
## 忍具（八咫镜）兑换 —— `ClientOpcode.RENJU = 2082`，动作号见 `RenJuAction`：
## `KAI_GUANG 0` / `COMBINE 3` / `SWITCH_RESISTANCE 4`（服务端 `handle_renju`）。
## 「兑换忍具」那一跳 = 原版 `RenJuProcessor.requestRenJuHeCheng:29-34`：**只写一个字节 3**。
const OP_RENJU := 2082
const RENJU_COMBINE := 3
const RENJU_SWITCH_RESISTANCE := 4
## 十拳剑（灵器）兑换 —— `ClientOpcode.LING = 2081`，动作号 `LingQiAction`：
## `KAI_GUANG 0` / `LING_HUA 1` / `WASH 2` / `COMBINE 3` / `FACE_LIST 4` / `CHANGE_FACE 5` / `CHANGE_COLOR 6`。
## 「兑换十拳剑」= 原版 `LingEquipProcessor.requestLingEquipHeCheng:60-67`：
## **一个字节 3** + `writeInt(0)` + `writeInt(0)`。
const OP_LING := 2081
const LING_COMBINE := 3

# ⚠️ 原版客户端**发送**时用的 256 字节替换表（`DECODE_BOX`）与它的逆表构造
#    （`_build_encode_box` / `_encode_box`）已于 2026-09-25 一并删除 ——
#    它只被 `_send_packet`（原始二进制帧）用，而那条路不可达，见文件头「通信通道」一节。
#    真值仍在 `2.2.3/tools/fake_flash_server.py` 的 `ORIGINAL_CLIENT_DECODE_BOX`。

## 已经警告过的「客户端未登记的统计字段号」—— **只为去重**，不是业务数据。
## 见 `_handle_stats_text` 里那段说明。
var _已警告字段号 := {}

var status := "未连接"
var detail := "等待连接原版游戏服"
var character_id := 0
var channel_id := 1
var authenticated := false
var in_game := false
var authoritative_stats := {}
## ── 右下角「获得提示」的差值引擎（原版 `DataCenter.updateOneStatu` 的那半） ──
## 每帧属性的**上一帧值**：原版拿 `this.stats.X` 当被减数，本工程 `authoritative_stats` 里
## 存的是**协议键名**（`exp`/`gold`…）而差值要按**字段号**算，且字段号 28/33 还没进那张名字表，
## ⇒ 这里另存一份按字段号的旧值，别和会话那套建模耦在一起（少一个键就少一条提示，正是老毛病）。
var _提示旧值 := {}
## 原版 `DataCenter.firstInitTime`（`isInitUpdate` 的起点，`:144` 默认 true、`:2281-2288` 才翻）。
## 0 = 这局还没来过属性帧。
var _首帧属性毫秒 := 0
## true = **还在进游戏那 5 秒里** ⇒ 差值一律不提示（原版的 `isInitUpdate`）。
var _初更新 := true
## 原版 `:2285` 写死的 `getTimer() - firstInitTime > 5000`（毫秒）。
const 初始化窗口毫秒 := 5000
var authoritative_skills := {}
## 临时忍术层数（勾玉/玉链）——原版 `DataCenter.addedSkillLevelList`。
## 键 = **七位补零的技能号**（与 `learned_skills[i].id` 同一套）；每帧 1813 **整表替换**。
var authoritative_skill_added_levels := {}
signal skill_added_levels_received(levels: Dictionary)
var authoritative_inventory: Array[Dictionary] = []
var authoritative_equipment := {}
## `WARP_CHAR_INFO` 第 37/38/39/40 截：神器（ShenQi）/ 魂结（HunJie）/ 灵器（LingQi）/ 忍具（RenJu）。
## 这四类走的是**负槽**（-23 灵器、-24 忍具、-100/-101 神器剑镜…），而普通装备快照 2050 只带正槽
## ⇒ 不单独收的话，人物窗的灵器格永远是空的，`EquipPane.as:258-264` 那条「改变外观」
## 菜单也就永远弹不出来（2026-10-24 在线门实测：开光十拳剑在服务端 -23，客户端却查不到）。
var authoritative_special_equipment := {}
var authoritative_item_effects := {}
var authoritative_npc_shop := {}
## 神秘商店货架（`324:` 那一帧）。形状 = `真值/窗口/神秘商店.md` §③：
## `{remaining_seconds, discount_percent, items:[{id,quantity,cash_price,money_type,price,purchased,…展示字段}]}`。
## **不**并进 `authoritative_npc_shop` —— 那一份是 NPC 商店按 `npc_id` 开的账。
var authoritative_mystery_shop: Dictionary = {}
var authoritative_storage: Array[Dictionary] = []
var authoritative_storage_gold := 0
var authoritative_storage_capacity := 0
## 背包总格数 `DataCenter.commonSlots`（`ItemWindow2` 的 totalCell）。
## 服务端进图时走 CHAR_INFO 下发、扩充时走 1084 回包，这里存一份权威值。
var authoritative_bag_capacity := 0
var authoritative_pets: Array[Dictionary] = []
var authoritative_pet_capacity := 10
var authoritative_cash_shop: Array[Dictionary] = []
var authoritative_cash_shop_total := 0
var authoritative_cash_shop_capacity := 0
var authoritative_guild := {}
var authoritative_guild_list: Array[Dictionary] = []
## 家族列表的**累计拉取**中间态（原版 `FamillyManager.famillyList` / `_loadPage` 的对应物）。
##
## 服务端一页最多 100 条，而原版是"一页 100、累计到 `total` 为止、拉齐了才整份交给列表窗"
## （`FM.as:385-396` + `:1265-1268`）。这里两个变量就干这件事，判据与死循环防护见
## `_handle_guild_text` 的 action 3 分支。
var _族列表拉取中 := false
var _族列表累计: Array[Dictionary] = []
## 玩家搜索结果（`1282:<search_id>:<行…>`，行 = 线/角色id/等级/职业/名字/家族id/家族名/-）
var authoritative_char_search: Array[Dictionary] = []
## 上面那一批行是**哪一种搜索**回的（`1282` 第 2 段 searchType）。
## 原版就是靠这一格分流的：4 = 双修选人（`Client.as:5003`）、100 = 家族查玩家
## （`Client.as:5012` → `FamillyManager.searchPlayerResult`）。不存下来，两族会抢同一帧。
var authoritative_char_search_类型 := 0
var authoritative_guild_boss := {}
var authoritative_guild_shop: Array[Dictionary] = []
## 地图族旗列表（`1815` 的 action 0）。
##
## 行 = `MapFlagInfo.decode` 的 12 个字段（**顺序以那份 `.as` 为准**，逐条对得上服务端
## `fake_flash_server._encode_local_flag_info` 的写者）：
##   map_id / x / y / channel / bang_id / bangName / flag_hp / flag_maxhp /
##   flag_level / flag_style / flag_color / flag_name
## ⚠️ 一个 **map_id 只有一行**（服务端按 `MAP_FLAG_LOCATIONS` 每个图发一条）——
##    旗帜窗的「势力对比」就是按这张表里**各家族的族旗数**排的（`FF.as:97-175`），
##    所以它既不是按家族发的，也不是按玩家位置发的。
var authoritative_flag_list: Array[Dictionary] = []
## **当前地图上**的族旗（服务端进图时会推 `1815:1`）。空 = 这张图没旗。
var authoritative_map_flag := {}
var authoritative_friends: Array[Dictionary] = []
var authoritative_enemies: Array[Dictionary] = []
var authoritative_blocked: Array[Dictionary] = []
var authoritative_recent_contacts: Array[Dictionary] = []
var authoritative_friend_requests: Array[Dictionary] = []
var authoritative_party := {}
var authoritative_nearby_parties: Array[Dictionary] = []
## 福利/礼包（`1344`）的权威状态，**按来源分组**（形状即 `1344:1..7` 各条回包）：
##   first    {index, remaining, total}      首次登录礼包（:1）
##   weekly   {days, states:[{day,state}]}   周登录礼包（:2，state 1=可领 2=已领 0=不可领）
##   monthly  {last_week_minutes, last_week_reward, week_minutes, gainable}  线上有礼（:4）
##   everyday {claimed, accumulated}         每日签到（:5）
##   level    int                            等级礼包（:3）
##   code     String                         兑换码结果（:6）
##   claim    Dictionary                     最近一次领取结果（:7 / :62）
## 任务的两个列表（`444` action 3/4）。**只有运行期信息**（id/状态/进度），
## 文案与几何都归 `数据/任务.json` —— 合并由任务窗口做（见 `_handle_quest_update_text`）。
var authoritative_quests_started: Array[Dictionary] = []
var authoritative_quests_available: Array[Dictionary] = []
var authoritative_gifts := {}
## 充值活动（`1814`）的权威状态：config（cmd 2）/ limit（cmd 1）/ xinfu（cmd 3）/ first_kill（cmd 4）。
## 六子页里的首杀礼包、限时大奖、新服有礼、活动奖励读的就是这里。
## ⚠️ cmd 4 的键**原名 first_charge**（原版 `requestCzHuodong_gainFC` 领的是首充礼包），
##    2026-10-31 用户口径再改：这一页是首杀礼包（击杀一只 BOSS 可领），键名随之改成 first_kill。
var authoritative_czhuodong := {}
var authoritative_exchange: Array[Dictionary] = []
## 二级密码（2309）的会话态。这四个数**全部来自服务端帧**，客户端一律不猜：
##   `类型` = 下行 2 那根 int（原版 `TwoPasswordManager.isSetPasswordType`：
##            0=setPasswordType_1「没设过」/ 1=setPasswordType_2「已设」/ 2=setPasswordType_3）；
##   `修改次数` = 下行 10、6 带回来的 `updateCount`；`删除次数` = 下行 5、9 的 `deleteCount`；
##   `已解锁` = 下行 8 的 `result == 1`（原版 `isunchainLook`，`Client.as:6810-6816`）。
## ⚠ 原版的 `problem1/problem2/result1/result2/mail_Text/...` 是**客户端草稿**，
##   不进这里（那份在 `二级密码窗.gd` 的脚本级静态里，跟窗实例无关，跨六扇窗共享）。
var authoritative_second_password := {"类型": 0, "修改次数": 0, "删除次数": 0, "已解锁": false}
var authoritative_fudai := {}
var authoritative_treasure := {}
## 排行榜（`1346`）：`menuId(int) → {"rows": [...], "rank": int, "江湖": bool}`。
## 行形状照原版解码器 `PaiHangInfo.decode:28-35` 的五段序（服务端文本化后同名同序）：
## `server_id(int) & char_id(int) & name(UTF) & pet_uid(float) & value(String 原样)`。
## ⚠ `value` **留字符串不留数**：原版 `rankNumText.text = param1.value`（`RankListCell2.as:43`）
##   是把 Number 直接当文本印，服务端那一段本来就是十进制串 ⇒ 取原样串最贴近，
##   也免了 int/float 往返把 `12.5` 变成 `12`（§3.253-D 那条漂移口径）。
var authoritative_rankings := {}
## 头顶榜单徽记（cmd 0）：`char_id → Array[int]`（元素是 `menuId`，原版
## `PaiHangTipPane.redraw:22-46` 拿它去 `PicTool.getPaiHangIcon` 取 `Effect_PaiHangBang_<n>`
## 那枚 MC、按 `-(len-1-i)*28` 竖排）。素材已直解进 `素材/特效/Effect_PaiHangBang/`
## （25 枚，从 `2.2.3/www/…/swf/Effect/Effect_PaiHangBang.swf` 用 JPEXS 出的），
## 画在 `地图实体._刷榜单徽记`。
var authoritative_ranking_titles := {}
var authoritative_achievements: Array[Dictionary] = []
var authoritative_activity := {}
var authoritative_card := {}
var authoritative_chest := {}
var authoritative_buff_fusion := {}
var authoritative_heal := {"state": 0, "character_id": 0, "partner_id": 0, "xinfa_id": 0, "pending_inviter_id": 0}
## 结成羁绊（结婚）后的权威对端：`61:19/20` 与登录补发的 `61:13` 都写这里。
## 字段名照原版 `onFriend_acceptTa:4878-4891` 那个对象（`charId/name/face/job/hunjieId`）。
var authoritative_spouse := {"charId": 0, "name": "", "face": 0, "job": 0, "hunjieId": 0}
## 最近一条 `2330` 的三个字段（镜像：改名窗重开时要能立刻回填）。
## `改名名单` 是 `PackedStringArray`，空表 = 服务端写了 `-`。
var 改名结果码 := -1
var 改名消息 := ""
var 改名名单 := PackedStringArray()
## 赠花档（`58:2` 那一条解出来的，键名照原版 `FlowerCharInfo.as:5-24` 的字段名，不另造一套）：
## `logs` 每条 = `FlowerSenderInfo`（senderName/senderId/count/sendTime/face/job/level/flowerid），
## `flowerInfo` 每条 = `FlowerInfo`（count/exp/cost/youhaodu/type/flowerid）。
## 两个列表服务端给的是什么序就什么序，**排序在收端**（原版 `:77/:91`：记录按 sendTime、档位按 youhaodu 升序）。
var authoritative_flower := {"cid": 0, "face": 0, "youhaodu": 0, "totalFlowers": 0,
		"weeklyFlowers": 0, "count": 0, "flowerDayLogInfo": [], "flowerInfo": []}
## **别人那具身体**的双修伙伴号（原版 `Character.healPartnerId` 挂在每个 Character 上）。
## 来源是 `1288:1` 里"讲的是别人"的那一帧 —— 服务端同意/停坐那一支给同一条连接连发两帧
## （`fake_flash_server.py:34884/34889`、`:35060-35085`），原版正是靠这一对把**两具身体**的伙伴号都种齐
## （`HealHandler.as:250` 的 if 支写我这具、`:315-331` 的 else 支写那一具）。
## 少了这一族 ⇒ `CharacterHandler.tickHealDouble:728` 那句 `_loc3_.healPartnerId != 0` 永远假
## ⇒ 一屏里只有一个人浮（原版是两个人一起浮）。消费者：`地图实体._双修对坐`。
var 远程双修伙伴 := {}
## 随身摊位（`1296:1:` 那一帧的原文解出来的形状）。消费者：`窗口管理._on_stall_state` → `功能窗口._render_stall`。
var authoritative_stall: Dictionary = {}
## 荣誉（木叶大战）那半边的状态。`fame_point` = 唯一由 `2323:8:` 写入的字段
## （`MuYeDaZhanManager.famePoint` 的等价物）。**登录时是 0** —— 原版同样从 0 起，
## 因为发 `2323:8:` 的三个地方全在"点兑换"之后（服务端 `:30031,30036,30046`）。
var authoritative_muye_battle: Dictionary = {"fame_point": 0}
## 交易窗的状态面（由 `335` 那一族帧累积）。形状见 `真值/窗口/交易与邀请托盘.md` §⑩。
## `my_items` / `other_items` 是 `{交易槽 1..5: 物品字典}` —— **键是交易槽**，
## 因为服务端 `_broadcast_trade_snapshot:23774-23776` 把负载里的 `slot` 换成了交易槽。
var authoritative_trade: Dictionary = {
	"active": false, "other_id": 0, "other_name": "",
	"my_money": 0, "other_money": 0, "my_cash": 0, "other_cash": 0,
	"my_items": {}, "other_items": {},
	"my_pet": {}, "other_pet": {},
	"my_locked": false, "other_locked": false,
}
var authoritative_jieyin := {}
## 师徒关系（`77:14` 解出来的两份）：`authoritative_tutor` = 我的师父（空 = 没有），
## `authoritative_students` = 我的徒弟列表。行形状 = 服务端 `_tutor_relation_row` 那 11 段
## （`号&名&等级&职业&脸&线&性别&关系&1&0&创建毫秒`，关系 −2 = 师父、−1 = 徒弟）。
var authoritative_tutor: Dictionary = {}
var authoritative_students: Array = []
var authoritative_anqi := {}
var _storage_chunks := {}
var _storage_expected_count := 0
var authoritative_cultivation := {
	"手里剑": {"stage": 0, "level": 0, "master": 0, "open": false, "blessing": 0},
	"结印": {"stage": 0, "count": 0},
	"八门": {"list_id": 0, "point_id": 0, "point_count": 0},
	"柔拳": {"stage": 0, "count": 0, "blessing": 0},
	"写轮眼": {"stage": 0, "count": 0, "blessing": 0},
	"轮回六道": {"stage": 0, "count": 0, "blessing": 0},
}
var last_npc_dialog := {}
## 最近一次「查看信息」回帧解出来的档案（键表见 `_handle_character_info_text`）。
## 只存**最后一条**：原版 `DetailsWindow` 也是一次只看一个人，重开就覆盖。
var 他人详细信息: Dictionary = {}
var 他人详细信息号 := -1
## 收到的那条原文（`:` 拼回）。分支那两条离线门拿它证明"喂的确实是真机那一帧"。
var 他人详细信息原文 := ""
var _inventory_chunks := {}
var characters: Array[Dictionary] = []
var map_players := {}
var map_monsters := {}
var map_npcs := {}
## `513` 推来的 NPC 任务态：`object_id → status`（原版枚举 `NpcQuestStatus.as:7-12`：
## NONE 0 / QUEST_CAN_START 1 / QUEST_CAN_COMPLETE 2 / QUEST_IN_PROGRESS 3）。
## 进图/重连后**补发**用 —— 换图要清（`reset_world_state`）。
var npc_quest_status := {}
var map_drops := {}
var authoritative_map_id := 0
var authoritative_position := Vector2.ZERO
var authoritative_vip_level := 0
var authoritative_pk_mode := 1
var authoritative_weather_type := -1
var authoritative_buffs := {}

var _entity_spawn_sequence := 0
var _player_spawn_order := {}
var _monster_spawn_order := {}
var _pending_skill_hits := {}

var _tcp := StreamPeerTCP.new()
var _receive_buffer := PackedByteArray()
## 发送序号，`_send_bridge_request` 的 `sid` 字段用它（与已删的原始二进制帧无关）。
var _send_sid := 1
var _connect_elapsed := 0.0
var _connection_started := false
var _login_sent := false
var _character_selected := false
var _enter_sent := false
var _pending_account := ""
var _pending_password := ""
var _auto_select_character := false

func _process(delta: float) -> void:
	_tcp.poll()
	var next_status := _tcp.get_status()
	if next_status == StreamPeerTCP.STATUS_CONNECTING:
		_connect_elapsed += delta
		if _connect_elapsed >= CONNECT_TIMEOUT:
			_fail_connection("连接超时")
		return
	if next_status == StreamPeerTCP.STATUS_CONNECTED:
		if not _connection_started:
			_connection_started = true
			_set_status("验证中", "已连接原版游戏服 AMF3 通道，正在校验版本")
			_send_bridge_request(1, str(CLIENT_VERSION))
		_read_available_packets()
		return
	if _connection_started:
		_fail_connection("服务器已断开连接")

func sync_character() -> void:
	var settings := _get_settings()
	connect_backend(
		String(settings.get("backend_account", "a33047518511@gmail.com")),
		String(settings.get("backend_password", "123456")),
		true
	)

func connect_backend(account: String, password: String, auto_select := false) -> void:
	disconnect_backend()
	var settings := _get_settings()
	_pending_account = account.strip_edges()
	_pending_password = password
	_auto_select_character = auto_select
	var host := String(settings.get("backend_host", DEFAULT_HOST)).strip_edges()
	var port := int(settings.get("backend_port", DEFAULT_PORT))
	if host.is_empty():
		host = DEFAULT_HOST
	_set_status("连接中", "%s:%d" % [host, port])
	var error := _tcp.connect_to_host(host, port)
	if error != OK:
		_fail_connection("无法连接原版游戏服（错误 %d）" % error)

func disconnect_backend() -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_NONE:
		_tcp.disconnect_from_host()
	_tcp = StreamPeerTCP.new()
	_receive_buffer.clear()
	_send_sid = 1
	_connect_elapsed = 0.0
	_connection_started = false
	_login_sent = false
	_character_selected = false
	_enter_sent = false
	authenticated = false
	in_game = false
	character_id = 0
	authoritative_stats.clear()
	item_cooldown_until.clear()
	## 获得提示的基准值与"进游戏 5 秒"起点是**这一局**的状态 ⇒ 断线一起复位，
	## 否则重连后第一帧会拿上一局的旧值算差（表现为"上线就提示金币 -3000"）。
	_提示旧值.clear()
	_首帧属性毫秒 = 0
	_初更新 = true
	authoritative_skills.clear()
	## 勾玉/玉链的临时层数同理：不清的话重连后在玉链还没穿上的那段时间里，
	## 忍术页仍会印着上一局的「+N」。服务端每次刷新都会重发 1813。
	authoritative_skill_added_levels.clear()
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null:
		# 断开要连"技能已被服务端接管"这个标记一起复位，否则重连后新的权威技能
		# 会被当成追加、离线示例数据里那两个编的技能又活过来。
		会话.server_skills_loaded = false
		会话.skill_added_levels.clear()
	authoritative_inventory.clear()
	authoritative_equipment.clear()
	authoritative_special_equipment.clear()
	authoritative_pets.clear()
	authoritative_cash_shop.clear()
	authoritative_cash_shop_total = 0
	authoritative_cash_shop_capacity = 0
	authoritative_guild.clear()
	# 断线/换号时把自己的家族名一起抹掉，免得下一局人物面板还挂着上一族的名。
	_同步家族到人物属性()
	authoritative_guild_list.clear()
	authoritative_guild_boss.clear()
	authoritative_flag_list.clear()
	authoritative_friends.clear()
	authoritative_enemies.clear()
	authoritative_blocked.clear()
	authoritative_recent_contacts.clear()
	authoritative_friend_requests.clear()
	authoritative_party.clear()
	authoritative_nearby_parties.clear()
	authoritative_quests_started.clear()
	authoritative_quests_available.clear()
	authoritative_gifts.clear()
	authoritative_czhuodong.clear()
	authoritative_exchange.clear()
	## 二级密码那四个数也是服务端推的 ⇒ 断线一起复位，别把上一局的「已解锁」带给下一局
	## （原版 `isunchainLook` 活在 `TwoPasswordManager` 的静态字段里，客户端重启才清，
	## 但本工程断线即复位 —— 因为服务端每条 8 都会重推，复位不会比原版少信息）。
	authoritative_second_password = {"类型": 0, "修改次数": 0, "删除次数": 0, "已解锁": false}
	authoritative_fudai.clear()
	authoritative_treasure.clear()
	authoritative_rankings.clear()
	authoritative_ranking_titles.clear()
	authoritative_achievements.clear()
	authoritative_activity.clear()
	_inventory_chunks.clear()
	last_npc_dialog.clear()
	characters.clear()
	map_players.clear()
	map_monsters.clear()
	map_npcs.clear()
	npc_quest_status.clear()		# 标记按 object_id 存，换图必清（新图会重发一轮 513）
	map_drops.clear()
	_pending_skill_hits.clear()
	authoritative_map_id = 0
	authoritative_position = Vector2.ZERO
	authoritative_vip_level = 0
	authoritative_pk_mode = 1
	authoritative_weather_type = -1
	authoritative_buffs.clear()
	authoritative_item_effects.clear()
	authoritative_heal = {"state": 0, "character_id": 0, "partner_id": 0, "xinfa_id": 0, "pending_inviter_id": 0}
	if 会话 != null and 会话.has_method("清空限时效果"):
		会话.call("清空限时效果")
	if 会话 != null and 会话.has_method("清空服务端增益"):
		会话.call("清空服务端增益")
	_entity_spawn_sequence = 0
	_player_spawn_order.clear()
	_monster_spawn_order.clear()
	_pending_account = ""
	_pending_password = ""
	_auto_select_character = false

func select_character(selected_character_id: int) -> bool:
	if not authenticated or selected_character_id <= 0:
		return false
	for character in characters:
		if int(character.get("id", 0)) == selected_character_id:
			character_received.emit(character)
			var session := get_node_or_null("/root/GameSession")
			if session != null:
				session.apply_backend_character(character)
			break
	_character_selected = true
	character_id = selected_character_id
	return _send_bridge_request(10, str(selected_character_id))

## 建角（`CREATE_CHAR = 17`，`SendOpCodes.as:18`）。
##
## 包体**逐字照原版** `CreateCharWindow3.enterGame()`（`as3_MainCreateChar`，`:355-376`）：
##   `{name, job, face:0, hair:0, gender, shoes:0, weapon:0, clothes:0, pants:0}`
## ⇒ **face/hair 一律 0**，外观由服务端定。本工程以前默认送 `face=10000003, hair=10000006`
##    是自己编的（原版那两格根本没进这个包）。
## 服务端：`fake_flash_server.py:_handle_create_character`（`:14373`）吃 JSON
##   `{name,job,gender,face,hair}`，回 `jylx:17` 带 `charInfo` + `maxChars`。
func create_character(character_name: String, job := 100, gender := 1) -> bool:
	if not authenticated:
		return false
	return _send_bridge_request(17, JSON.stringify({
		"name": character_name.strip_edges(), "job": job,
		"face": 0, "hair": 0, "gender": gender,
		"shoes": 0, "weapon": 0, "clothes": 0, "pants": 0,
	}))


## 随机名（`GENERATE_CHAR_NAME = 1028`，`SendOpCodes.as:144`）。
## 原版 `LoginProcessor.requestGenerateCharName(gender)`（`:163-168`）只 `writeShort(gender)`；
## 回帧 `GENERATED_CHAR_NAME = 1028` → 服务端 `_handle_generate_character_name`（`:14439`）
## 回 `{jylx:1028, charName:"…"}`。
## ⚠ 原版 `Client.onGeneratedCharName`（`Client.as:1392-1395`）**是空的**，
##    真正落名的是 `CreateCharWindow3.setName()` —— 所以本客户端拿到名字要**自己写进输入框**。
func request_generate_char_name(gender := 1) -> bool:
	if not authenticated:
		return false
	return _send_bridge_request(1028, "1028:%d" % gender)

func send_game_packet(opcode: int, payload := PackedByteArray()) -> bool:
	if not in_game or _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	return _send_bridge_request(opcode, payload.hex_encode())

func send_game_request(opcode: int, content: String) -> bool:
	if not in_game or _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	return _send_bridge_request(opcode, content)

## 发自己的一步走。**段序由服务端的读法决定**（`fake_flash_server.py:34625 handle_move`）：
## `36:<x>:<y>:<movement_action>:<速度x>:<速度y>:<movement_flag>[:<朝向>]` —— 第 4 段是动作号
## （`PLAYER_MOVEMENT_ACTION_*`：站立1/跳2/走3/爬梯4/爬绳5/打坐7/双修坐8），第 5/6 段被原样转进
## 广播包的第 8/9 段（同伴拿去推朝向与攀爬冻结），第 7 段是移动状态
## （`PLAYER_MOVEMENT_FLAG_CLIMBING=1 / GROUNDED=2`，`:109-110`）。
## ★ 第 8 段（**可选**）是本机此刻的朝向 ±1。原版 `Character` 的采样帧里本来就带
## `character.direction`（`CommandController` 收端直接照它转身），我们以前没这一格 ⇒
## 收端只能"按速度符号推"，于是**站着不动的人永远停在上一次移动的那个朝向**：
## 双修时他该朝左、却还朝右（10-17 用户实机那一屏）。服务端 `handle_move:34769`
## 已经把 `fields[6]` 原样转进广播包第 12 段 ⇒ **加这一格不用改服务端**，老客户端不发就是 0 = "没给"。
## ⚠ 以前第二参发的是朝向（±1）⇒ 落在动作槽里，对面永远读到"站立"（-1 还会被服务端夹成
## 站立），表现就是**看别人走路只有平移、不播走路帧**（用户 2026-10-14 报的第一条）。
func send_movement(位置: Vector2, 动作: int = 3, 速度: Vector2 = Vector2.ZERO, 朝向: int = 0) -> bool:
	var 状态 := 1 if (动作 == 4 or 动作 == 5) else 2
	return send_game_request(36, "36:%d:%d:%d:%d:%d:%d:%d" % [
			roundi(位置.x), roundi(位置.y), 动作, roundi(速度.x), roundi(速度.y), 状态, 朝向])

## 按**当前地图上的传送门编号**请求换图。服务端只认这个形态：
## `CHANGE_MAP(33)` 的 `reason=2(PORTAL), targetObject(-1), <portalId>`，
## 它在 current_map.portals 里查该 id 再取 target_map_id——没有"直接给目标地图"的形式。
func request_portal_enter(portal_index: int) -> bool:
	if portal_index < 0:
		return false
	return send_game_request(33, "2:-1:%d" % portal_index)

## 回 Boss 房门那一步（`1349`）。服务端 `handle_portal_panel_confirmation:15114` 读法：
## `fields[0] = request_id`、`fields[1] = 1/0`；request_id 对不上就整帧丢掉，
## 摘「取消」只是清掉挂起、不开图（`:15071-15077`）。
func request_portal_panel(request_id: int, accepted: bool) -> bool:
	if request_id < 0:
		return false
	return send_game_request(OP_PORTAL_PANEL, "%d:%d" % [request_id, 1 if accepted else 0])

func request_map_change(map_id: int, x: int, y: int) -> bool:
	# 只给目标地图时（测试与脚本用），先在本图按目标图反查门，再按门的编号请求。
	# 走传送门时应直接用 request_portal_enter，避免同目标多门时选错。
	var portal := _find_portal_to_map(map_id)
	if portal.is_empty():
		return false
	return request_portal_enter(int(portal.get("index", -1)))

## 在当前地图的 portal 表里找通往 target_map_id 的门。
## 数据来自 数据/地图/{id}/地图.json 的 "portal" 字典：键即 portal id，tm 为目标地图。
func _find_portal_to_map(target_map_id: int) -> Dictionary:
	var data := MAP_RESOURCES.map_data(str(authoritative_map_id))
	var raw = data.get("portal", {})
	if not raw is Dictionary:
		return {}
	for key in raw:
		var entry = raw[key]
		if not entry is Dictionary:
			continue
		if int((entry as Dictionary).get("tm", 0)) == target_map_id:
			var portal: Dictionary = (entry as Dictionary).duplicate(true)
			portal["index"] = int(key)
			return portal
	return {}

func request_pk_mode(mode: int) -> bool:
	if mode < 1 or mode > 4:
		return false
	return send_game_request(OP_OPEN_PVP_ACTION, "0:%d" % mode)

func request_npc_dialog(npc_object_id: int) -> bool:
	## `send_game_request` 自己会拼上 opcode（线上是 `54:<id>`），这里**只发裸 id**。
	## ⚠ 以前多发了一层 `"54:%d"` ⇒ 线上 `54:54:<id>`；服务端 `_resolve_talk_npc`
	## 只剥掉第一个 54，剩下的 54 被当成 **NPC 模板号 54** ⇒ 永远跟 54 号 NPC 说话。
	## 传 object_id 时侥幸没事（它先在所有字段里找 object_id），但传**模板号**时必错：
	## 2026-10-26 用户交付 1270（回复 NPC 57 砂隐暗部-风）就是被解析成 54（三代火影），
	## 对话里只有「离开」、没有 1270 可交行。实测：裸 `54:57` → 回帧 npc_id=57、
	## selection 含 1270 状态 2；带前缀的 `54:54:57` → 回帧 npc_id=54。
	return send_game_request(54, npc_talk_payload(npc_object_id))


## 54 的**唯一**载荷形态：裸 id（线上由 `send_game_request` 拼成 `54:<id>`）。
## 单独提出来给门钉 —— 多一层 `"54:"` 会让模板号被服务端解析成 NPC 54（见上）。
static func npc_talk_payload(npc_object_id: int) -> String:
	return str(npc_object_id)

func request_npc_more_talk_ex(command_type: int, value: int) -> bool:
	return send_game_request(57, "%d:%d" % [command_type, value])

func request_npc_menu_action(action: int) -> bool:
	return request_npc_more_talk_ex(2, action)

## 点对话窗「我说」那块皮 = 原版 `QuestDialog.clickPlayerSaidHandler():137-145`
## ⇒ `requestNPCMoreTalkEx(NPCTalkCmdType.NEXT=1, 1)`。服务端 `_continue_original_quest_dialog`
## 把作者台词往后翻一条，**翻到最后一条才落状态变更**（接取 / 对话目标计数 / 交付发奖），
## 所以这一条不发出去，任务就永远停在"进行中"（本工程 2026-10-09 前整条 NPC 任务链断在这里）。
func request_npc_next() -> bool:
	return request_npc_more_talk_ex(1, 1)

## 点舞台空白 / ESC = 原版 `__clickStageHandler():365-369`
## ⇒ `requestNPCMoreTalkEx(CLOSE=-1, -1)`，服务端 `_clear_active_quest_dialog()`
## —— 半途走开**不**结算任务（与"翻到最后一句"是两条不同的路，别混）。
func request_npc_leave() -> bool:
	return request_npc_more_talk_ex(-1, -1)

## 点对话窗里**任务那一行**（selection 富文本链接）= 原版 `selectionLinKHandler():106-118`
## ⇒ `requestNPCMoreTalkEx(SELECTION=3, <任务id>)`。**href 的值就是任务 id**，不是行号。
## 服务端 `handle_npc_talk_more_ex` 收到才走 `_handle_original_quest_npc(selected_quest_id=…)`
## —— 接取 / 对话目标 / 交付全从这一跳开始（本工程此前一条都没发过 ⇒ 任务点不动）。
func request_npc_selection(quest_id: int) -> bool:
	return request_npc_more_talk_ex(3, quest_id)

## 点 NPC 对话（`NPC_TALK 54`，原版第一跳；系统全景里挂"未接"多年）。
## 服务端 `handle_npc_talk → _resolve_talk_npc`：**object_id 或 template_id 都认**
## （跨图取 template 兜底），随后置 active_npc 并回 328 对话帧（纲手那格带 menu 段）。
const OP_NPC_TALK := 54


func request_npc_talk(编号: int) -> bool:
	return send_game_request(OP_NPC_TALK, str(编号))


## `use_all` 写在报文第 4 段 —— 服务端 `handle_use_item` 读 `fields[3]=="true"`
## 且物品定义 `use_all` 才整摞吃（`PacketCreator.as:396-404` 的 `param4`、
## `fake_flash_server.py:50346-50357`）。**参数曾叫 `automatic`，是起错的名字**：
## 它从来不是"自动"，就是原版那个 useAll；2026-10-01 改名，全工程无人传过 true。
##
## 第 3 段（`fields[2]`）是原版的 **AMF3 selection 对象** —— `UI.useItem` 把它透传给
## `requestUseItem`，服务端 `_use_item_request_fields:49791-49813` 把以 `{` 开头的尾巴
## **整段**还原成一个字段、`json.loads` 之后交给 `_use_authored_gift_item`
## （`:50399-50406`）。自选礼包不带它就回「请先在自选礼包中选择一件奖励。」并**一件不扣**。
## 不选东西时这里必须写字面 `"-"`：服务端把 `""`/`"-"`/`"null"` 三种都当"没带"（`:50400`），
## 而原版空选发的就是 `-`。
func request_use_item(slot: int, item_id: int = 0, use_all := false,
		extra: Array = [], 选择: Dictionary = {}) -> bool:
	var 选文 := "-"
	if not 选择.is_empty():
		选文 = JSON.stringify(选择)
	var values := [str(slot), str(item_id), 选文, str(use_all).to_lower()]
	for index in 3:
		values.append(String(extra[index]) if index < extra.size() else "")
	return send_game_request(69, ":".join(values))

func request_pickup(map_object_id: int) -> bool:
	return send_game_request(198, str(map_object_id))

func request_basic_attack(target_object_id: int, world_position: Vector2, direction: int, stance := 11) -> bool:
	# 服务端的命中包是**冒号文本**（其 _decode_original_attack_request 的字段序，
	# 见 fake_flash_server.py 的 _attack_skill_id / _apply_pet_mob_attack 对 fields 的取用）：
	#   [0]isPlayer [1]characterId [2]petUid [3]level [4]damageCount [5]targetCount
	#   [6](targetCount<<4)|damageCount [7]skillTrigger [8]skillLevel [9]skillId
	#   [10]stance [11]direction [12]targets
	# targets 必须落在 index 12，且**不要**带 "id&alive&dmg" 认领——不带认领时服务端
	# 自算伤害并把结算（243/252/239）广播回来；带认领会被按客户端伤害校验而抑制回放。
	if target_object_id <= 0:
		return false
	var target_count := 1
	var damage_count := 1
	var fields := PackedStringArray([
		"1", str(character_id), "0", "1", str(damage_count), str(target_count),
		str((target_count << 4) | damage_count), "false", "0", "0",
		str(stance), str(direction), str(target_object_id),
	])
	return send_game_request(40, "40:%s" % ":".join(fields))

## 技能的两张帧（1328 广播 / 42 结算）都用这个把 objectId 列表折成 `@` 连接的目标串。
## ⚠️ 2026-09-27 之前 42 发的是 **JSON**（`send_game_request(42, JSON.stringify(...))`），
## 而服务端 `_request_fields()` 是按**冒号**切字段的 —— JSON 里的冒号被切成一堆碎片，
## `_attack_skill_id()` 从 `fields[9]` 取不到技能 id（拿到 0）→ `_resolve_attack_skill()`
## 判成"没学过这个技能"→ **整条包被丢掉，技能在线打不到任何怪**（用户实机报的"不能打怪"）。
## 普攻那条（opcode 40）从一开始就是冒号文本，所以一直好使。两张帧现在都照服务端的解析器来。
func _技能目标串(target_object_ids: Array) -> Array[String]:
	var 目标: Array[String] = []
	for target_id in target_object_ids:
		if int(target_id) > 0:
			目标.append(str(int(target_id)))
	return 目标

## ⚠ **两张帧分开、而且分开在两个不同的时刻发**（2026-10-14 用户实机"从别人窗口看技能特效
## 延迟也很高"抓出来的）：上一轮 #193 为了"弹到身上才算伤害"，把**两张帧捆在一起压到命中帧**，
## 于是旁观者要等飞行物落地才看到出手动画与起手特效（投掷技 = 几百毫秒后；近战 = 立刻）。
## 原版的分工是：
##   · **1328 广播 = 出手那一拍当场发**（`AbstractAttackSkill.hitTest():629` 一出手就
##     `requestPlayerAttackInfo(...)`，**有没有目标都发**）；
##   · **42 结算 = 命中那一拍才发**（PVE 伤害本来就是客户端在命中帧算的）。
## 所以：动画/特效的可见性归 `announce_skill_cast`（按下去那一刻），伤害的时序归
## `request_skill_damage`（弹落地那一刻）—— #193 那条口径一个字都不动。
func announce_skill_cast(skill_id: int, skill_level: int, target_object_ids: Array,
		world_position: Vector2, direction: int, stance := 11) -> bool:
	var 目标 := _技能目标串(target_object_ids)
	var 目标串 := "@".join(目标) if not 目标.is_empty() else "-"
	var expires_at := Time.get_ticks_msec() + 5000
	for target_id in 目标:
		_pending_skill_hits[int(target_id)] = {"skill_id": skill_id, "expires_at": expires_at}
	# 字段序与 `_player_attack_packet_body()`（服务端自己的写包器，PlayerAttackInfo 原版布局）一致：
	#   characterId / attack / defence / critical / evasion / stance / direction / speed
	#   / **skillId** / skillLevel / x / y / players(@) / **monsters(@)** / tag…
	# ⚠️ 服务端 `_request_fields()` 会**先剥掉开头的 opcode** 再编号，所以上面这套序号
	#    是"去掉 1328 之后"的；写断言时别把 opcode 算进去（差一格就全错）。
	return send_game_request(1328, "1328:%d:0:0:0:0:%d:%d:0:%d:%d:%d:%d:-:%s:0:-:-" % [
		character_id, stance, direction, skill_id, maxi(1, skill_level),
		roundi(world_position.x), roundi(world_position.y), 目标串,
	])

## 命中那一拍的**结算请求**（42 AttackInfo）。没有目标就该不发（空发会让服务端拿 `-` 去查怪、
## 白报一条 rejected）。字段序与普攻 `request_basic_attack` 完全一致，只有 skillId/skillLevel/目标数不同。
func request_skill_damage(skill_id: int, skill_level: int, target_object_ids: Array,
		direction: int, stance := 11) -> bool:
	var 目标 := _技能目标串(target_object_ids)
	if 目标.is_empty():
		return false
	var 目标串 := "@".join(目标)
	var target_count := 目标.size()
	var damage_count := 1
	var fields := PackedStringArray([
		"1", str(character_id), "0", "1", str(damage_count), str(target_count),
		str((target_count << 4) | damage_count), "false", str(maxi(1, skill_level)), str(skill_id),
		str(stance), str(direction), 目标串,
	])
	var settled := send_game_request(42, "42:%s" % ":".join(fields))
	if not settled:
		for target_id in 目标:
			_pending_skill_hits.erase(int(target_id))
	return settled

## ── #352 打人链的三发上行（打**玩家**）───────────────────────────────
## 字段序与打怪那三发**完全一致**（服务端就一个解包器），只有两处不同：
##   · `isPlayer` 那一格 ⇒ 打怪也是 `"1"`（那是"发起方是玩家"，不是"目标是玩家"，
##     见 `request_basic_attack:1139-1156` 与 `request_skill_damage:1199-1216` 都是写死 1），
##     所以这三发**真正变的只有 targets**：填**目标的服务端角色号**而不是怪的 object_id。
##   · 1328 那一条把目标串放进 `players(@)` 那一格（打怪时它写死 `-`、串在 `monsters(@)`）。
## ⚠ **不要动 `request_basic_attack` / `request_skill_damage` / `announce_skill_cast`**：
##    打怪那条链上钉着一堆门（40/42/1328 的时序、目标串口径、`_pending_skill_hits` 认领），
##    改一个字就要重跑全量。这三发是**新增**，打怪行为一字未变。

## 普攻打人：**两发一起发**，各管一半。
## 1. `40`（AttackInfo）= 只负责"他在挥这一拳"的动画转发 —— 服务端 `handle_attack:40740-40752`
##    对 40 做的第一件事就是 `_send_visible(read_str, include_self=False)` 转给同屏的人。
## 2. `1328`（PLAYER_ATTACK，技能号填 **0**）= 真正让服务端去结算这一拳。
##    为什么非走 1328：原版 `AttackInfo.as:47` 的第一个字节 `isPlayer` 表示的是
##    **攻击者是玩家还是宠物**（紧跟它的就是 `petUid`），不是"目标是玩家"；
##    而 40 的 targets 那一格在原版是 `MobDamage.mobId`（`MobDamage.as` 的 `writeInt(mobId)`）
##    ⇒ 我们这份夹具里怪的 objectId 与角色号是**两套号**，服务端 `_attack_monster_target_ids:44804`
##    拿角色号去 `self.monsters` 查必然查不到、什么都不做（10-25 实测就是这样"打得动动画、不掉血"）。
##    1328 的字段布局里有**专门的 players 格**（`fields[12]`），服务端
##    `handle_player_attack_announce:41143-41145` 就是按角色号解析 + 过 `_can_attack_player` 闸，
##    过了才往被打的人身上挂 `PendingPvpHit:41325-41358`，由**他那侧的 tick** 合成
##    `PLAYER_DAMAGE` 结算并发 1329/1330（`:35473-35488`）。技能本来就是走这一条，普攻只是同一扇门。
func request_pvp_basic_attack(目标角色号: int, 世界位: Vector2, 朝向: int, stance := 11) -> bool:
	if 目标角色号 <= 0 or 目标角色号 == character_id:
		return false	## 原版 `SkillHandler.canAttack`：Character 那一支的 `objectId != 我的`
	var target_count := 1
	var damage_count := 1
	var fields := PackedStringArray([
		"1", str(character_id), "0", "1", str(damage_count), str(target_count),
		str((target_count << 4) | damage_count), "false", "0", "0",
		str(stance), str(朝向 if 朝向 != 0 else 1), str(目标角色号),
	])
	var 动画 := send_game_request(40, "40:%s" % ":".join(fields))
	var 结算 := announce_pvp_skill_cast(0, 1, [目标角色号], 世界位, 朝向, stance)
	return 动画 and 结算


## 技能打人的**结算请求**（42）：字段序同 `request_skill_damage`，targets 填角色号串。
func request_pvp_skill_damage(技能号: int, 技能等级: int, 目标角色号数组: Array,
		朝向: int, stance := 11) -> bool:
	var 目标 := _技能目标串(目标角色号数组)
	if 目标.is_empty():
		return false
	var 目标串 := "@".join(目标)
	var target_count := 目标.size()
	var damage_count := 1
	var fields := PackedStringArray([
		"1", str(character_id), "0", "1", str(damage_count), str(target_count),
		str((target_count << 4) | damage_count), "false", str(maxi(1, 技能等级)), str(技能号),
		str(stance), str(朝向 if 朝向 != 0 else 1), 目标串,
	])
	## ⚠ 这里**不登记** `_pending_skill_hits` —— 那张表按怪的 object_id 认领伤害回包
	## （`_handle_monster_damage_text` 那一路），角色号塞进去会把别人的伤害帧认错。
	return send_game_request(42, "42:%s" % ":".join(fields))


## 技能打人的**出手广播**（1328）：`players(@)` 那一格（打怪时写死 `-` 的那格）填角色号串，
## `monsters(@)` 反过来填 `-`。服务端 `_handle_player_attack_text` 会把这个 players 列表
## 广播给同图的人 ⇒ 旁观者看到的是"他在对这些人放这一招"。
func announce_pvp_skill_cast(技能号: int, 技能等级: int, 目标角色号数组: Array,
		世界位: Vector2, 朝向: int, stance := 11) -> bool:
	var 目标 := _技能目标串(目标角色号数组)
	var 目标串 := "@".join(目标) if not 目标.is_empty() else "-"
	return send_game_request(1328, "1328:%d:0:0:0:0:%d:%d:0:%d:%d:%d:%d:%s:-:0:-:-" % [
		character_id, stance, 朝向 if 朝向 != 0 else 1, 技能号, maxi(1, 技能等级),
		roundi(世界位.x), roundi(世界位.y), 目标串,
	])


func acknowledge_damage(monster_object_id: int, damage: int) -> bool:
	return send_game_request(44, JSON.stringify({"monsterObjectId": monster_object_id, "damage": damage}))
func request_distribute_ap(atk: int, def: int, dex: int, phy: int) -> bool:
	return send_game_request(OP_DISTRIBUTE_AP, "%d:%d:%d:%d" % [atk, def, dex, phy])

# `DISTRIBUTE_SP(87)` 这个 opcode 在原版 `SendOpCodes.as:86` 里**有**，但 `requestDistributeSp`
# 全客户端**没有一个调用点**（只有声明），忍术升级走的是 `SKILL_CHANGE(1330)`（见
# `request_skill_change`）。2026-10-18 删掉了原来拿 87 + JSON 当忍术升级的请求：
# 报文形状不是原版 `getDistributeSpRequestPacket`，夹具也没有 87 的处理器 ⇒ 只会被静默丢掉。


## 洗点上行：`83:<攻>:<防>:<敏>:<体>`（四段都是"这一项要还原多少点"）。
## 服务端 `handle_rewash_ap:34307-34361` 逐条核：任一为负 ⇒ 丢；超过"当前值−等级基值" ⇒ 回
## 「洗点数值无效」；总和 0 ⇒ 回「当前没有选中需要重洗的潜能点」；过了才扣卷 + 返还 + 回「洗点成功…」。
## ⇒ 这边**不做本地预扣**（原版也不做，`:1852` 就是发完等回帧），成功提示走服务端那条系统消息。
func request_rewash_ap(攻: int, 防: int, 敏: int, 体: int) -> bool:
	return send_game_request(OP_REWASH_AP, "%d:%d:%d:%d" % [攻, 防, 敏, 体])

## 移动 / 装备 / 卸下 / 丢弃（`ITEM_MOVE = 68`）。
##
## 报文体的**第一个字段必须是那个 `type`**：原版 `PacketCreator.getItemMoveRequestPacket`
## 是 `writeByte(type), writeShort(src), writeShort(dst), writeShort(quantity)`
## （`PacketCreator.as:159-167`），服务端 `handle_item_move` 也从 `fields[1]` 取源格：
##   `source = fields[1]; destination = fields[2]`，且第一句就是 `if source == 0: return`。
##
## ⚠️ 这里原来发的是 `"%d:%d:%d:%d" % [kind, src, dst, qty]` —— **少了一层**：
##    `_request_fields` 会把开头的 opcode 剥掉，于是 `kind` 被当成 `src`，
##    真正的 `src` 落到 `dst`，第一个字段成了常量 0 → 服务端每次都在
##    `if source == 0: return` 上静默吃掉。**表现就是"拖了没反应、装备穿不上"**，
##    而所有现存在线用例都没走这条路，所以一直没被发现（2026-09-21 装备用例抓出来的）。
func request_item_move(kind: int, source_slot: int, target_slot: int, quantity: int = 0) -> bool:
	return send_game_request(OP_ITEM_MOVE, "%d:%d:%d:%d:%d" % [OP_ITEM_MOVE, kind, source_slot, target_slot, quantity])

func request_item_sort(bag_type: int = 1) -> bool:
	return send_game_request(OP_ITEM_SORT, str(bag_type))


## 拆分堆叠。原版 `AllInOneProcessor.requestItemSplit`（`SendOpCodes.ITEM_SPLIT = 1332`）：
## `int position, int splitCount` —— 与 2.2.3 服务端 `handle_item_split` 读的
## `fields[0]=source_slot / fields[1]=split_count` 一致（以服务端为准的规矩见 §0 第 1 条）。
func request_item_split(slot: int, split_count: int) -> bool:
	return send_game_request(OP_ITEM_SPLIT, "%d:%d" % [slot, split_count])

func request_npc_shop(action: int, args: Array = []) -> bool:
	if action < 0 or action > 8:
		return false
	var values := [str(action)]
	for value in args:
		values.append(str(value).to_lower() if value is bool else str(value))
	return send_game_request(OP_NPC_SHOP, ":".join(values))

func request_npc_shop_buy(item_id: int, quantity: int = 1) -> bool:
	return request_npc_shop(0, [item_id, maxi(1, quantity)])

func request_npc_shop_sell(slot: int, item_id: int, quantity: int = 1) -> bool:
	return request_npc_shop(1, [slot, item_id, maxi(1, quantity)])

func request_npc_shop_recharge(slot: int) -> bool:
	return request_npc_shop(2, [slot])

func request_npc_shop_buy_consumables(enabled: bool) -> bool:
	return request_npc_shop(3, [enabled])

func request_npc_shop_sell_all_normal_equipment(start_slot: int, end_slot: int) -> bool:
	return request_npc_shop(4, [start_slot, end_slot])

## `PacketCreator.getNPCShopOnekeySellRequestPacket:102-111` = `writeByte(5)` + **4 个 writeInt**
## （等级上限、星级上限、品质上限、**目标位图**）。位图出自 `QuickSaleWindow.as:18-22`：
## 1=装备（恒有）、2=残卷、4=玉链 ⇒ 第四个字段不是"格子区间"的尾巴，旧签名那三个参数
## 是把「一键出售」当"卖 1..30 格"发出去了（巡检 #18：夹具把第 3 个读成品质上限 ⇒ 恒 0 ⇒ SHOP_ERROR）。
func request_npc_shop_one_key_sell(等级上限: int, 星级上限: int, 品质上限: int, 对象 := 1) -> bool:
	return request_npc_shop(5, [等级上限, 星级上限, 品质上限, 对象])

func request_secret_shop_open() -> bool:
	return request_npc_shop(6)

func request_secret_shop_buy(index: int) -> bool:
	return request_npc_shop(7, [index])

func request_secret_shop_refresh() -> bool:
	return request_npc_shop(8)


## VIP 通道（`OP_VIP 1818`）的六个动作号 = `AllInOneProcessor.as` 里各写一个 byte：
## `1 :933-938` 随身药店 / `2 :1761-1766` 随身仓库（**只发这两条**）/
## `3 :1731-1736`、`4 :957-962` 那两条是**外挂专用**
## （`openYaoDianHandler:1231` / `openCangKuHandler:1295` 判的是 `API.waiGuaHandler.isConnected`）。
## ⚠ 3/4 这里**故意不做**：本工程没有 `WaiGuaHandler` 那半边（自动购买/自动挂机），
## 补上就是凭空多两条上行 ⇒ 分支少一支，别照 AS3 抄回来。
## ⚠ `5 :4531-4536` / `6 :1462-1467`（**元宝付**那两条）2026-10-25 按用户报修 5.2
## 「删除 vip、vip 充值的内容按键逻辑」**整条删掉** ⇒ 等级闸与「购买VIP确认」弹一并没了（报修 5.1）。
## 回帧不在 1818 上：药店走 `OPEN_NPC_SHOP`（服务端 `_send_npc_shop(14)`）、
## 仓库走 `330:1`（`_send_storage_open:55713-55723`，`OPEN_STORAGE = 330`）⇒ 见 `窗口管理._on_npc_shop` / `_on_storage_opened`。
func request_vip(action: int) -> bool:
	return send_game_request(OP_VIP, str(action))

func request_vip_open_medicine() -> bool:
	return request_vip(1)

func request_vip_open_store() -> bool:
	return request_vip(2)


func request_storage(action: int, args: Array = []) -> bool:
	if action < 1 or action > 8 or action == 7:
		return false
	var values := [str(action)]
	for value in args:
		values.append(str(value))
	return send_game_request(OP_STORAGE, ":".join(values))

func request_storage_move(source_slot: int, destination_slot: int) -> bool:
	return request_storage(1, [source_slot, destination_slot])

func request_storage_take_item(storage_slot: int, quantity: int = 0) -> bool:
	return request_storage(2, [storage_slot, maxi(0, quantity)])

func request_storage_store_item(bag_slot: int, quantity: int = 0) -> bool:
	return request_storage(3, [bag_slot, maxi(0, quantity)])

func request_storage_store_gold(amount: int) -> bool:
	return request_storage(4, [maxi(0, amount)])

func request_storage_take_gold(amount: int) -> bool:
	return request_storage(5, [maxi(0, amount)])

func request_storage_remove_item(storage_slot: int) -> bool:
	return request_storage(6, [storage_slot])

func request_storage_close() -> bool:
	return request_storage(8)

func request_pet_action(action: int, args: Array = []) -> bool:
	if action < 0 or action > 22:
		return false
	var values := [str(action)]
	for value in args:
		values.append(str(value))
	return send_game_request(OP_PET_ACTION, ":".join(values))

func request_pet_list(item_id: int = 0) -> bool:
	return request_pet_action(0, [item_id])

func request_pet_call_out(unique_id: int) -> bool:
	return request_pet_action(1, [unique_id])

func request_pet_call_back(unique_id: int) -> bool:
	return request_pet_action(2, [unique_id])

func request_pet_rename(unique_id: int, pet_name: String) -> bool:
	return request_pet_action(3, [unique_id, pet_name.replace(":", "").left(12)])

func request_pet_feed(unique_id: int, item_id: int) -> bool:
	return request_pet_action(4, [unique_id, item_id])

func request_pet_release(unique_id: int) -> bool:
	return request_pet_action(5, [unique_id])

func request_pet_rewash_aptitude(unique_id: int, helper_count: int = 0) -> bool:
	return request_pet_action(6, [unique_id, maxi(0, helper_count)])

func request_pet_change_savvy(unique_id: int, helper_count: int = 0) -> bool:
	return request_pet_action(7, [unique_id, maxi(0, helper_count)])

func request_pet_learn_skill(unique_id: int, skill_or_book_id: int) -> bool:
	return request_pet_action(8, [unique_id, skill_or_book_id])

func request_pet_move(fields: Array) -> bool:
	return request_pet_action(9, fields)

func request_pet_auto_potion(unique_id: int, item_id: int) -> bool:
	return request_pet_action(10, [unique_id, item_id])

func request_pet_pickup(unique_id: int, map_object_id: int) -> bool:
	return request_pet_action(11, [unique_id, map_object_id])

func request_pet_chat(unique_id: int, chat_type: int, message: String) -> bool:
	return request_pet_action(12, [unique_id, chat_type, message.replace(":", "")])

func request_pet_attack_out(unique_id: int) -> bool:
	return request_pet_action(13, [unique_id])

func request_pet_attack_back(unique_id: int) -> bool:
	return request_pet_action(14, [unique_id])

func request_pet_put_equipment(unique_id: int, bag_slot: int) -> bool:
	return request_pet_action(15, [unique_id, bag_slot])

func request_pet_take_off_equipment(unique_id: int, equipment_slot: int) -> bool:
	return request_pet_action(16, [unique_id, equipment_slot])

func request_pet_evolve(unique_id: int, helper_count: int = 0) -> bool:
	return request_pet_action(17, [unique_id, maxi(0, helper_count)])

func request_pet_strength_potential(unique_id: int, helper_count: int, potential_type: int) -> bool:
	return request_pet_action(18, [unique_id, maxi(0, helper_count), potential_type])

## 扩张兽栏（`PET_ACTION` 子动作 **19**）。原版 `PetProcessor.requestExtendPetLimit`：
## `writeInt(19); writeInt(param1)`，而唯一调用点 `EnlargeWindow.as:296` 传的就是 **0**
## （`API.client.requestExtendPetLimit(0)`）⇒ 这里的入参**固定 0**，不是宠物 id。
## ⚠️ 本函数原叫 `request_pet_expand(unique_id)` 并把 unique_id 当第二字段发 —— 名字与载荷
## 都是错的（19 在协议里**只有**"扩兽栏"这一义，服务端 `_extend_pet_capacity` 直接忽略第二字段），
## 且当时**零调用点**。2026-10-11 接「扩展兽栏」行时一并纠正。
func request_extend_pet_limit() -> bool:
	return request_pet_action(19, [0])

func request_pet_catch(map_object_id: int) -> bool:
	return request_pet_action(21, [map_object_id])

func request_pet_soul_fusion(unique_id: int, selection: int) -> bool:
	return request_pet_action(22, [unique_id, selection])

func request_copy_history() -> bool:
	return send_game_request(OP_COPY_ACTION, "0")

func request_copy_open(copy_id: int) -> bool:
	return send_game_request(OP_COPY_ACTION, "1:%d" % copy_id)

func request_copy_confirm(confirmed: bool) -> bool:
	return send_game_request(OP_COPY_ACTION, "2:%s" % str(confirmed).to_lower())

func request_copy_reward(copy_id: int) -> bool:
	return send_game_request(OP_COPY_ACTION, "3:%d" % copy_id)

func request_copy_finish_escort() -> bool:
	return send_game_request(OP_COPY_ACTION, "4")

## 秘笈合成请求：`0:<主残卷 unique_id>:<幸运符张数>`（没勾传 0）。
## ⚠️ 第二参是**被放入格那一件的 unique_id**（原版 `writeDouble(_itemData.uniqueId)`），
## 不是格号也不是 item_id —— 夹具按 `item.unique_id == selected_unique_id` 找主件。
func request_can_juan_compose(残卷唯一号: int, 幸运符张数: int) -> bool:
	return send_game_request(OP_CAN_JUAN_ACTION, "0:%d:%d" % [残卷唯一号, maxi(0, 幸运符张数)])

## 首领刷新列表请求：**空 body**（原版 `requestWangList` 就是 `getEmptyPacket()` 一个字节不写，
## `AllInOneProcessor.as:2014-2017`）。开窗链路原版是"窗口不存在才发"（`UI.as:1675-1685`），
## 我们的 `首领窗口.gd` 在渲染时若会话还没列表才补发一次。
func request_wang_list() -> bool:
	return send_game_request(OP_WANG_LIST, "")

## 意志动作统一封装（12 个动作共用一条 opcode，正文 `动作号:参数…`，同宠物 `request_pet_action` 的形状）。
## 动作号↔语义照原版 `SpiritProcessor.as` + 夹具 `handle_spirit_action` 的分支表：
##   0 开面板(回1+7+6+0) / 1 点亮特殊导师(召唤) / 2 向导师学习 / 3 拾取单个(面板位) /
##   4 全部拾取 / 5 卖出单个 / 6 全部卖出(灰) / 7 扩背包格 / 8 一键合成 /
##   9 二合一(喂) / 10 格移动(to<0=穿戴位 -1..-8) / 11 一键学习
func request_spirit_action(动作号: int, 参数: Array = []) -> bool:
	if 动作号 < 0 or 动作号 > 11:
		return false
	return send_game_request(OP_SPIRIT_ACTION, ":".join([str(动作号)] + 参数.map(str)))

## 问一次百炼状态（action 0）⇒ 回 `1572:0:<进度>:<阅历>`。意志页开页时发（离线返回 false，
## 由调用方决定要不要出声——学习页选不出声，阅历留 0 与离线会话自洽）。
func request_pve_status() -> bool:
	return send_game_request(OP_PVE_ACTION, "0")

## 精英副本开窗自拉（原版客户端有 `requestHeroPlayerInfo`=1828/0 这条，虽反编译里查不到调用点
## ——本机服务端菜单 30 与这条都回同样的 0 帧，双保险）。
func request_hero_info() -> bool:
	return send_game_request(OP_HERO_ACTION, "0")

## 点精英格进本：`1828:1:<copyId>`（原版 `HeroProcessor.requestHeroEnter():84-91` ← `EliteCopyWindow.as:311`）。
func request_hero_enter(copy_id: int) -> bool:
	return send_game_request(OP_HERO_ACTION, "1:%d" % copy_id)

## ⚠ 原来这里有一条 `request_hang_state()` 发 `"2"`：原版 1808 **只有 0/1 两档**
## （`Client.as` 的 `requestGuaJi(0/1)`），服务端 `handle_hang_action:18326` 也只认 0/1、
## 别的值整个忽略 ⇒ 那条"查询"从来没有任何回帧，却让它把在线门写成"等一个永远不来的信号"。
## 挂机状态是**本地状态机**（原版 `GuajiHandler` 自己记），别等回帧。
func request_hang_start() -> bool:
	return send_game_request(OP_HANG_ACTION, "0")

func request_hang_stop() -> bool:
	return send_game_request(OP_HANG_ACTION, "1")

## 1283 查询：载荷就一个 `0`（服务端 `handle_char_config:17900` 判 `payload == "0"` 后
## 走 `_send_char_config()` 回一帧）。这是原版 `CharacterConfig` 进图时同步用的同一条。
func request_hang_config_query() -> bool:
	return send_game_request(OP_CHAR_CONFIG, "0")

## 1283 保存：载荷 = 整个 JSON 对象（**不带 action 位、不带 opcode**），服务端逐键覆盖
## `character_config` 再落存档。不发的键保持原值 ⇒ `keyData` 不在这里发，快捷键表不会被抹掉。
func request_hang_config_save(配置: Dictionary) -> bool:
	return send_game_request(OP_CHAR_CONFIG, JSON.stringify(配置))

## 7779 自动出售：四个 int。服务端 `handle_auto_sell_config:27093` 存表 + 把下一轮巡检提前
## + **在聊天栏回一句**「自动出售已开启/已关闭」⇒ 点完看得见。
func request_auto_sell_config(掩码: int, 等级上限: int, 职业序号: int, 品质上限: int) -> bool:
	return send_game_request(OP_AUTO_SELL_CONFIG,
		"%d:%d:%d:%d" % [掩码, 等级上限, 职业序号, 品质上限])


## 复活（`MAKE_ALIVE = 1281`）。原版 `ReliveWindow` 那两个按钮走的是同一条协议、
## 只差第一位：`originLiveHandler:232-242` 发 **1**（原地，带复活道具号），
## `backLiveHandler:133-138` 发 **0**（回城）—— 见 `PacketCreator.as:857-863`
## `writeByte(type) + writeInt(itemId)`，服务端 `handle_make_alive:45029-45047`
## 按 `ReviveMode.IN_PLACE=1 / RETURN_TO_MAP=0` 解，且只认道具号 0 或 16000010。
## ⚠ 这条上行**本工程从来没发过**（客户端一直是自己把角色搬回出生点），
## 服务端两个 handler 一直在（`:714` 注册、`:45029` 实现）。
const OP_MAKE_ALIVE := 1281


func request_revive(档: int, 道具号: int = 0) -> bool:
	if 档 != 0 and 档 != 1:
		return false
	return send_game_request(OP_MAKE_ALIVE, "%d:%d" % [档, 道具号])

func request_cash_money() -> bool:
	return send_game_request(OP_CASH_MONEY_REQUEST, "0")

func request_cash_shop_category(category_id: int, index_begin := 0, index_end := 29, shop_type := 0) -> bool:
	return send_game_request(OP_CASH_CATEGORY_REQUEST, "%d:%d:%d:%d" % [shop_type, category_id, maxi(0, index_begin), maxi(index_begin, index_end)])

func request_cash_shop_search(keyword: String, category_id := -1, index_begin := 0, index_end := 29, price_begin := 0, price_end := 2147483647) -> bool:
	var clean := keyword.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges()
	return send_game_request(OP_CASH_SEARCH, "%d:%s:%d:%d:%d:%d" % [category_id, clean, maxi(0, price_begin), maxi(price_begin, price_end), maxi(0, index_begin), maxi(index_begin, index_end)])

## 商城下单（`CS_REQ_CASH_BUY` 那支：`431|432…:1:<sn>:<数量>`，`shop_type` 0=元宝 1=点券）。
## 数量硬闸 **1..9999**：原版 `BuyEqpWindow.as:249` 的 `maxCount` 算的是 `floor(余额/单价)`
## （**不是**堆叠上限），报文本身按 `ShopItem.as:39` 的 `readUnsignedShort` 走得动 9999；
## 真正的"超过一摞能装多少"由服务端 `_item_stack_limit` 结算（用户 2026-10-21 要求把 99/999 抬到 9999，
## 见 `游戏数据.堆叠上限` 与 `真值/物品/堆叠上限.md`）。
func request_cash_shop_buy(item_sn: int, quantity := 1, shop_type := 0) -> bool:
	if item_sn <= 0:
		return false
	return send_game_request(OP_CASH_SHOPPING, "%d:%d:%d" % [shop_type, item_sn, clampi(quantity, 1, 9999)])

## **申请扩充背包**（1084）—— ⚠️ **这不是"查背包容量"**，是一个**会改存档的动作**：
## 服务端 `服务端/runtime/tools/fake_flash_server.py:26118 handle_bag_capacity_extend`
## → `_extend_item_capacity:26126`，密卷不够就广播「扩充背包需要%d个扩充密卷。」，
## 密卷够就**当场扣掉、背包 +30 格并落盘**。所以只许由 `背包窗口` 扩容窗的「确定」发这一发，
## **不许挂在商城开窗那类"顺手查一下"的路上**（2026-10-21 用户报的"进商城就提示要 162 个密卷"
## 就是 `游戏会话._request_cash_shop_metadata_later` 把它当查询发了一次）。
## 背包容量的权威来源是进图 `CHAR_INFO` 下发 + 本条的回包 `1084:新容量`。
func request_cash_shop_capacity() -> bool:
	return send_game_request(OP_CASH_CATEGORY_CAPACITY, "1")

## 扩充仓库一格/一页（1085，同样**不是查询**）。服务端 `handle_storage_capacity_extend`
## （`服务端/runtime/tools/fake_flash_server.py:26122`）忽略入参，
## 消耗背包里的「扩充密卷」后回 `1085:新容量` + 一条系统公告。
func request_cash_storage_capacity() -> bool:
	return send_game_request(OP_CASH_STORAGE_CAPACITY, "1")


func request_cash_item_info(item_sn: int, shop_type := 0) -> bool:
	# 只发一个字段：服务端 handle_cash_item_info 取 fields[0] 当**物品 id** 用
	# （其二进制翻译也是 `f"{prefix}:{一个整数}"`），而商城行的编码里首个字段就是
	# 物品 id——所以本服务端下 sn 即 item_id。多发一个 shop_type 会让 fields[0]
	# 变成 0，服务端查不到物品、不回 1079。shop_type 参数保留是为了不动调用点。
	if item_sn <= 0:
		return false
	return send_game_request(OP_CASH_ITEM_INFO_REQUEST, str(item_sn))

## 兑换十拳剑（灵器）。原版 `LingEquipProcessor.requestLingEquipHeCheng` = 字节 3 + 两个 int 0。
## 灵器**开光** —— `LING = 2081` 子命令 **0** + (itemId, itemPos)
## （`LingEquipProcessor.as:116-122` `writeByte(0)`）。
## 变身卡**普通交换**（基础+附加属性）—— `ITEM_CHANGE` 子命令 **29** + (格A, 格B)
## （`ItemChangeProcessor.as:105-112` `writeByte(29)`）。
func request_transform_card_swap(slot_a: int, slot_b: int) -> bool:
	return request_item_change(29, [slot_a, slot_b])


## 变身卡**特性交换**（只换特性）—— 子命令 **39** + (格A, 格B)
## （`:114-121` `writeByte(39)`）。29/39 两条都只带**背包格号**。
func request_transform_card_special_swap(slot_a: int, slot_b: int) -> bool:
	return request_item_change(39, [slot_a, slot_b])


func request_ling_equip_kai_guang(item_id: int, item_slot: int) -> bool:
	return send_game_request(OP_LING, "%d:%d:%d" % [0, item_id, item_slot])


## 灵器**灵化** —— 子命令 **1**（`:107-113` `writeByte(1)`）。
func request_ling_equip_ling_hua(item_id: int, item_slot: int) -> bool:
	return send_game_request(OP_LING, "%d:%d:%d" % [1, item_id, item_slot])


## 灵器**洗炼** —— 子命令 **2**（`:125-131` `writeByte(2)`）。
func request_ling_equip_wash(item_id: int, item_slot: int) -> bool:
	return send_game_request(OP_LING, "%d:%d:%d" % [2, item_id, item_slot])


func request_ling_equip_combine() -> bool:
	return send_game_request(OP_LING, "%d:0:0" % LING_COMBINE)


## 十拳剑「改变外观」：列脸/色表、换脸、换色。
## 原版字节序见 `LingEquipProcessor.as`：4 无参、5/6 各一个 int；
## 本客户端是文本帧 ⇒ `2081:4` / `2081:5:<faceId>` / `2081:6:<colorId>`。
func request_ling_qi_face_list() -> bool:
	return send_game_request(OP_LING, str(4))


func request_ling_qi_change_face(face_id: int) -> bool:
	return send_game_request(OP_LING, "%d:%d" % [5, face_id])


func request_ling_qi_change_color(color_id: int) -> bool:
	return send_game_request(OP_LING, "%d:%d" % [6, color_id])


## 兑换忍具（八咫镜六碎片合成）。原版 `RenJuProcessor.requestRenJuHeCheng` = 单个字节 3。
func request_renju_combine() -> bool:
	return send_game_request(OP_RENJU, str(RENJU_COMBINE))

## 忍具开光（原版 `requestRenJuKaiGuang(param1,param2)` = 动作 0 + 两个 int）。
func request_renju_kai_guang(item_slot: int, value: int) -> bool:
	return send_game_request(OP_RENJU, "%d:%d:%d" % [0, item_slot, value])

## 八咫镜**属性抗性换档** —— 原版 `RenJuProcessor.requestRenJuResistance:45-51`
## = 动作字节 4 + **一个 byte** 的元素号（`onClickPopupMenu:472-483` 的四发：
## 1 火 / 2 水 / 3 雷 / 4 风；**0 = 让服务端轮下一档**，出处是 `EquipPane.as:396-399` 的双击）。
## 号与名两边同一份：服务端 `YATA_RESISTANCE_NAMES = {1:火, 2:水, 3:雷, 4:风}`。
## ⚠ 原版**没有这一档的回帧分支** —— `handleRenJuOperationResult:65-73` 只 switch 0（开光）
##   与 3（合成），客户端发完就当没事发生。本工程服务端同法：`_switch_yata_resistance:53571`
##   落盘后**一句提示都不发**（2026-11-04：以前每次上线都往聊天框灌 "八咫镜当前为X属性抗性"，
##   那不是原版行为，已删）。
##   ⇒ 别在这里等结果帧、也别为它编一句本地提示（原版一句都没有）。
func request_renju_resistance(element: int) -> bool:
	return send_game_request(OP_RENJU, "%d:%d" % [RENJU_SWITCH_RESISTANCE, element])


func request_guild(action: int, args: Array = []) -> bool:
	var values := [str(action)]
	for value in args:
		values.append(str(value))
	return send_game_request(OP_GUILD, ":".join(values))

## 玩家搜索。字段序按服务端 `handle_char_search`：`<search_id>:<mode>:<名字>`。
##   **mode 1 = 按名字搜全服角色**（家族「查询玩家」要的就是它，会看 `名字`）；
##   mode 2 = 同屏可见玩家（**不看名字**，`visible_peers`）。
## 默认 1 —— 用 2 按名字查会恒返回空（我第一版就踩了）。
## `1282:<searchType>:<mode>[:<名字>]`。**名字为空时整段不发**（不留尾随冒号）——
## 原版 `Client.requestCharSearchInMap` 走的是 `writeInt(searchType); writeByte(2); writeShort(0)`，
## mode 2 那一支**包体里根本没有第三个字段**；服务端 `handle_char_search:35004` 也是
## `fields[2] if len(fields) > 2 else ""` 的读法 ⇒ 少一段才是原样。
func request_char_search(搜索名: String, mode := 1, search_id := 4) -> bool:
	var 体 := "%d:%d" % [search_id, mode]
	return send_game_request(OP_CHAR_SEARCH, 体 if 搜索名.is_empty() else 体 + ":" + 搜索名)


func request_guild_summary(guild_id := 0) -> bool:
	return request_guild(102, [maxi(0, guild_id)])

func request_guild_create(guild_name: String, flag_style := 0, flag_name := "", notice := "团结协作，共同守护木叶。", flag_color := 0) -> bool:
	var clean_name := guild_name.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(24)
	var clean_flag := flag_name.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(24)
	var clean_notice := notice.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(120)
	return request_guild(1, [flag_style, clean_name, clean_flag if not clean_flag.is_empty() else clean_name, clean_notice, flag_color])

func request_guild_list(page := 1, page_size := 100) -> bool:
	# 服务端 _handle_multiplayer_family 的 action 101 取 fields[1]=每页条数、fields[2]=页码，
	# 与原实现的 (page, page_size) 顺序相反。顺序错时服务端会算出 page_size=1/page=10，
	# 取到 families()[9:10]，于是列表恒为空。
	#
	# 每页条数的默认值是 **100**（原版 `preloadFamillyList` → `requestBanghuiQueryBanghuiList(100, page)`，
	# `FM.as:1268`）：服务端单页上限也就 100，所以要一次拿全就得显式要 100。给 10 的话
	# 家族超过 10 个就永远看不全（回包会按 total 继续累计拉取，见 action 3 的注释）。
	#
	# 起始页同时重置累计状态（`_族列表累计` / `_族列表拉取中`）—— 否则上一次没拉完的
	# 残余会和这一次的第一页拼在一起。
	if page <= 1:
		_族列表拉取中 = false
		_族列表累计.clear()
	return request_guild(101, [clampi(page_size, 1, 200), maxi(1, page)])

## 「申请加入」——原版 `Client.requestBanghuiApply` → `BanghuiProcessor.requestApply`
## （`:174-180`）：`writeShort(2)` + `writeInt(家族id)`。服务端 `handle_banghui` 的
## `action == 2` 收 fields[1]=家族 id。
func request_guild_apply(guild_id: int) -> bool:
	return request_guild(2, [maxi(0, guild_id)])


func request_guild_invite(角色号: int) -> bool:
	## `requestInvite:809-815` = 19 + 角色号（`requestBanghuiInvite`）。
	## 服务端闸 = 族长（本轮扩成族长/副族长，见 `fake_flash_server` action 19）。
	return 角色号 > 0 and request_guild(19, [角色号])


func request_guild_members(guild_id := 0, detailed := false) -> bool:
	return request_guild(105 if detailed else 104, [maxi(0, guild_id)])


## ── 成员管理七发（`BanghuiProcessor.as` 逐个对过：动作号 + 载荷类型）──────────
## 全码 `writeShort(<动作>) + writeInt(<角色号>)`；改职务多一个 `writeInt(rank)`、
## 改族内昵称多一个 `writeUTF(昵称)`；自动同意是 `writeInt(0|1)`。
## 权限一律在服务端（`is_leader`；部分还要求 rank），客户端不加闸、只负责把参数发对。
## action 22（弹劾族长，`requestKickBanghuiLeader:764-769`）= 空载荷；本轮服务端已补：
## 消耗 15019001「弹劾令」、把弹劾者提为族长，并对全族推 `1552:7:0` + 新摘要。
func request_guild_expel(角色号: int) -> bool:
	## `requestExpel:461-466` = 4 + 角色号。族长开除族员。
	return 角色号 > 0 and request_guild(4, [角色号])


func request_guild_reject_apply(角色号: int) -> bool:
	## `requestRejectApply:20-25` = 13 + 申请者角色号（不是家族 id）。
	## 服务端给申请者回 `1552:9:<族长名>`。
	return 角色号 > 0 and request_guild(13, [角色号])


func request_guild_accept_apply(角色号: int) -> bool:
	## `requestAcceptApply:427-432` = 14 + 申请者角色号。
	return 角色号 > 0 and request_guild(14, [角色号])


func request_guild_member_nick(角色号: int, 昵称: String) -> bool:
	## `requestChangeMemberNick:127-133` = 16 + 角色号 + UTF 昵称。
	## ⚠️ 这一发走的是同一套冒号分隔文本帧 ⇒ 昵称里的 `:` 会被当成字段分隔符，
	##    必须在客户端就换成全角（服务端也做一次，双保险）。
	var 文本 := 昵称.replace(":", "：").strip_edges().left(12)
	return 角色号 > 0 and request_guild(16, [角色号, 文本])


func request_guild_member_rank(角色号: int, rank: int) -> bool:
	## `requestChangeMemberRank:614-621` = 17 + 角色号 + rank。
	## rank 只收原版那几档（`FamillyManager.as:51-61`：2 副族长 / 3 长老 / 4 顾问 /
	## 5 精英 / 9999 族员）；族长(1)只能靠禅让，不能被"任命"出来。
	if 角色号 <= 0 or not [2, 3, 4, 5, 9999].has(rank):
		return false
	return request_guild(17, [角色号, rank])


func request_guild_change_leader(角色号: int) -> bool:
	## `requestChangeLeader:41-46` = 18 + 角色号。禅让族长。
	return 角色号 > 0 and request_guild(18, [角色号])


func request_guild_impeach() -> bool:
	## `requestKickBanghuiLeader:764-769` = 22，**空载荷**（`getEmptyPacket` 只写 action）。
	return request_guild(22)


func request_guild_auto_accept(要: bool) -> bool:
	## `requestChangeAutoAcceptMember:545-550` = 20 + `writeInt(0|1)`。
	## ⚠ 原版这一项**只写本地 CharacterConfig**（`FamillyMembersWindow.as:140-145`，不发协议）；
	##    本机服务端有多人侧的 `autoAccept` 字段，所以本工程改为**服务端权威** ——
	##    否则组长在 A 端关掉自动同意、B 端的人照样直接进族。
	return request_guild(20, [1 if 要 else 0])

func request_guild_leave() -> bool:
	return request_guild(6)

func request_guild_disband() -> bool:
	return request_guild(5)

## 修改家族公告（服务端 action 7，仅族长生效：`_handle_multiplayer_family` 的
## `action == 7`）。原版 `FamillyWindow` 公告区那个「修改」钮就是它。
## ⚠️ 服务端用 `":".join(fields[1:])`，所以公告里的英文冒号会被换成全角——
##    本桥只发一段文本，客户端侧就已经把 `:` 换掉了（见调用点）。
func request_guild_notice(notice: String) -> bool:
	var 文本 := notice.replace(":", "：").replace("@", "＠").replace("&", "＆").strip_edges().left(80)
	return request_guild(7, [文本])

func request_guild_upgrade_flag() -> bool:
	return request_guild(10)

## 背包里某件物品的**权威**数量（汇总服务端下发的 `authoritative_inventory`）。
## 家族创建/升级的门槛判定都走它 —— 原来各填充脚本各遍历一遍背包，写法还不完全一样。
func inventory_quantity(item_id: int) -> int:
	if item_id <= 0:
		return 0
	var 合计 := 0
	for 物品 in authoritative_inventory:
		var 行 := 物品 as Dictionary
		if int(行.get("id", 行.get("item_id", 0))) == item_id:
			合计 += int(行.get("quantity", 行.get("count", 0)))
	return 合计


## 家族名重名检测（服务端 `action 21`，回包 `19:<0|1>`）。
## 原版 `FamillyCreateWindow.nameValidateHandler` → `requestBanghuiCheckBanghuiName`（创建窗的
## 「检测重名」钮），服务端 `_handle_multiplayer_family` 的 `action == 21` 拿它和已有家族名
## 逐一比对后回 `19`。⚠️ 这条链路我们原来**完全没接**，所以那颗钮点了没反应。
func request_guild_check_name(家族名: String) -> bool:
	var 名 := 家族名.strip_edges().replace(":", " ").replace("@", " ").replace("&", " ").left(24)
	if 名.is_empty():
		return false
	return request_guild(21, [名])


## 改家族旗帜名（服务端 `action 8`，仅族长；`_handle_multiplayer_family` 里
## `family = self.accounts.update_family(..., flagName=fields[1][:12])`）。
func request_guild_set_flag_name(旗名: String) -> bool:
	var 文本 := 旗名.replace(":", "：").replace("@", "＠").replace("&", "＆").strip_edges().left(12)
	if 文本.is_empty():
		return false
	return request_guild(8, [文本])


## 改家族旗帜样式（服务端 `action 9`，仅族长；`flagStyle=max(1000, fields[2])`，
## 所以样式号必须 ≥ 1000，和创建时的口径一致）。
func request_guild_set_flag_style(样式: int) -> bool:
	return request_guild(9, [maxi(1000, 样式)])

## 家族捐献（服务端 action 12）。载荷形态 "itemId&数量@itemId&数量"，
## **itemId=0 表示捐金币**（进家族资金），itemId>0 捐物品（进家族材料）。
## 家徽升级要的正是家族资金 666 + 四种材料各 1，所以升级前必须先捐。
func request_guild_donate(entries: Array) -> bool:
	if entries.is_empty():
		return false
	var rows := PackedStringArray()
	for entry in entries:
		rows.append("%d&%d" % [int(entry[0]), int(entry[1])])
	return request_guild(12, ["@".join(rows)])

func request_guild_flag(guild_id := 0) -> bool:
	return request_guild(103, [maxi(0, guild_id)])

func request_guild_shop() -> bool:
	return request_guild(205)

func request_guild_shop_buy(item_id: int) -> bool:
	if item_id <= 0:
		return false
	return request_guild(206, [item_id])


## 地图族旗列表。原版 `MapFlagProcessor.requestQueryMapFlagList`（`:134-139`）：
## `writeByte(0)` → `MAP_FLAG_ACTION(1815)`，即本桥的 `1815:0`。
func request_flag_list() -> bool:
	return send_game_request(OP_MAP_FLAG_ACTION, "0")

## 原版 MapFlagProcessor：action 1=安插族旗，action 2=修复族旗血量。
## 两者都只带目标地图 id，结果由服务端权威回包后重新查询列表。
func request_map_flag_add(map_id: int) -> bool:
	if map_id <= 0:
		return false
	return send_game_request(OP_MAP_FLAG_ACTION, "1:%d" % map_id)

func request_map_flag_cure(map_id: int) -> bool:
	if map_id <= 0:
		return false
	return send_game_request(OP_MAP_FLAG_ACTION, "2:%d" % map_id)

func request_map_flag_damage(map_id: int, damage: int) -> bool:
	if map_id <= 0 or damage <= 0:
		return false
	return send_game_request(OP_MAP_FLAG_ACTION, "3:%d:%d" % [map_id, damage])

func request_guild_boss_state() -> bool:
	return request_guild(201)

func request_guild_boss_enter() -> bool:
	return request_guild(203)

func request_guild_boss_claim() -> bool:
	return request_guild(204)

## ── 族邀（逐件真值：`真值/窗口/家族邀请窗.md`）────────────────────────────
## 三条上行的子命令号一律回 `BanghuiProcessor.as` 的 `writeShort(...)` 现查，
## **不是**「发什么号就收什么号」：发 19 ⇒ 服务端给对面推的是 **16**。
## 同意/拒绝带的是**家族 id**（`param1.id`），不是角色号 —— 服务端 `:33384`/`:33358`
## 都拿它比对存着的那份 `familyInviteId`，对不上就一句话都不回。
func request_family_invite(号: int) -> bool:
	## `requestInvite:809-815` = `writeShort(19)` + `writeInt(对方角色号)`。
	## 客户端侧没有闸（`FamillyManager.invateToJoinFamilly:779-782` 就一行转发）；
	## 权限在服务端：不是族长 ⇒ 这一发落到 `is_leader` 之外，什么也不会发生。
	return 号 > 0 and request_guild(19, [号])

## 按名字邀人入族（聊天栏右键那一行拿到的只有名字，同 `request_friend_add_by_name`）。
## 解析不到 ⇒ 返回 false，由调用方**说话**；不发 `1552:19:0` 那种空号帧去"演"一次成功。
func request_family_invite_by_name(player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		return false
	for 人在 in map_players.values():
		if 人在 is Dictionary and String((人在 as Dictionary).get("name", "")) == clean:
			return request_family_invite(int((人在 as Dictionary).get("character_id", 0)))
	return false

func request_family_invite_accept(族id: int) -> bool:
	## `requestAcceptInvitation:720-725` = `writeShort(15)` + `writeInt(家族id)`。
	return 族id > 0 and request_guild(15, [族id])

func request_family_invite_reject(族id: int) -> bool:
	## `requestRejectInvitation:509-514` = `writeShort(3)` + `writeInt(家族id)`。
	## 服务端给**族长**回 `1552:9:<拒绝者名>`，族长侧原版 `actionBanghuiRejectInvitation`
	## 不弹任何东西 ⇒ 本工程也不给它加提示（别自造「某某拒绝了你的邀请」）。
	return 族id > 0 and request_guild(3, [族id])

func request_friend(action: int, target = "") -> bool:
	var clean := str(target).replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(24)
	return send_game_request(OP_FRIEND_REQUEST, str(action) if clean.is_empty() else "%d:%s" % [action, clean])

func request_friend_list() -> bool:
	return request_friend(0)

## 加好友：服务端 `_handle_multiplayer_friend` 的 action 1 取的是**角色编号**
## （`_safe_int(fields[1])`），原版 AS3 的 `requestAddFriend(int)` 同为编号——
## 传名字会被解析成 0、服务端直接忽略（现象：好友申请永远不送达）。
func request_friend_add(character_id: int) -> bool:
	return character_id > 0 and request_friend(1, character_id)

## 按名字加好友：先从**同屏玩家**实体（服务端下发，带 character_id 与 name）解析出编号。
## 目标不在同屏时解析不到，需要走原版的角色搜索流程（CHAR_SEARCH）才能加。
func request_friend_add_by_name(player_name: String) -> bool:
	var clean := player_name.strip_edges()
	if clean.is_empty():
		return false
	for player in map_players.values():
		if player is Dictionary and String((player as Dictionary).get("name", "")) == clean:
			return request_friend_add(int((player as Dictionary).get("character_id", 0)))
	return false

func request_friend_accept(character_id: int) -> bool:
	return character_id > 0 and request_friend(2, character_id)

func request_friend_delete(character_id_or_name) -> bool:
	return request_friend(3, character_id_or_name)

## 「最近」页删一行 = 原版 `FriendProcessor.requestDeleteRecent:442-448` 的 **action 7**
## （`Client.as:9505` → `Friend_requestDeleteRecent`）。跟好友删除的 3 不是同一档：
## 3 会把对方从好友列表里摘掉，7 只清「最近联系人」这一页。
func request_friend_delete_recent(character_id: int) -> bool:
	return character_id > 0 and request_friend(7, character_id)

## 「仇人」页删一行 = `FriendProcessor.requestDeleteEnemy:450-456` 的 **action 9**
## （`Client.as:9897` → `Friend_requestDeleteEnemy`）。
func request_friend_delete_enemy(character_id: int) -> bool:
	return character_id > 0 and request_friend(9, character_id)

func request_friend_block(character_id_or_name) -> bool:
	return request_friend(4, character_id_or_name)

func request_friend_unblock(character_id_or_name) -> bool:
	return request_friend(6, character_id_or_name)

## 好友私聊：原版 `FriendProcessor.requestSendMsg:460-466` = `writeByte(8)` + `writeInt` + `writeUTF`
## ⇒ `127:8:<角色号>:<正文>`（`Client.as:2313` 那条 `Friend_requestChatWithFriend`）。
## ⚠ 不走 `request_friend()`：那个助手会把 `:` 洗成空格，而正文里的冒号在服务端是
##    `":".join(fields[2:])` 拼回去的（保留成全角「：」），不该在客户端先改形状。
func request_friend_chat(character_id: int, message: String) -> bool:
	var 正文 := String(message).replace("\r", " ").replace("\n", " ")
	if character_id <= 0 or 正文.is_empty():
		return false
	return send_game_request(OP_FRIEND_REQUEST, "8:%d:%s" % [character_id, 正文])

## 打探：原版 `FriendProcessor.requestFindEnemy:26-32` = `writeByte(10)` + `writeInt`
## ⇒ `127:10:<角色号>`。回包走 `find_enemy_result_received`。
func request_friend_find_enemy(character_id: int) -> bool:
	return character_id > 0 and send_game_request(OP_FRIEND_REQUEST, "10:%d" % character_id)

func request_friend_reject(character_id: int) -> bool:
	return character_id > 0 and request_friend(11, character_id)

## ── 羁绊（求婚）四条上行，`61` 族；包体形状逐条回 AS3 `FriendProcessor` 的 `writeByte` 列全表 ──
## ⚠ 一律**不走** `request_friend()`：那个助手会把 `:` 洗成空格（防注入），
## 而 20/21 两发是**两个 int**（`writeByte(20) + writeInt + writeInt`），拼出来的串必须原样出去。
func request_bond_start(号: int) -> bool:
	## `requestTaStart:491-497` = `15` + int ⇒ `127:15:<对方角色号>`。
	## 服务端 `:23225-23241` 要求**对面在线**，不在线整条 return、一句都不回 ⇒ 别把"没反应"当成坏了。
	return 号 > 0 and send_game_request(OP_FRIEND_REQUEST, "15:%d" % 号)

func request_bond_invite(号: int, 戒指id: int) -> bool:
	## `requestAddTa:458-464` = `20` + int + int ⇒ `127:20:<号>:<对戒物品号>`。
	## 对戒只认 `190[1-8]0001` 且**要在背包里**（服务端 `_is_bond_pair_item:22926` / `_bond_pair_item:22930`）。
	return 号 > 0 and 戒指id > 0 and send_game_request(OP_FRIEND_REQUEST, "20:%d:%d" % [号, 戒指id])

func request_bond_accept(号: int, 戒指id: int) -> bool:
	## `requestAcceptTa:34-40` = `21` + int + int ⇒ `127:21:<求方号>:<对戒物品号>`。
	return 号 > 0 and 戒指id > 0 and send_game_request(OP_FRIEND_REQUEST, "21:%d:%d" % [号, 戒指id])

func request_bond_refuse(号: int) -> bool:
	## `requestRefuseTa:419-424` = `22` + int ⇒ `127:22:<求方号>` ⇒ 求方收 `61:18:<我的名>` 那一句。
	return 号 > 0 and send_game_request(OP_FRIEND_REQUEST, "22:%d" % 号)

func request_party(action: int, value = "") -> bool:
	var clean := str(value).replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(32)
	return send_game_request(OP_PARTY_REQUEST, str(action) if clean.is_empty() else "%d:%s" % [action, clean])

func request_party_state() -> bool:
	return request_party(9)

func request_party_create(party_name := "") -> bool:
	return request_party(1, party_name)

func request_party_leave() -> bool:
	return request_party(2)

func request_party_accept(party_id: int) -> bool:
	return request_party(3, maxi(0, party_id))

func request_party_invite(player_name: String) -> bool:
	return request_party(4, player_name)

func request_party_expel(character_id_or_name) -> bool:
	return request_party(5, character_id_or_name)

func request_party_change_leader(character_id_or_name) -> bool:
	return request_party(6, character_id_or_name)

func request_party_disband() -> bool:
	return request_party(7)

func request_party_rename(party_name: String) -> bool:
	return request_party(8, party_name)

func request_nearby_parties() -> bool:
	return request_party(10)

## 拒绝组队邀请 = **`120:13:<队长名>`**。
## ⚠ 原版这一发跟的是**队长名字**不是队伍号：`PartyProcessor.as:430-434` →
## `PacketCreator.as:865-871` 写的是 `writeByte(13)` + **`writeUTF(captainName)`**
## （本工程以前按队伍号发 ⇒ 与原版不同；本机服务端 `_handle_multiplayer_party` 压根没实现 13，
## 所以两种发法今天都没人接，改回真值是为了以后接上时不用再猜）。
func request_party_reject(captain_name: String) -> bool:
	return not captain_name.is_empty() and request_party(13, captain_name)

## 把六子页要用的礼包状态**一次查全**（首次登录 / 周登录 / 线上有礼 / 每日签到 / 等级）。
## 原版是各页各自查（`GiftProcessor` 里一个 action 一个方法），这里合并成一次调用只为
## 让"开窗就有数"好写；发出去的仍然是**五个原版 action**，不是自造的组合包。
## 每收到一条回包都会发一次 `gift_state_received`（带 `gift` 键），所以用例等任一即可。
func request_gift_state() -> bool:
	var 发出 := false
	for action in [GIFT_QUERY_FIRST, GIFT_QUERY_WEEKLY, GIFT_QUERY_MONTHLY,
			GIFT_QUERY_EVERYDAY, GIFT_QUERY_LEVEL]:
		发出 = send_game_request(OP_GIFT, str(action)) or 发出
	return 发出

## 领福利。`kind` 是本移植给六个子页起的名字，**映射到原版 action** 见下表；
## `argument` 只有 `first`（礼包下标）与 `weekly`（累计天数）用得上。
func request_gift_claim(kind: String, argument := "") -> bool:
	var clean_kind := kind.replace(":", "").strip_edges().to_lower()
	match clean_kind:
		"first":
			return send_game_request(OP_GIFT, "%d:%d" % [GIFT_GAIN_FIRST, int(argument) if not argument.is_empty() else 0])
		"weekly":
			return send_game_request(OP_GIFT, "%d:%d" % [GIFT_GAIN_WEEKLY, int(argument) if not argument.is_empty() else 0])
		"monthly":
			return send_game_request(OP_GIFT, str(GIFT_GAIN_MONTHLY))
		"daily":
			# 「每日签到」= 原版 `requestGainEverydayGift`（byte 42）。
			return send_game_request(OP_GIFT, str(GIFT_GAIN_EVERYDAY))
		"level":
			return send_game_request(OP_GIFT, str(GIFT_QUERY_LEVEL))
		_:
			return false

func request_gift_code(code: String) -> bool:
	var clean := code.replace(":", "").replace("@", "").strip_edges().to_upper().left(40)
	return not clean.is_empty() and send_game_request(OP_GIFT, "%d:%s" % [GIFT_CODE, clean])

## 拉充值活动全量（配置 + 限时大奖/新服有礼/首杀礼包三种 status）。
## 服务端回 cmd 2/1/3/4 四条，见 `_handle_czhuodong_dictionary`。
func request_czhuodong_bootstrap() -> bool:
	return send_game_request(OP_CZHUODONG, str(CZ_BOOTSTRAP))

## 领限时大奖。`huodong_id` 是活动 id（服务端只认 `"1"` / `"limit"`），
## `type` 是 `"each"`（每档）或 `"total"`（累计），`gain_id` 是档位下标。
func request_czhuodong_gain(huodong_id: String, type: String, gain_id: int) -> bool:
	var 类型 := type.strip_edges().to_lower()
	if 类型 not in ["each", "total"]:
		return false
	return send_game_request(OP_CZHUODONG, "%d:%s" % [CZ_GAIN_LIMIT, JSON.stringify({
		"huodongId": huodong_id, "type": 类型, "gainId": gain_id,
	})])

## 领新服有礼。`type` 是服务端那两条奖励各自的类型串（大写），`gain_id` 是奖励 id。
func request_czhuodong_gain_xinfu(type: String, gain_id: int) -> bool:
	var 类型 := type.strip_edges().to_upper()
	return not 类型.is_empty() and send_game_request(OP_CZHUODONG, "%d:%s" % [CZ_GAIN_XINFU, JSON.stringify({
		"type": 类型, "gainId": gain_id,
	})])

## 领首杀礼包。原版这条叫 `requestCzHuodong_gainFC`（FC = 首充），报文就是 `common(4, {})`；
## 页面无充值逻辑，2026-10-31 条件改成「击杀一只 BOSS」，函数名跟着改口径，**协议号 4 一个字节没动**。
func request_czhuodong_gain_first_kill() -> bool:
	return send_game_request(OP_CZHUODONG, str(CZ_GAIN_FIRST_KILL))

## 换图走到某个 NPC。`use_bird=true` 走「红色千纸鹤」那条路（原版要求持有道具
## `16000010`，服务端侧会校验副本/战场状态），`auto_talk=true` 表示到了自动对话。
func request_move_to_npc_map(npc_template_id: int, map_id: int, portal_id := 0, use_bird := false, auto_talk := true) -> bool:
	return send_game_request(OP_MOVE_TO_NPC_MAP, "%d:%d:%d:%d:%d" % [
		npc_template_id, map_id, portal_id, int(use_bird), int(auto_talk),
	])

func request_exchange_list(keyword := "") -> bool:
	var clean := keyword.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges().left(40)
	return send_game_request(OP_EXCHANGE, "0" if clean.is_empty() else "1:%s" % clean)

func request_exchange(sn: int) -> bool:
	return sn > 0 and send_game_request(OP_EXCHANGE, "2:%d" % sn)


## 二级密码（2309）的**唯一上行出口**。载荷 = 裸 JSON `{"action":N,"values":[...]}`
## （服务端 `handle_second_level_password:1983-1992` 就 `json.loads` 这一份，不认冒号文本）。
## ⚠ `values` 里**一律按字符串送**：原版 AS3 那十个方法全是 `writeUTF`，服务端
##   `values = [str(v) for v in raw_values]`（`:21992`）也是先转串再比长度 ⇒
##   长度校验（6-14 位）读的是**十进制位数**，送 int 进来必须走同样的转换。
##   这里用 `str()` 不用 `String()`：Godot 4 的 `String(7)` 是**无效构造**（运行期
##   `Invalid call 'String' constructor` ⇒ 整条上行静默不发，页面还照着成功那条腿刷）。
func request_second_password(动作: int, 值: Array = []) -> bool:
	if 动作 < 0 or 动作 > 9:
		return false
	var 串表: Array[String] = []
	for v in 值:
		串表.append(str(v))
	return send_game_request(OP_SECOND_PASSWORD, JSON.stringify({"action": 动作, "values": 串表}))

## 成就福袋（原版 `FudaiProcessor` 的 1/2/3 三支，`SendOpCodes.FUDAI = 1286`）：
##   1 = `requestFudaiOpen(背包格位)`（`:216-222` writeByte(1) + writeInt(position)）
##   2 = `requestFudaiStart()`（`:146-151` 只 writeByte(2)）
##   3 = `requestFudaiGain()`（`:123-128` 只 writeByte(3)）
## ⚠️ 原版**没有 action 0**：上一版这里的 `request_fudai_state()` 发 `"0"` 是自造的，
##    服务端 `handle_fudai` 走到 `if action != 3: return` 静默丢弃 ⇒ 「查询福袋状态」
##    这条永远等不到回帧。上一版把 `"1:%d"` 命名成 `request_fudai_select(槽)` 也是错的：
##    action 1 后面那个 int 是 **writeInt 的背包格位**（和 18 的第二段同源），
##    不是"选第几件候选"—— 福袋选哪件由服务端抽（`randrange(len(candidates))`），
##    客户端只负责开、开始、领三个动作。
func request_fudai_open(背包格位: int) -> bool:
	return 背包格位 >= 1 and send_game_request(OP_FUDAI_REQUEST, "1:%d" % 背包格位)

func request_fudai_start() -> bool:
	return send_game_request(OP_FUDAI_REQUEST, "2")

func request_fudai_gain() -> bool:
	return send_game_request(OP_FUDAI_REQUEST, "3")

## 亲热天堂（小地图「藏宝图」，原版 `FudaiProcessor` 的 17/18/19/20 四支）：
## 17 查询、18 开箱（类型 + 背包格位）、19 开始兑换、20 领取。回包走 `treasure_state_received`。
func request_treasure_show() -> bool:
	return send_game_request(OP_FUDAI_REQUEST, "17")

func request_treasure_open(类型: int, 背包格位: int) -> bool:
	return 类型 >= 2 and 类型 <= 4 and send_game_request(OP_FUDAI_REQUEST, "18:%d:%d" % [类型, 背包格位])

func request_treasure_start() -> bool:
	return send_game_request(OP_FUDAI_REQUEST, "19")

func request_treasure_gain() -> bool:
	return send_game_request(OP_FUDAI_REQUEST, "20")

## 排行榜查询 —— 原版 `PaiHangProcessor.requestPaiHangSearch:19-26`：
## `writeByte(0)` + `writeInt(tabId)` + `writeByte(bool)`，文本化后 = `0:<榜单>:<忍界位>`
## （服务端 `_safe_int` 读第三个字段，所以布尔写 0/1，不写 true/false）。
## ⚠️ 第三个字节原版传的是 **`!renJieBtn.enabled`**（`RankWindow2.requestListData:103-108`），
##   而 `changeTab(p):296-303` 把它设成 `p != 0` ⇒ **忍界榜页(p=0) 发 1、同级榜页(p=1) 发 0**。
##   服务端回帧里那一段叫 `bJiangHu`、客户端却拿它去赋 `rankList.renJieBang`（`setData:364-374`）
##   —— 名字是反的，别照名字推语义，照这两行代码。
## ⚠️ 榜单号**不在这里 clamp**：左侧菜单是从 `Etc.PaiHangBang` 建的（23 条，`menuId 0..22`），
##   clamp 到写死的上界会把以后加榜的那一条静默吃掉；非负闸就够了（`maxi(0, …)`）。
func request_ranking(榜单: int, 忍界榜: bool = true) -> bool:
	return send_game_request(OP_PAI_HANG, "0:%d:%d" % [maxi(0, 榜单), 1 if 忍界榜 else 0])

func request_achievements(tab := 1, begin := 0, end := 19, achievement_type := 0) -> bool:
	return send_game_request(OP_ACHIEVEMENT, "0:%d:%d:%d:%d" % [maxi(1, tab), maxi(0, begin), maxi(begin, end), maxi(0, achievement_type)])

func request_gained_achievements() -> bool:
	return send_game_request(OP_ACHIEVEMENT, "1")

func request_claim_achievement(tab: int, index: int) -> bool:
	return tab > 0 and index > 0 and send_game_request(OP_ACHIEVEMENT, "4:%d:%d" % [tab, index])

func request_use_achievement_title(tab: int, index: int) -> bool:
	return tab > 0 and index > 0 and send_game_request(OP_ACHIEVEMENT, "2:%d:%d" % [tab, index])

func request_hide_achievement_title() -> bool:
	return send_game_request(OP_ACHIEVEMENT, "3")

func request_activity_state() -> bool:
	return send_game_request(OP_ACTIVITY, "0")

func request_activity_claim() -> bool:
	return send_game_request(OP_ACTIVITY, "1")

func request_item_change(action: int, args: Array = []) -> bool:
	# ⚠️ 上界原来写 **28** —— 那是"当时实装到哪儿"的快照，不是协议的上界。
	# 后果：**31（宝石幸运合成）发不出去、函数静默 return false**（2026-10-11 §3.100 实装时
	# 靠在线门"没等到 1042 回包"才逮到）。原版 `ItemChangeProcessor.as` 的动作号到 **39**
	# （`requestTransformCardSpecialSwap`），上界按协议取 39；越界/未实装的由服务端那边
	# `ItemChangeAction(...)` 抛 ValueError 静默丢弃，客户端这层不必重复把关。
	if action < 0 or action > 39:
		return false
	var values := [str(action)]
	for value in args:
		# ⚠️ **布尔发 1/0，不发 "true"/"false"**。原版每条 `ItemChangeProcessor` 的布尔参数
		# 写的都是 `writeByte(bool ? 1 : 0)`（`requestStrengthKunChong:223-227`、
		# `requestStageUp:366-367`、`requestKeYing:549`），而服务端 `fake_flash_server.py:53632`
		# 用 `_safe_int(fields[2])` 读镇灵石那一位 —— 收到 `"true"` 只能退回默认 0，
		# ⇒ **勾了镇灵石等于没勾**（2026-10-17 巡检 #7）。
		values.append(str(1 if value else 0) if value is bool else str(value))
	return send_game_request(OP_ITEM_CHANGE, ":".join(values))

func request_item_misc(action: int, compressed_amf3: PackedByteArray = PackedByteArray()) -> bool:
	if action < 0 or action > 0xffff or compressed_amf3.size() > 4096:
		return false
	var payload := PackedByteArray()
	_append_u16_be(payload, action)
	_append_u16_be(payload, compressed_amf3.size())
	payload.append_array(compressed_amf3)
	return send_game_packet(OP_ITEM_MISC_REQUEST, payload)

func request_zhenqidan_extract_packet(compressed_amf3: PackedByteArray) -> bool:
	return request_item_misc(1, compressed_amf3)

func request_merge_stone(item_position: int) -> bool:
	return request_item_change(0, [item_position])

## 宝石**幸运**合成（`ITEM_CHANGE` 子命令 **31**，原版 `ItemChangeProcessor.requestMergeStoneLucky`
## `:608-615`：`writeByte(31)` + position + `_loc1_`=幸运符张数）。
## ⚠️ 服务端原来**枚举里没有 31**（`ItemChangeAction(31)` 抛 ValueError 被吞 ⇒ 静默无效），
## 2026-10-11 §3.100 才补上 `MERGE_STONE_LUCKY = 31` 与处理器。
func request_merge_stone_lucky(item_position: int, charm_count: int = 0) -> bool:
	return request_item_change(31, [item_position, charm_count])

func request_inlay(equipment_position: int, stone_position: int) -> bool:
	return request_item_change(1, [equipment_position, stone_position])

func request_uninlay(equipment_position: int, inlay_index: int) -> bool:
	return request_item_change(2, [equipment_position, inlay_index])

func request_stage_up(item_position: int, lucky_count: int = 0, keep_strength := false, keep_inlays := false) -> bool:
	return request_item_change(3, [item_position, lucky_count, keep_strength, keep_inlays])

func request_change_aptitude(item_position: int, lucky_count: int = 0) -> bool:
	return request_item_change(4, [item_position, lucky_count])

func request_strength(item_position: int, lucky_count: int = 0) -> bool:
	return request_item_change(5, [item_position, lucky_count])

func request_reset_strength(item_position: int, material_position: int) -> bool:
	return request_item_change(6, [item_position, material_position])

## `ItemChangeProcessor.requestRepairEquip:249-255` = `writeByte(7) + writeInt(repairType)`。
## ⚠️ 那一个 int 是**修理方式**（0 普通 / 1 特殊），**不是格位** —— 这条一次修**身上全部**装备，
## 出处是 NPC 商店的「装备修理」窗 `MendEtcWindow`（巡检 #19：以前当"修某一件"发、
## 还发成了 `NPC_SHOP` 子命令 2 = 商品补货）。
func request_repair_equip(repair_type: int) -> bool:
	return request_item_change(7, [repair_type])

func request_recover_equipment(item_position: int) -> bool:
	return request_item_change(8, [item_position])

func request_bind_item(item_position: int) -> bool:
	return request_item_change(9, [item_position])

func request_merge_jade(item_position: int) -> bool:
	return request_item_change(10, [item_position])

func request_change_jade(item_position: int) -> bool:
	return request_item_change(11, [item_position])

func request_special_stage_up(item_position: int) -> bool:
	return request_item_change(12, [item_position])

func request_jade_inlay(equipment_position: int, jade_position: int) -> bool:
	return request_item_change(13, [equipment_position, jade_position])

func request_jade_uninlay(equipment_position: int, inlay_index: int) -> bool:
	return request_item_change(14, [equipment_position, inlay_index])

func request_wash_born(item_position: int) -> bool:
	return request_item_change(15, [item_position])

func request_carve(item_position: int, confirmed := true) -> bool:
	return request_item_change(16, [item_position, confirmed])

func request_add_plus_count(item_position: int, material_position: int) -> bool:
	return request_item_change(17, [item_position, material_position])

func request_wash_plus_value(item_position: int, mode: int = 0) -> bool:
	return request_item_change(18, [item_position, mode])

func request_select_plus_value(item_position: int, accepted: bool) -> bool:
	return request_item_change(19, [item_position, 1 if accepted else 0])

func request_full_plus_value(item_position: int, material_position: int, attribute_index: int) -> bool:
	return request_item_change(20, [item_position, material_position, attribute_index])

func request_forge_strength(item_position: int) -> bool:
	return request_item_change(21, [item_position])

func request_forge_additive(item_position: int) -> bool:
	return request_item_change(22, [item_position])

func request_change_to_orange(item_position: int) -> bool:
	return request_item_change(23, [item_position])

func request_change_tale_attribute(item_position: int) -> bool:
	return request_item_change(24, [item_position])

## 昆虫（寄坏虫）强化。`ITEM_CHANGE` 动作 **25**，三个字段逐条照原版
## `ItemChangeProcessor.requestStrengthKunChong:221-230`：
##   `writeByte(25); writeInt(position); writeInt(用镇灵石?1:0); writeInt(寄坏玉张数)`
## ⚠️ 参数名原来写的是 `automatic / material_position` —— **两个都错**（名字影响不到协议，
##    但会让人以为"自动强化"和"材料格"是这两个字段）。服务端读的是
##    `fields[2]=use_guarantee` / `fields[3]=help_count`（`_strengthen_kun_chong`）。
func request_strength_kunchong(item_position: int, use_guarantee := false, help_count := 0) -> bool:
	return request_item_change(25, [item_position, use_guarantee, maxi(0, help_count)])

func request_merge_badge_stone(item_position: int) -> bool:
	return request_item_change(26, [item_position])

func request_stage_up_badge(item_position: int) -> bool:
	return request_item_change(27, [item_position])

func request_stage_up_120(item_position: int, material_position: int) -> bool:
	return request_item_change(28, [item_position, material_position])

## **选中**某个玩家 ⇒ 只要顶栏那条血蓝。原版
## `AllInOneProcessor.as:1133-1139 requestTargetCharacterInfo` 往包里写的字节是 **4**，
## 服务端回的是 `TARGET_INFO(1284)`（`Client.onTargetInfo():6966-6977` 喂信息条）。
func request_character_info(target_id: int) -> bool:
	return send_game_request(OP_CHARACTER_INFO, "4:%d" % target_id)

## **选中怪那一跳**的目标信息上行。原版
## `TargetHandler.as:279-282` `API.client.requestTargetMonsterInfo(param1.objectId)`
## → `Client.as:2019-2024` → `AllInOneProcessor.as:1431-1437`：同一个 `CHAR_INFO_REQUEST(94)` 上
## `writeByte(3) + writeInt(objectId)`（与玩家那发 `:4` 只差一个字节）。服务端 `:20247-20253`
## 的 `action == 3` 拿**怪的服务端 object_id** 回 `TARGET_INFO(1284)` 的怪档。
## 调用点只有一个：`地图实体.显示目标框()`（= 原版 viewTarget setter 的对照物，点怪与挂机共用）。
func request_target_monster_info(monster_object_id: int) -> bool:
	return monster_object_id > 0 and send_game_request(OP_CHARACTER_INFO, "3:%d" % monster_object_id)

## 点顶栏「查看信息」⇒ 要开的是**对方那扇「人物属性」窗** ⇒ 要的是完整的 `CharacterFullInfo`。
## 原版 `UI.as:674-677 clickCharacter()` → `Client.as:4310-4314 requestCharFullInfo()` →
## `AllInOneProcessor.as:3430-3436` 往包里写的字节是 **0**（⚠ 不是 4 —— 两发的字节只差一位，
## 弄混的后果是"点谁谁开窗"或"点了不开窗"，10-15 就是这么绕了一圈）。
func request_char_full_info(target_id: int) -> bool:
	return send_game_request(OP_CHARACTER_INFO, "0:%d" % target_id)

## 菜单「赠花」那一行 ⇒ 查**对面**的花档（`真值/窗口/赠花窗.md` §②）。
## 原版 `MarryTableManager.openMarryZengHuaWindow:184-197` 先存那四个"对面是谁"，再
## `requestFlowerWindowInfo` → `Client.as:4374-4380` → `AllInOneProcessor.as:3691-3697`
## 往包里写的字节是 **6**（同一号 94 上第 0/4/6 三支只差一位，混了就点谁都不开窗）。
## ⚠ 0 号不发：服务端 `_character_info_session:20254-20262` 把 `0` 当**我自己** ⇒
## 发出去会得到一扇"对着自己送花"的窗（帧发得出去、屏上没错号，只有这一闸能挡住）。
func request_flower_info(target_id: int) -> bool:
	return target_id > 0 and send_game_request(OP_CHARACTER_INFO, "6:%d" % target_id)

## 送花：`127:39:<对面号>:<朵>` —— 原版 `FriendProcessor.as:541-548` 是 `writeByte(39)`
## 加**两个 `writeInt`**（少一位服务端解不出来，`if action == 39 and len(fields) >= 3` 那一支直接不认）。
## 朵数只能是档位表里那三档（`FLOWER_GIFT_OPTIONS:512-515` = 1 / 20 / 99），别的数字
## 服务端回一句「赠花选项或目标无效。」⇒ 这里只闸 0，档位交给窗里那三颗钮（数据帧给的）。
func request_send_flower(target_id: int, flower_count: int) -> bool:
	return target_id > 0 and flower_count > 0 \
			and send_game_request(OP_FRIEND_REQUEST, "39:%d:%d" % [target_id, flower_count])

## —— 改名族三条上行（`CHANGE_NAMES 2330`，包体第一段 = 原版的 action 字节）————
## 原版 `AllInOneProcessor.as:99-105`：`writeByte(1)` + `writeUTF(新名)`。
## 服务端 `handle_change_name:33190-33219` 会**扣一张改名卡**（`16000180`）再回 `2330:0:<新名>`。
## ⚠ 客户端自己也要先拦三道（原版 `ChangeNameWindow.onConfirmClick:310-329`）：
##    空名 / 长度不在 2~12 / 改名卡数为 0 —— 三道都不许把包发出去。
func request_change_name(新名: String) -> bool:
	return send_game_request(OP_CHANGE_NAMES, "1:%s" % 新名)

## 原版 `:107-112`（开自己那扇「角色改名」窗时 `refreshData()` 就发这一发）。
func request_history_names() -> bool:
	return send_game_request(OP_CHANGE_NAMES, "10")

## 原版 `:114-120`：`writeByte(12)` + `writeUTF(名字)` —— **按名字查，不是按角色号**。
## 入口是**别人**那扇人物窗名字右边那颗「改」（`CharPane.as:321-331`：`_isMyself` 假 ⇒ 走这一发）。
func request_other_history_names(名: String) -> bool:
	if 名.is_empty():
		return false
	return send_game_request(OP_CHANGE_NAMES, "12:%s" % 名)

## 目标信息条那排钮要发的三条（`真值/窗口/目标信息条.md` §④⑤）。
## ⚠ 包体**第一段就是原版的 action 字节**，不带 opcode 前缀 ——
## 服务端 `_request_fields`（`fake_flash_server.py:57728`）只在 `fields[0] == str(opcode)`
## 时才剥头一段，所以 `"2:1001"` 交给 119 时它读到的正是 `action=2, target=1001`。

## 玩家间互动（交易状态机）。原版 `DetailsWindow._trade():466-471` 发 action 2 = 交易邀请；
## 服务端 `handle_player_interaction` 成功时给对方 `119:3:<我的号>:<我的名>`、给我一条系统提示。
func request_trade_invite(target_id: int) -> bool:
	return target_id > 0 and send_game_request(OP_PLAYER_INTERACTION, "2:%d" % target_id)

## 看别人的摊：`UI.viewStall():216-220` → `StallProcessor.requestStallOpen`
## （`StallProcessor.as:262-268` `writeInt(2)` + `writeInt(摊主号)`）。
func request_stall_open(owner_id: int) -> bool:
	return owner_id > 0 and send_game_request(OP_STALL_ACTION, "2:%d" % owner_id)

## 翻摊位列表：`StallProcessor.requestStallList(startIndex, endIndex)`
## （`StallProcessor.as:128-135`：`writeInt(0)` + 两个 `writeInt`）⇒ `1296:0:<起>:<止>`。
## 止 = 起 + 11（`StallListWindow.as:40 _pageSize = 11`，`loadPage:139-149` 算的就是这对）。
func request_stall_list(起始: int, 止: int) -> bool:
	return 起始 >= 0 and 止 > 起始 and send_game_request(OP_STALL_ACTION, "0:%d:%d" % [起始, 止])

## 按关键字搜摊位：`requestStallSearch(quickKey, searchKey, startIndex, endIndex)`
## （`StallProcessor.as:251-260`：`writeInt(1)` + int + **UTF** + int + int）⇒ `1296:1:<类>:<词>:<起>:<止>`。
## ⚠ 这个 **1 是上行动作号**；下行 `1296:1:` 是"某摊位的那一摊货"，同号不同义（同交易族
## 上行 119／下行 335 那对反例），别把两条并成一个函数。
## ⚠ 词里的三个分隔符必须换掉：文本帧按 `:` 分段、行表按 `@`／`&` 分格，留着它们
## 等于把一帧劈成两半（服务端 `handle_stall_action` 也是这么洗摊名的，`:25489`）。
func request_stall_search(类: int, 词: String, 起始: int, 止: int) -> bool:
	var 干净 := 词.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges()
	if 干净 == "" or 起始 < 0 or 止 <= 起始:
		return false
	return send_game_request(OP_STALL_ACTION, "1:%d:%s:%d:%d" % [类, 干净, 起始, 止])

## 买一件：`1296:7:<卖家号>:<卖家名>:<挂牌uid>`（服务端 `handle_stall_action` action 7，
## `fake_flash_server.py:25590-25598`）。⚠ **卖家名要一字不差** —— 服务端先按号找人，
## 号对不上名字时它会退到"按名字找"，两个都不对就直接什么都不回（现象：点了购买没反应）。
func request_stall_buy(seller_id: int, seller_name: String, listing_uid: int) -> bool:
	if seller_id <= 0 or listing_uid <= 0 or seller_name.is_empty():
		return false
	var 干净 := seller_name.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges()
	return 干净 != "" and send_game_request(OP_STALL_ACTION, "7:%d:%s:%d" % [seller_id, 干净, listing_uid])

## 摊主上架一件物品：`requestStallAddItemToStall(category, position, count, gold, yb)`
## （`StallProcessor.as:28-38`：`writeInt(4)` + `writeByte` + **两个 `writeShort`** + 两个 `writeInt`）
## ⇒ `1296:4:<类型>:<背包格>:<数量>:<金币价>:<元宝价>`。
## ⚠ 前四段在原版是 **byte/short**（上限 255／32767）、后两段才是 int ⇒ 文本桥把它们写成一样宽，
## 越界的格号／数量服务端不报错、只会按它自己的字典去找那一格（找不到就整条静默丢掉）。
## ⚠ 数量给 **0 会被服务端抬成 1**（`fake_flash_server.py:25496 max(1, …)`）⇒ 这里自己拦：
## 抬成 1 等于"玩家想卖整摞、结果只挂一件"，那种悄悄改了语义的事不能放行。
func request_stall_add_item(类型: int, 背包格: int, 数量: int, 金币: int, 元宝: int) -> bool:
	if 背包格 <= 0 or 数量 < 1 or 金币 < 0 or 元宝 < 0:
		return false
	return send_game_request(OP_STALL_ACTION, "4:%d:%d:%d:%d:%d" % [类型, 背包格, 数量, 金币, 元宝])

## 摊主下架一件：`1296:6:<挂牌uid>`（`requestStallRemoveFromStall:20-26`，`writeInt(6)` + `writeInt`）。
## ⚠ **不带摊主号**：服务端只认"发这一跳的那个人自己那一摊"（action 6 先 `open_stall(self)` 再按 uid 摘）。
func request_stall_remove_item(uid: int) -> bool:
	return uid > 0 and send_game_request(OP_STALL_ACTION, "6:%d" % uid)

## 改摊名：`1296:3:<角色号>:<摊名>`（`requestStallRename:270-277`，`writeInt(3)` + `writeInt` + `writeUTF`）。
## ⚠ 摊名**不预先洗半角冒号**：服务端 `:25489` 是 `":".join(fields[2:])[:30].replace(":", "：")`
## —— 名字里带 `:` 会被它自己折成全角，客户端先换掉的话，15 字那道闸就会算错一位。
## ⚠ 但 `@`／`&` **必须**换掉：那两个是文本桥的行／格分隔符，留着等于把一帧劈成两半。
func request_stall_rename(角色号: int, 摊名: String) -> bool:
	if 角色号 <= 0 or 摊名.is_empty():
		return false
	var 干净 := 摊名.replace("@", " ").replace("&", " ")
	return 干净.strip_edges() != "" and send_game_request(OP_STALL_ACTION, "3:%d:%s" % [角色号, 干净])

## 摊主上架一只通灵兽：`requestStallAddPetToStall(uid, gold, yb)`
## （`StallProcessor.as:210-228`：`writeInt(5)` + `writeDouble(uid)` + 两个 `writeInt`）
## ⇒ `1296:5:<唯一号>:<金币价>:<元宝价>`。
## ⚠ uid 在原版是 **double**（`writeDouble`）；文本桥统一写整数，服务端按 int 收即可
## （唯一号永远在 2^53 以内，double 与 int 在这里同值）。
## 两价都是 0 不发：服务端 `:26305` 会回「出售价格不能为零。」，本地先挡少一个来回。
func request_stall_add_pet(uid: int, 金币: int, 元宝: int) -> bool:
	if uid <= 0 or 金币 < 0 or 元宝 < 0 or (金币 == 0 and 元宝 == 0):
		return false
	return send_game_request(OP_STALL_ACTION, "5:%d:%d:%d" % [uid, 金币, 元宝])

## 摊主上架一笔货币：`requestStallAddMoneyToStall(isGold, gold, yb)`
## （`StallProcessor.as:210-228` 的 action 8 那支：`writeInt(8)` + `writeByte` + 两个 `writeInt`）
## ⇒ `1296:8:<是否金币>:<金币数>:<元宝数>`。
## ⚠ 别把两枚数目按"先金币后元宝"硬解：原版 `UpShelfMoneyWindow.onClickUpshelfBtn` 传的是
## `isJingBi ? count : prize` / `isJingBi ? prize : count` —— 卖金币时第二段是**要价个数**，
## 卖元宝时第三段才是。服务端 `:26345` 自己再按 `is_gold` 拆，客户端照原版这两句摆即可。
## 两个数都 0 不发（服务端 `:26349` 回「出售数量和价格必须大于零。」）。
func request_stall_add_money(is_gold: bool, 金币: int, 元宝: int) -> bool:
	if 金币 < 0 or 元宝 < 0 or (金币 == 0 and 元宝 == 0):
		return false
	return send_game_request(OP_STALL_ACTION, "8:%d:%d:%d" % [1 if is_gold else 0, 金币, 元宝])

## 摊位族下行 `1296:2:` = **单条挂牌**增量（服务端 `_stall_listing_payload:25720-25743`，mode 传 2）：
##   `1296:2:<uid>:<摊主号>:<类型>:<积分价>:<现金价>:<编码负载>`。
## ⚠ 负载里的分隔符这一支是 `@`，**不是** `1296:1:` 那一支的 `!`
## （`_stall_listing_payload` 用 `replace("&", "@")`、`_send_stall` 用 `replace("&", "!")`）
## ⇒ 还原各按各的那一枚换回去，别共用一个反解函数（这是本帧族最容易顺手写错的一处）。
## 原版 `handleStallAction_addItem:40-57` 解成一条 `StallItemInfo` 后交
## `StallDataManager.onStallAddItem:80-86` —— **只塞摊主自己那扇**，买家那扇不更新。
## `authoritative_stall` 这一侧同步补一行：页面重灌走的是它，不补的话下一次重灌会把刚挂上的那条弄丢。
func _handle_stall_listing(fields: PackedStringArray) -> void:
	if fields.size() < 8:
		return
	var 行 := {
		"uid": int(fields[2]), "owner_id": int(fields[3]), "kind": int(fields[4]),
		"point_price": int(fields[5]), "cash_price": int(fields[6]),
		"payload": String(fields[7]).replace("@", "&"),
	}
	if not authoritative_stall.is_empty() \
			and int(authoritative_stall.get("owner_id", 0)) == int(行["owner_id"]):
		var 列: Array = authoritative_stall.get("listings", []) as Array
		列.append(行)
		authoritative_stall["listings"] = 列
	stall_listing_added.emit(行)

## 下行 `1296:3:<摊主号>:<uid>` = 摘掉一条挂牌（`handleStallAction_removeItem:230-249`）。
## 原版 `onStallRemoveItem:65-78` 按摊主号分流：是自己 ⇒ `myStallWindow.downShelf`，
## 是别人 ⇒ `stallWindow.downShelf`（**买家那扇也要摘**，摊主下架的东西从人家视野里消失）。
## 服务端 `:25583` 那句 `if listing is not None and self._return_stall_listing(listing)` ⇒
## **背包放不下时它一条都不回**（只发一句「背包空间不足」），所以摘行只发生在收到这一帧的时候。
func _handle_stall_removed(fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	var 号 := int(fields[2])
	var 页 := int(fields[3])
	if not authoritative_stall.is_empty() and int(authoritative_stall.get("owner_id", 0)) == 号:
		var 列: Array = authoritative_stall.get("listings", []) as Array
		var 留: Array = []
		for 旧 in 列:
			if int((旧 as Dictionary).get("uid", -1)) != 页:
				留.append(旧)
		authoritative_stall["listings"] = 留
	stall_listing_removed.emit(号, 页)

## 下行 `1296:4:<买家名>:<物品名>:<金币>:<元宝>` = 摊主的一条出售记录（`handleStallAction_addLog`）。
## ⚠ 本函数**不碰 `authoritative_stall.logs`**：原版 `StallDataManager.onStallItemList:27-39`
## 把服务端给的 `param5`（日志段）**整段丢掉了**，屏幕上那串只由 `4:` 帧累积
## （`onStallTeadeLog:41-63` 往单例的 `stallLogs` 上追一行）。照它 ⇒ 累积那本账在 `摊位窗`，不在这里。
func _handle_stall_sale_log(fields: PackedStringArray) -> void:
	if fields.size() < 6:
		return
	stall_sale_log.emit(String(fields[2]), String(fields[3]), int(fields[4]), int(fields[5]))

## 摊位族（`STALL_ACTION 1296`）下行按**第二段动作号**分流，照 `StallProcessor.handlePetAction:106-126`
## 的 `switch (action)`：`0` = 列表帧、`1` = 某一摊的货、`2` = 加一条挂牌、`3` = 摘一条、`4` = 一条出售记录。
## ⚠ 上行的 1 是「搜索」（`requestStallSearch`），下行的 1 是「摊位内容」—— 同号不同义，
## 别并成一个函数（同交易族上行 119／下行 335 那对反例）。
## ⚠ 反过来，上行的 `5/6/7/8`（宠物上架／下架／购买／货币上架）**在下行没有对应支**
## —— 原版 switch 到 4 就到底了，别照上行补出对称的四条来。
## 认不出的动作号整条丢掉：凑半条会把别人的挂牌挂到本摊上。
func _handle_stall_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	match int(fields[1]):
		0: _handle_stall_list(fields)
		1: _handle_stall_content(fields)
		2: _handle_stall_listing(fields)
		3: _handle_stall_removed(fields)
		4: _handle_stall_sale_log(fields)

## 摊位列表回帧。形状（服务端 `handle_stall_action` action 0/1 那一支，`fake_flash_server.py:25432-25455`）：
##   `1296:0:<总数>:<行表>`，空表那格是 `-`；
##   一行 = `摊名&摊主号&摊主名&等级&物品数&宠物数&货币数`（`StallInfo.as:28-37` 的 readUTF/int 顺序）。
## ⚠ **摊名从右往左数出来**，不是从左：服务端拼串时没转义 `&`（`:25489` 只洗 `:`），
## 名字里带 `&` 的那一行按左数会把「等级」读成名字的第二段。原版走 `readUTF` 无此患，文本帧只能这么补。
## `总数` 是**匹配总数**（`len(matching_stalls)`），不是本页条数 —— 原版用它算页数，照它。
func _handle_stall_list(fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	var 行表: Array = []
	var 原文 := String(fields[3])
	if 原文 != "-":
		for 行 in 原文.split("@"):
			var 段: PackedStringArray = 行.split("&")
			if 段.size() < 7:
				continue
			## 尾部 6 段是数字，前面剩下的全属于摊名（正常摊名只有一段，多余段就是被 `&` 劈开的原名）。
			var 尾 := 段.size() - 6
			行表.append({
				"stall_name": "&".join(段.slice(0, 尾)),
				"payer_id": int(段[尾]), "player_name": String(段[尾 + 1]),
				"player_level": int(段[尾 + 2]), "itemnum": int(段[尾 + 3]),
				"petnum": int(段[尾 + 4]), "moneynum": int(段[尾 + 5]),
			})
	stall_list_received.emit(int(fields[2]), 行表)

## 摊位内容回帧。形状（服务端 `_send_stall:25777-25811`）：
##   `1296:1:<摊主号>:<摊主名>:<摊名>:<行表>@<行表>…:<日志>`，空表那格是 `-`；
##   一行 = `uid&摊主号&类型&积分价&现金价&编码负载`，**负载里的 `&` 被换成 `!`**（防串味）。
## 段数不够（老端/噪声）整条丢掉。
func _handle_stall_content(fields: PackedStringArray) -> void:
	if fields.size() < 6:
		return
	var 行表: Array = []
	var 原文 := String(fields[5])
	if 原文 != "-":
		for 行 in 原文.split("@"):
			var 段: PackedStringArray = 行.split("&", true, 5)
			if 段.size() < 6:
				continue
			行表.append({
				"uid": int(段[0]), "owner_id": int(段[1]), "kind": int(段[2]),
				"point_price": int(段[3]), "cash_price": int(段[4]),
				## 负载原样留在这儿，`!` 还原成 `&` 之后交给物品解码那一族（解码口径不在本文件猜）
				"payload": String(段[5]).replace("!", "&"),
			})
	var 状 := {
		"owner_id": int(fields[2]), "owner_name": String(fields[3]),
		"stall_name": String(fields[4]), "listings": 行表,
		"logs": (String(fields[6]) if fields.size() > 6 else "-"),
	}
	authoritative_stall = 状
	stall_state_received.emit(状.duplicate(true))

## 木叶大战下行 `2323:8:<积分>` —— 荣誉页唯一消费的一条。
##
## ⚠ **动作 0..11 里只有 8 与商城这扇窗有关**，其余全属于战场面板/名单/倒计时那一族
## （`MuYeDaZhanManager.onMuyeBattle_*`）。这里把它们当**合法的空动作**收下、不告警：
## 3 线登录本来就会白收一条 `2323:0:0:1800`（服务端 `:14241`），一告警就是每次上线刷一行噪声。
## ⚠ 也别"顺手"把 1（面板）里的 personal_points 当积分写：原版 `action_showPanel` 送的是
## `onMuyeBattle_showPanel(5 个参数)`，`MuYeDaZhanManager` 里**没有**往 `famePoint` 赋值的分支
## —— 写进去就等于造一条原版没有的显示口径（战场内外积分语义不同）。
## 段数不够（老端/噪声）整条丢掉，等价于 `action_updateFamePoint` 的 `catch → reportDecodingError → return`。
func _handle_muye_battle_text(fields: PackedStringArray) -> void:
	if fields.size() < 3 or int(fields[1]) != 8 or not String(fields[2]).is_valid_int():
		return
	var 积分 := int(fields[2])
	authoritative_muye_battle["fame_point"] = 积分
	荣誉积分帧.emit(积分)

## 兑换一件荣誉商品：`2323:3:<物品id>:<数量>`
## （`MuyeBattleProcessor.requestPrize:38-45`：`writeByte(3)` + `writeInt` + `writeInt`）。
## 原版荣誉格的点击**恒传数量 1**（`RongYuItemCell` 的点击回调 `requestPrize(int(data.itemId), 1)`），
## 这半边不提供"自选数量"的入口 —— 那是偏离，不是补全。
## ⚠ 发完**不做任何本地成功动作**：服务端三条出口（积分不足/背包满/成功）都只回 `2323:8:`，
## 加物品走另一条库存帧 ⇒ 客户端能做的只有等帧。
## id ≤ 0 时不发：服务端 `muye_battle_shop().get(item_id, 0)` 拿不到价也照样回一帧 `2323:8:<当前积分>`，
## 表现是"点了没反应"，不如在客户端就拦住。
func request_muye_prize(物品id: int, 数量: int = 1) -> bool:
	if 物品id <= 0 or 数量 <= 0:
		return false
	return send_game_request(OP_MUYE_BATTLE, "3:%d:%d" % [物品id, 数量])

## 一个空交易状态。`removeData()` 的等价物（`TradeWindow2.as:270-292`）：
## 十个格清空 + 两遮罩隐 + 交易钮 disable + **四个金额写回 0**。
static func _空交易状态() -> Dictionary:
	return {
		"active": false, "other_id": 0, "other_name": "",
		"my_money": 0, "other_money": 0, "my_cash": 0, "other_cash": 0,
		"my_items": {}, "other_items": {},
		"my_pet": {}, "other_pet": {},
		"my_locked": false, "other_locked": false,
	}

## 交易族下行（335）。分发照 `TradeProcessor.handlePlayerInteractionPacket:142-224`；
## **槽位含义**照 `Client.as`：`param1 == 0 ⇒ 我这侧`（物品 `:1683-1697`、宠物 `:1737-1751`、
## 金币 `:2321-2326`、元宝 `:1438-1443`）。段序一律反查服务端拼串
## （`_broadcast_trade_snapshot:23753-23787`、`handle_player_interaction:23789-23955`），
## 不许照原版二进制 `readByte/readInt` 猜文本通道的段数。
## 段不够 ⇒ 整条丢掉（凑半条会把别人的出价算到我头上）。
func _handle_trade_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var 子命令 := int(fields[1])
	if 子命令 == 3:
		# 邀请：只往托盘塞一格，**不开窗**（`Client.as:6391-6398`）
		if fields.size() < 4:
			return
		trade_invite_received.emit({"id": int(fields[2]), "name": String(fields[3])})
		return
	if 子命令 == 22:
		if fields.size() < 8:
			return
		# `22:0:<我号>:<我名>:1:<他号>:<他名>` —— 每端收到的都是"自己那一份在前"，
		# 但仍按 playerSlot 判，别按位置硬取（`Client.onTradeStart:853-873` 用的就是 playerSlot）
		var 我在前 := int(fields[2]) == 0
		var 新 := _空交易状态()
		新["active"] = true
		新["other_id"] = int(fields[6] if 我在前 else fields[3])
		新["other_name"] = String(fields[7] if 我在前 else fields[4])
		authoritative_trade = 新
		trade_started.emit(新.duplicate(true))
		return
	if 子命令 == 7:
		# 双方都锁定（服务端只在 `locked == {first, second}` 时发，`:23936-23941`）
		authoritative_trade["my_locked"] = true
		authoritative_trade["other_locked"] = true
		trade_updated.emit(authoritative_trade.duplicate(true))
		return
	if 子命令 == 8:
		authoritative_trade = _空交易状态()
		trade_closed.emit("成交")
		return
	if 子命令 == 9:
		authoritative_trade = _空交易状态()
		trade_closed.emit("取消")
		return
	if 子命令 == 11:
		# ⚠ 原版这条是**死处理**：`Client.onTradePetRemove:7073-7076` 只 debugTrace、不动格。
		# 照搬 ⇒ 宠物取回后交易窗仍显示它（`119:19` 没有 UI 入口，实际走不到这一步）。
		return
	if 子命令 == 4 or 子命令 == 6:
		# ⚠ 判的是 `fields[3]` 存不存在 ⇒ 门槛必须是 `< 4`（写 `< 3` 时一条
		# `335:4:0`（少一段）会走到取 `fields[3]` 那一句，运行期越界报错）。
		if fields.size() < 4:
			return
		var 是他的 := int(fields[2]) != 0
		var 数 := maxi(0, int(fields[3]))
		if 子命令 == 4:
			authoritative_trade["other_money" if 是他的 else "my_money"] = 数
		else:
			authoritative_trade["other_cash" if 是他的 else "my_cash"] = 数
		trade_updated.emit(authoritative_trade.duplicate(true))
		return
	if 子命令 == 5 or 子命令 == 21:
		if fields.size() < 4:
			return
		var 件 := _parse_item_entry(String(fields[3]))
		if 件.is_empty():
			return
		# 键 = **交易槽**（服务端 `:23774-23776` 把负载里的 slot 换成了交易槽）
		var 槽 := int(件.get("slot_index", 0))
		if 槽 < 1 or 槽 > 5:
			return
		var 表名 := "other_items" if int(fields[2]) != 0 else "my_items"
		var 格表: Dictionary = authoritative_trade[表名]
		if 子命令 == 5:
			格表[槽] = 件
		else:
			格表.erase(槽)
		trade_updated.emit(authoritative_trade.duplicate(true))
		return
	if 子命令 == 10:
		if fields.size() < 4:
			return
		var 宠 := _parse_pet_fields(String(fields[3]).split("&", true), 0)
		if 宠.is_empty():
			return
		authoritative_trade["other_pet" if int(fields[2]) != 0 else "my_pet"] = 宠
		trade_updated.emit(authoritative_trade.duplicate(true))
		return

## 交易族上行。动作号 = `PlayerAction.as:6-32`，拼法 = `TradeProcessor.as` + `PacketCreator.as`。
## ⚠ 包体第一段就是动作字节（服务端 `_request_fields` 只在 `fields[0] == "119"` 时才剥头一段）。
## 除 `邀请/婉拒/接受` 三条外都要求**已在交易态**——服务端 `:23838-23840` 找不到交易也是直接 return，
## 在这里挡一次，省得 UI 点空了还往外发帧。
func _request_trade_action(内容: String, 需要在场 := true) -> bool:
	if 需要在场 and not bool(authoritative_trade.get("active", false)):
		return false
	return send_game_request(OP_PLAYER_INTERACTION, 内容)

## 婉拒邀请（DECLINE=3，`TradeProcessor.as:544-550`）。服务端拿这条会向双方发 `335:9:0`。
func request_trade_decline(target_id: int) -> bool:
	return target_id > 0 and send_game_request(OP_PLAYER_INTERACTION, "3:%d" % target_id)

## 接受邀请（VISIT=4，`:394-400`）⇒ 服务端给双方各发一条 `335:22` 并推快照。
func request_trade_accept(target_id: int) -> bool:
	return target_id > 0 and send_game_request(OP_PLAYER_INTERACTION, "4:%d" % target_id)

## 锁定我这堆（LOCK=9，`PacketCreator.as:551-556`）。
## ⚠ 服务端 `:23933-23935` 是**同步**把 `character_id` 加进 `trade.locked` 的（`335:7` 只在
## 两人都锁完才发）⇒ "我已经锁了"这一条客户端当场就知道。这里跟着写进状态，
## 否则下一次快照重灌会把我自己那半红遮罩又画回"没锁"（原版的半遮罩是点下去立刻上的）。
func request_trade_lock() -> bool:
	if not _request_trade_action("9"):
		return false
	authoritative_trade["my_locked"] = true
	return true

## 退出/取消交易（EXIT=10，`:809-814`）。关闭钮与「取消」钮都发这一条（`TradeWindow2.as:123-129,316-319`）。
func request_trade_exit() -> bool:
	return _request_trade_action("10")

## 确认成交（CONFIRM=16，`:509-514`）。服务端要求**双方都已锁定**才受理（`:23942`）。
func request_trade_confirm() -> bool:
	return _request_trade_action("16")

## 出价金币（SET_COCONUTS=15，`:455-461`）/ 出价元宝（SET_CASH=13，`:938-944`）。
## ⚠ 别把两条搞反：**金币 = `offered_money` = 15**、**元宝 = `offered_cash_money` = 13**。
func request_trade_offer_money(数量: int) -> bool:
	return 数量 >= 0 and _request_trade_action("15:%d" % 数量)

func request_trade_offer_cash(数量: int) -> bool:
	return 数量 >= 0 and _request_trade_action("13:%d" % 数量)

## 放物品进交易格（SET_ITEMS=14，`TradeProcessor.as:79-86`：byte + writeInt(背包槽) + writeInt(交易槽)）。
## 交易槽 **必须 1..5** —— 服务端 `:23873` 对其它值直接丢帧。
func request_trade_put_item(背包槽: int, 交易槽: int) -> bool:
	if 背包槽 <= 0 or 交易槽 < 1 or 交易槽 > 5:
		return false
	return _request_trade_action("14:%d:%d" % [背包槽, 交易槽])

## 取回物品（TAKE_ITEM_BACK_TRADE=17，`:402-408`）。
## ⚠ 原版**没有可用的 UI 入口**（`UI.onTradeDragItem:501-504` 从未 addEventListener，
## 背包接 `DragManager.TRADE_WINDOW` 那支 `ItemWindow2.as:1712-1716` 只清拖拽不发帧）
## ⇒ 本方法先备着，不在界面上造入口（造了就是自造交互）。
func request_trade_take_item(交易槽: int) -> bool:
	if 交易槽 < 1 or 交易槽 > 5:
		return false
	return _request_trade_action("17:%d" % 交易槽)

## 第一个空的交易槽（1..5）。原版「物品上架」模式发的 `dst=0`（`ItemWindow2.as:458-465`）
## 在本机服务端会被丢（见上一函数的行号），所以由客户端算出真实槽号再发。
func 交易空格() -> int:
	for 槽 in range(1, 6):
		if not (authoritative_trade.get("my_items", {}) as Dictionary).has(槽):
			return 槽
	return 0

## 把一只通灵兽放进交易（SET_PET=18）：`TradeProcessor.as:133-139`
## `writeByte(18)` + `writeDouble(唯一号)` + `writeInt(1)` ⇒ `119:18:<唯一号>:1`。
## 入口 = 交易窗「宠物列表」那颗钮开的 `SuiShenPet` 选完点上架（`UI.as:1761-1767 setTradePet`，
## `myType == JIAOYI_TYPE` 才发）；服务端 `:24671-24683` 只收未锁定、可交易且**在宠物栏**的那只。
## 第二段那个 1 服务端不读（原版 `Client.requestSetTradePet(param2)` 唯一调用点写死 1）。
func request_trade_set_pet(uid: int, flag := 1) -> bool:
	return uid > 0 and _request_trade_action("18:%d:%d" % [uid, flag])

## 师徒：`TutorProcessor.as:222-228` 拜师 = action 3、`:246-252` 收徒 = action 4，都跟一个角色号。
func request_tutor_apply(action: int, target_id: int) -> bool:
	return target_id > 0 and send_game_request(OP_TUTOR, "%d:%d" % [action, target_id])


## 申请窗那两颗钮：`TutorProcessor.as:261-267` 同意拜师 = 7、`:30-36` 同意收徒 = 8；
## `:22-28` 拒绝拜师 = 5、`:230-236` 拒绝收徒 = 6。原版分四个函数，本工程按"档 + 号"两参收敛
## （档 = `AgreestToturWindow.TYPE_PRENTICE(1)` / `TYPE_TEACHER(2)`，与下行 4/5 同一套）。
func request_tutor_accept(档: int, target_id: int) -> bool:
	return 档 in [1, 2] and target_id > 0 \
			and send_game_request(OP_TUTOR, "%d:%d" % [7 if 档 == 1 else 8, target_id])


func request_tutor_refuse(档: int, target_id: int) -> bool:
	return 档 in [1, 2] and target_id > 0 \
			and send_game_request(OP_TUTOR, "%d:%d" % [5 if 档 == 1 else 6, target_id])


## 一行推荐候选 = `名&号&脸&等级&职业`（服务端 `_tutor_recommended_row:22444-22458`，
## 第 5 段是 10-15 补的 —— 行件要写「等级+职业名」）。段数不够就**整行丢**，
## 凑半行会把别人的名字配到另一个人的脸上。
static func _解师徒行(原文: String) -> Array:
	var 行们: Array = []
	if 原文 == "-" or 原文.is_empty():
		return 行们
	for 一 in 原文.split("@"):
		var 段 := 一.split("&")
		if 段.size() < 5:
			continue
		行们.append({"name": String(段[0]), "charId": int(段[1]), "face": int(段[2]),
				"level": int(段[3]), "job": int(段[4])})
	return 行们


## 下行 `77`。分发表在 `TutorProcessor.handleTutorListPacket():110-205`。
## 本机服务端只发 4/5/14/15/17/18 这几条（其余 action 是"我发出去"的那一族的回执，
## 原版对应处理者要么是空函数、要么这一版没接），所以**不在表里的一律静默丢**。
func _handle_tutor_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		return
	var 子 := int(fields[1])
	if 子 == 17 or 子 == 18:
		# `77:17:<行>@…:<在线数>` / `77:18:<行>@…:<候选数>`
		# （服务端 `_send_tutor_recommendations:22460-22477`；没候选时它回 `77:<档>:-:0`）
		if fields.size() < 4:
			return
		var 行们 := _解师徒行(String(fields[2]))
		var 后缀 := int(fields[3])
		if 行们.is_empty():
			## 原版这里照样会往托盘塞一格（`Client.as:6715-6720` 不看内容），
			## 但点开就是 `getItemAt(0).charId` 抛异常 ⇒ 空表**不塞格**，
			## 这条偏离记在 `真值/窗口/师徒推荐窗.md` §⑤。
			return
		if 子 == 17:
			tutor_recommended.emit(10, {"tutors": 行们, "online": 后缀})
		else:
			tutor_recommended.emit(9, {"students": 行们, "count": 后缀})
		return
	if 子 == 4 or 子 == 5:
		# `77:4:<学生号>:<学生名>` = 有人请求拜我为师（档 1）；
		# `77:5:<师父号>:<师父名>` = 有人请求收我为徒（档 2）。
		# 服务端 `handle_tutor:22729-22732 / 22755-22758` 与登录补投 `:22227-22239` 同形状。
		if fields.size() < 4:
			return
		tutor_requested.emit(1 if 子 == 4 else 2, int(fields[2]), String(fields[3]))
		return
	if 子 == 14:
		# 关系列表：`77:14:<行>@…`，一行 11 段（`_tutor_relation_row:22327-22351`）。
		# 空表那一格是 `-` ⇒ 两份都清（"逐出徒弟/退出师门"就靠这条把 UI 抹干净）。
		var 师: Dictionary = {}
		var 徒: Array = []
		for 一 in String(fields[2] if fields.size() > 2 else "-").split("@"):
			var 段 := 一.split("&")
			if 段.size() < 8:
				continue
			var 项 := {"charId": int(段[0]), "name": String(段[1]), "level": int(段[2]),
					"job": int(段[3]), "face": int(段[4]), "relation": int(段[7])}
			if 项["relation"] == -2:
				师 = 项
			elif 项["relation"] == -1:
				徒.append(项)
		authoritative_tutor = 师
		authoritative_students = 徒
		tutor_list_received.emit(师, 徒)
		return
## 原版 `friendListData.isFriend(id)`（`DetailsWindow._addFriend():193`）按**角色编号**判；
## 编号来自 `127` 回帧的 `authoritative_friends`（`_parse_social_contacts:4158-4163`）。
func is_friend(character_id: int) -> bool:
	if character_id <= 0:
		return false
	for 项 in authoritative_friends:
		if int(项.get("character_id", 0)) == character_id:
			return true
	return false

func request_chat(message: String, message_type: int = 0, target_id: int = 0, target_name: String = "") -> bool:
	var clean := message.replace(":", " ").replace("@", " ").replace("&", " ").strip_edges()
	if clean.is_empty():
		return false
	return send_game_request(OP_CHAT, "1536:0:0:%d:0:%d:%s:-:%s" % [message_type, target_id, clean, target_name])

func request_quest(action: int, quest_id: int) -> bool:
	return send_game_request(OP_QUEST_ACTION, "%d:%d" % [action, quest_id])

## 拉任务列表：**两条请求**（已接列表 byte 1、可接列表 byte 2）。
## 服务端两条都回 `444`（`_send_original_started_quest_list` / `_send_original_can_start_quest_list`）。
func request_quest_list() -> bool:
	return send_game_request(OP_QUEST_INFO, "1") and send_game_request(OP_QUEST_INFO, "2")

## 学习/升级忍术（`SKILL_CHANGE = 1330`）。报文 = `writeByte(action), writeInt(skillId)`：
## action 0=学习、2=升级（`SkillChangeProcessor.as:16-31`）。
## ⚠️ 2026-10-18 修：原来签名是 `(skill_id, amount)`，段序整个反了 —— 服务端把技能 id
## 当 action 读，永远落在 `SkillChangeAction` 枚举外、静默丢弃（"提升层数点了没反应"）。
func request_skill_change(action: int, skill_id: int) -> bool:
	return send_game_request(OP_SKILL_CHANGE, "%d:%d" % [action, skill_id])

func request_shuriken(action: int, enabled := false) -> bool:
	var content := str(action)
	if action == 0 or action == 2:
		content += ":%d" % int(enabled)
	return send_game_request(OP_AN_QI, content)

## 结印「跳一次」（原版 `JieYinProcessor.requestJieYin_EatUp`：请求体就是**一个 byte 0**）。
## ⚠️ 只有这一个动作。协议里那条 byte 1（`eatUpAutoConsumeAllZq` = 服务端一次吞光精华）
##    在原版**没有任何 UI 调用点**（`Client.as:8558` 定义了、全工程零引用）⇒
##    结印的「自动提升」是**客户端每 0.8 秒重发这一发**（见 `功能窗口.排结印下一跳`）。
## ⚠️ 也**没有**"请求当前状态"这第三个动作：`handleJieYinAction` 只认下行 cmd 0/1/2，
##    上行只发 0/1，阶段/熟练度是登录时服务端**主动推**的（`_send_jie_yin_state`）
##    ⇒ 原来那个 `request_jieyin_state()`（发 2318:2）是**空枪**，进人物页那一发永远无回帧，已删。
func request_jieyin() -> bool:
	return send_game_request(OP_JIE_YIN, "0")

func request_anqi_state() -> bool:
	return send_game_request(OP_AN_QI, "3")

func request_card_level(level: int) -> bool:
	return send_game_request(OP_CARD, "0:%d" % level)

func request_card_node(level: int, node_id: int) -> bool:
	return send_game_request(OP_CARD, "1:%d:%d" % [level, node_id])

func request_card_commit(level: int, node_id: int) -> bool:
	return send_game_request(OP_CARD, "2:%d:%d" % [level, node_id])

func request_card_claim(level: int, node_id: int) -> bool:
	return send_game_request(OP_CARD, "3:%d:%d" % [level, node_id])

func request_chest_open(object_id: int) -> bool:
	return send_game_request(OP_CHEST, "0:%d" % object_id)

func request_chest_close(object_id: int) -> bool:
	return send_game_request(OP_CHEST, "1:%d" % object_id)

func request_chest_claim(object_id: int, item_slot: int) -> bool:
	return send_game_request(OP_CHEST, "2:%d:%d" % [object_id, item_slot])

func request_chest_claim_all(object_id: int) -> bool:
	return send_game_request(OP_CHEST, "3:%d" % object_id)

func request_buff_fusion(first_slot: int, second_slot: int) -> bool:
	return send_game_request(OP_BUFF_FUSION, "1:%d:%d" % [first_slot, second_slot])

## 禁寻路图（迷路森林那两口）里打坐/双修**根本不许发**：
## `Client.as:4340`（`requestHealStart`）与 `:7921`（`requestDoubleHealInvite`）都套了
## `if(!API.map.nowInNotFindPathMap)`，外边那层 `HealHandler.requestHealStart():349-353`
## 还会把 `nowInHeal` 直接清掉 —— 两处一致：这一类图里没有回血/双修。
func _禁寻路图() -> bool:
	return 禁寻路地图.是禁寻路图(str(authoritative_map_id))

func request_heal_start() -> bool:
	if _禁寻路图():
		return false
	return send_game_request(OP_HEAL, "1")

func request_heal_stop() -> bool:
	return send_game_request(OP_HEAL, "2")

func request_double_heal_invite(partner_id: int) -> bool:
	if _禁寻路图():
		return false
	return send_game_request(OP_HEAL, "3:%d" % partner_id)

func request_double_heal_accept(partner_id: int) -> bool:
	return send_game_request(OP_HEAL, "4:%d" % partner_id)

func request_double_heal_deny(partner_id: int) -> bool:
	return send_game_request(OP_HEAL, "5:%d" % partner_id)

func request_xinfa_change(xinfa_id: int) -> bool:
	return send_game_request(OP_HEAL, "6:%d" % xinfa_id)

## 开窗时查询「当前修炼的心法」——原版 `ButtonsWindow.as:84` 派发 XINFA_DAKAI ⇒
## `UI.as:649-652 openXinfaWindow()` 里唯一一句就是 `Client.requestXinfaShow()`（发 `7`），
## 回帧 `HEAL_STATE:3:<id>` 才由 `Client.as:8033 onDefaultXinfaId` 建窗并填主格。
## 本机服务端确实在处理：`fake_flash_server.py:34799-34800`（QUERY_XINFA=7 ⇒ `_send_default_xinfa()`）。
func request_xinfa_show() -> bool:
	return send_game_request(OP_HEAL, "7")

func request_heal_state() -> bool:
	return send_game_request(OP_HEAL, "8")

## 八门请求（`MAI = 1287`）。`动作` 照原版 `MaiProcessor`：**1 统计 / 2 开通穴道 / 3 突破 / 4 突破信息**
## （服务端 `MaiAction` 同值）。
## ⚠️ 动作 2 的三个字段原是 `list_id/point_id/mode` 这么命名的 —— **全错**：
##   原版 `ChongMaiWindow.as:272` 发的是 `requestMaiExplode(maiId, pointId, 勾选 ? 下拉+1 : 0)`
##   ⇒ 依次是**门序号 / 该门穴位下标 / 用几个八门铜人**。名字错读一次就会写出错的判据
##   （§3.112 的同族教训），2026-10-14 改名对齐。
func request_bamen(动作: int, 门序号 := 0, 穴位下标 := 0, 铜人数 := 0) -> bool:
	var content := str(动作)
	if 动作 == 2:
		content = "%d:%d:%d:%d" % [动作, 门序号, 穴位下标, 铜人数]
	return send_game_request(OP_MAI, content)

func request_huodong_countdowns() -> bool:
	return send_game_request(OP_HUODONG_ACTION, "0")

func request_biguan_query() -> bool:
	return send_game_request(OP_BIGUAN, "2")

func request_biguan_claim(use_double: bool) -> bool:
	## 原版 `AllInOneProcessor.requestBiguan():4272-4278` 就是两个字节：
	## `writeByte(1)` + `writeByte(param1 ? 1 : 0)` ⇒ 领取的 action 恒为 **1**，
	## 单双倍在第二字节。以前发 `10/11` 是照本地服务端方言自造的（2026-10-20 已把
	## 服务端 `handle_biguan` 改回原版的 `1:<0|1>`，两边一起对齐）。
	return send_game_request(OP_BIGUAN, "1:%d" % (1 if use_double else 0))

func request_rouquan_stage_up() -> bool:
	return send_game_request(OP_ROU_QUAN, "0")

func request_xielunyan_stage_up() -> bool:
	return send_game_request(OP_XIE_LUN_YAN, "0")

func request_lunhuiyan_stage_up() -> bool:
	return send_game_request(OP_LUN_HUI_YAN, "0")

func request_kunchong_strength(item_position: int, use_guarantee := false, help_count := 0) -> bool:
	return request_strength_kunchong(item_position, use_guarantee, help_count)

func _send_login() -> void:
	if _login_sent:
		return
	_login_sent = true
	var account := _pending_account
	var password := _pending_password
	if account.is_empty():
		_fail_connection("请输入账号")
		return
	_set_status("登录中", "正在验证账号 %s" % account)
	_send_bridge_request(6, JSON.stringify({"userName": account, "password": password, "serverId": 1}))

func _read_available_packets() -> void:
	var available := _tcp.get_available_bytes()
	if available <= 0:
		return
	var result := _tcp.get_data(available)
	if int(result[0]) != OK:
		_fail_connection("读取服务器数据失败")
		return
	_receive_buffer.append_array(result[1] as PackedByteArray)
	while _receive_buffer.size() >= 4:
		var body_size := _read_u32_be(_receive_buffer, 0)
		if body_size < 6 or body_size > 16 * 1024 * 1024:
			_fail_connection("服务器数据包长度异常")
			return
		if _receive_buffer.size() < body_size + 4:
			return
		var body := _receive_buffer.slice(4, body_size + 4)
		_receive_buffer = _receive_buffer.slice(body_size + 4)
		_handle_amf_frame(body)

func _handle_amf_frame(frame: PackedByteArray) -> void:
	var decoded := _amf3_read_string(frame)
	if decoded.is_empty():
		# 解不出 AMF3 字符串 ⇒ 试原始帧（1820 的列表回帧就是这种）。
		# ⚠ 别改回"只 push_warning 就 return"：那等于把服务端真发的数据整帧丢掉，
		#   页面表现为「窗开得出、里面是空的」而且**一声不响**。
		_handle_original_frame(frame)
		return
	var plain := _decrypt_amf_string(decoded.bytes)
	if plain.begins_with("{"):
		var json := JSON.new()
		if json.parse(plain) == OK and json.data is Dictionary:
			_handle_bridge_dictionary(json.data)
			return
		push_warning("BackendConnection: JSON 回包格式异常：%s" % plain.left(160))
	_handle_bridge_text(plain)

func _handle_bridge_dictionary(data: Dictionary) -> void:
	var opcode := int(data.get("jylx", data.get("opCode", -1)))
	match opcode:
		0:
			_handle_login_status_value(int(data.get("loginStatus", -1)))
		1:
			_send_login()
		10:
			_handle_bridge_character(data)
		17:
			# `ADD_NEW_CHAR_ENTRY` —— 服务端建角成功后把新角色整份推回来（带 charInfo + maxChars）。
			# ⚠ **不许**在这里 emit `character_list_received`：原版这一号只报"建好了"
			#   （`LoginProcessor.as:326-339 handleAddNewCharacterEntryPacket` →
			#   `LoginServClient.onAddNewCharacterEntry` → `MainLoader.onCharCreated()`
			#   = 拆掉创角窗 + 直接进游戏），**不刷角色列表**。
			#   以前顺手一 emit ⇒ 登录界面收到"列表非空"就把**选角窗**弹出来，
			#   玩家建完角还要再点一次角色才进图（用户 2026-10-10 报的那条"纯多余"）。
			var character_data = data.get("charInfo", {})
			if character_data is Dictionary:
				characters.append(character_data.duplicate(true))
				character_created.emit((character_data as Dictionary).duplicate(true))
		1028:
			# `GENERATED_CHAR_NAME`：原版这条只喂 `CreateCharWindow3.setName()`，
			# `Client.onGeneratedCharName` 是**空函数** ⇒ 这里也只发信号，不自己落名字。
			char_name_generated.emit(String(data.get("charName", "")))
		OP_BIGUAN_INFO:
			biguan_info_received.emit(
				int(data.get("seconds", 0)),
				int(data.get("expGain", 0)),
				int(data.get("zqGain", 0)),
			)
		OP_WANG_LIST:
			# 夹具 `handle_wang_list` 的回帧：`wanglist` = 每行一段 json，`||` 分隔
			# （`struct.pack("<iiiBi")` 的 text 通道等价物：index/mobId/mapId/alive/nextTime + 静态列）。
			var 行集: Array = []
			for 段 in String(data.get("wanglist", "")).split("||"):
				if String(段).is_empty():
					continue
				var 解: Variant = JSON.parse_string(String(段))
				if 解 is Dictionary:
					行集.append(解)
			wang_list_received.emit(行集)
		11:
			channel_id = int(data.get("channelId", 1))
			if character_id <= 0:
				character_id = int(data.get("clientId", 0))
			if _character_selected:
				_send_enter_game()
		34:
			var stats: Dictionary = data.duplicate(true)
			stats.erase("jylx")
			_apply_stats(stats)
		OP_VIP:
			_handle_vip_dictionary(data)
		OP_CZHUODONG:
			_handle_czhuodong_dictionary(data)
		39:
			_handle_skill_dictionary(data)
		_:
			# 未知 opcode → 忽略。
			# ⚠️ **别在这里接原始二进制**：本客户端恒走 AMF3 通道（文件头「通信通道」一节），
			#    服务端从不下发 `data` 字节数组，原来这条 `data` 分支是**不可达**的，已删。
			pass

## 1809:2:<描述>&<剩余秒>@… —— 左侧「系统消息」的活动倒计时列表。
## 只处理 action==2 的那一支（其它 action 是活动面板自身的事）。
func _handle_huodong_countdowns_text(fields: PackedStringArray) -> void:
	if fields.size() < 3 or int(fields[1]) != 2:
		return
	var 载荷 := String(fields[2])
	if 载荷 == "-" or 载荷.is_empty():
		huodong_countdowns_received.emit([])
		return
	var rows: Array = []
	for 段 in 载荷.split("@", false):
		var 片 := 段.split("&", true)
		if 片.size() < 2:
			continue
		rows.append({"text": String(片[0]), "seconds": maxi(0, int(片[1]))})
	huodong_countdowns_received.emit(rows)

## NPC 头顶标记（`513 UPDATE_NPC_QUEST_STATUS`）：一条一枚，`513:<object_id>:<状态>`。
## 存的是 **object_id**（服务端按在场实体发），要模板号请经 `map_npcs` 反查。
## `42:<infoType>:<questId>:<questStatus>:<updateType>`（本机服务端的文本桥，
## 见 `fake_flash_server.py:_send_original_quest_started_notification`）。
## 只认 `infoType == QUEST(1)` 且 `questStatus == START(1)` 且 `updateType == 0` 那一条 ——
## 与 `AllInOneProcessor.as:4155-4203` 的分支一致；其余 infoType（EXP/FAME/ITEM/…）不归这里。
func _handle_show_status_info_text(fields: PackedStringArray) -> void:
	if fields.size() < 5 or int(fields[1]) != STATUS_INFO_QUEST:
		return
	if int(fields[3]) != QUEST_STATUS_START or int(fields[4]) != 0:
		return
	quest_accepted.emit(int(fields[2]))

## `51:<questId>` —— 原版 `QuestProcessor.as:46-63` 只读一个 int。
func _handle_quest_completion_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	quest_completion_shown.emit(int(fields[1]))

func _handle_npc_quest_status_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var 号 := int(fields[1])
	if 号 <= 0:
		return
	var 新 := int(fields[2])
	## 只在**值真的变了**时才发信号：进图那一瞬服务端是成批发来的（一张图几十枚），
	## 每行都触发一次全场重挂没意义；而"变了"才是头顶那枚需要跟着动的唯一时机。
	var 旧 = npc_quest_status.get(号, null)
	npc_quest_status[号] = 新
	if 旧 == null or int(旧) != 新:
		npc_quest_status_updated.emit(号, 新)


## 任务列表与进度（`444 QUEST_INFO_UPDATE`）。
##
## ⚠️ **之前这条线是断的**：`443/444` 只 `quest_received.emit(opcode, fields)`，
##    而那个信号**一个消费者都没有** —— 于是在线时任务窗口读的一直是离线那套假任务。
##
## 真值出处：服务端 `_send_original_*` 与 `QuestListUpdateAction`（`fake_flash_server.py:1808`），
## 与客户端 `QuestProcessor.handleQuestInfoUpdatePacket`（`:463-492`）逐项对得上：
##
##   `444:3:<条目>@<条目>@…` 或 `444:3:-`     STARTED_LIST（已接）
##        条目 = `<任务id>&<状态>&<目标类型>&<数据>&<环id>&-&<完成次数>`
##              状态 1=进行中 2=可交；数据 = `<键>+<当前>+<需要>!…` 或 `-`
##   `444:4:<id>@<id>@…` 或 `444:4:-`        CAN_START_LIST（可接），**只有 id**
##   `444:2:<任务id>:<状态>:<类型>:<数据>:0`   ALL_PROGRESS（整条进度刷新）
##   `444:1:<任务id>:<目标序号>:<类型>:<数据>` SINGLE_PROGRESS（单目标刷新）
##
## 列表的"名字/类型/等级/奖励"一律**不在**这些帧里 —— 它们来自 `数据/任务.json`
## （原版 `Quest` 段），由任务窗口按 id 合并。这里只交运行期的 id/状态/进度。
func _handle_quest_update_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var action := int(fields[1])
	match action:
		3:
			var 已接: Array[Dictionary] = []
			if fields[2] != "-":
				for 段 in fields[2].split("@", false):
					已接.append(_解任务状态条目(String(段)))
			authoritative_quests_started = 已接
			quest_list_received.emit(已接.duplicate(true), authoritative_quests_available.duplicate(true))
		4:
			var 可接: Array[Dictionary] = []
			if fields[2] != "-":
				for 段 in fields[2].split("@", false):
					var id := String(段).strip_edges()
					if not id.is_empty():
						可接.append({"id": id, "completed": false})
			authoritative_quests_available = 可接
			quest_list_received.emit(authoritative_quests_started.duplicate(true), 可接.duplicate(true))
		2:
			if fields.size() < 6:
				return
			var 信息 := {
				"id": String(fields[2]), "status": int(fields[3]),
				"kind": str(fields[4]), "data": String(fields[5]),
			}
			if fields.size() >= 9:
				信息.merge(_解任务环字段(int(fields[6]), fields[7], int(fields[8])))
			_存整条任务进度(信息)
			quest_progress_received.emit(信息)
		1:
			if fields.size() < 6:
				return
			quest_progress_received.emit({
				"id": String(fields[2]), "objective": int(fields[3]),
				"kind": str(fields[4]), "data": String(fields[5]),
			})
		_:
			return


## 已接列表里的一个条目 → 本移植的运行时任务字典。
## 形状见 `_handle_quest_update_text` 上方；`x+y+z` 的目标数据在这里折成 当前/需要 两个和。
func _解任务状态条目(段: String) -> Dictionary:
	var 片 := 段.split("&", true)
	if 片.size() < 2:
		return {}
	var 状态 := int(片[1])
	var 条 := {
		"id": 片[0], "completed": 状态 == 2, "flash_status": 状态,
		"progress": 0, "required": 0,
		"目标进度": _解目标数据(片[2] if 片.size() > 2 else "", 片[3] if 片.size() > 3 else ""),
	}
	for 项 in (条["目标进度"] as Array):
		条["progress"] = int(条["progress"]) + int((项 as Dictionary)["curr"])
		条["required"] = int(条["required"]) + int((项 as Dictionary)["count"])
	if 片.size() >= 7:
		条.merge(_解任务环字段(int(片[4]), 片[5], int(片[6])))
	return 条


func _解任务环字段(环号: int, 编码: String, 次数: int) -> Dictionary:
	var 出 := {"loop_id": 环号, "finish_count": 次数}
	if 环号 <= 0 or 编码 == "-" or 编码.is_empty():
		return 出
	var 动态: Variant = JSON.parse_string(Marshalls.base64_to_utf8(编码))
	if not 动态 is Dictionary:
		return 出
	出["dynamic_data"] = 动态
	出["cooldown_deadline"] = Time.get_ticks_msec() + int((动态.get("daily_cooldown", {}) as Dictionary).get("remain_seconds", 0)) * 1000
	出["turn_in_npc"] = str(int(动态.get("npc", 0)))
	return 出


func _存整条任务进度(信息: Dictionary) -> void:
	var 索引 := -1
	for i in authoritative_quests_started.size():
		if str(authoritative_quests_started[i].get("id", "")) == str(信息["id"]):
			索引 = i
			break
	if 索引 < 0:
		authoritative_quests_started.append({"id": 信息["id"]})
		索引 = authoritative_quests_started.size() - 1
	var 条: Dictionary = authoritative_quests_started[索引]
	var 目标: Array = 条.get("目标进度", [])
	if 信息.has("dynamic_data"):
		if int(条.get("loop_id", 0)) != int(信息.get("loop_id", 0)) or (条.get("dynamic_data", {}) as Dictionary).get("check", {}) != (信息["dynamic_data"] as Dictionary).get("check", {}):
			目标 = []
		for 键 in ["dynamic_data", "loop_id", "finish_count", "cooldown_deadline", "turn_in_npc"]:
			条[键] = 信息[键]
	var 类 := str(信息["kind"])
	目标 = 目标.filter(func(项: Dictionary): return str(项.get("kind", "")) != 类)
	目标.append_array(_解目标数据(类, str(信息["data"]).replace("&", "+").replace("@", "!")))
	条["目标进度"] = 目标
	条["flash_status"] = int(信息["status"])
	条["completed"] = int(信息["status"]) == 2
	条["progress"] = 0
	条["required"] = 0
	for 项 in 目标:
		条["progress"] += int(项["curr"])
		条["required"] += int(项["count"])


## `444:3` 条目第 3 段 = `<键>+<当前>+<需要>!…`（`!` 分目标），第 2 段 = 这一批的**目标类型**。
## 服务端（`fake_flash_server.py:_encode_original_quest_status`）**一批只带一种 kind**，
## 多 kind 的任务剩下的靠随后那几条 `444:2` 补齐 ⇒ 这里原样交出去，合并交给会话层。
func _解目标数据(类: String, 数据: String) -> Array:
	var 出: Array = []
	if 数据 == "" or 数据 == "-":
		return 出
	for 项 in 数据.split("!", false):
		var 三段 := String(项).split("+", true)
		if 三段.size() < 3:
			continue
		出.append({"kind": 类, "key": String(三段[0]),
				"curr": int(三段[1]), "count": int(三段[2])})
	return 出


## 活跃度面板（`2326`）。服务端在 AMF3 通道下发的**就是文本帧** ——
## 原来这里只有一条二进制分支（`_handle_packet` 里的 `OP_ACTIVITY`），
## 而那条路不可达，于是文本帧到达后**被静默丢弃**，面板上的「今日活跃度」恒为 0。
##
## 真值出处：`fake_flash_server.py:32400-32502`
## （`_send_activity_panel` / `_claim_next_activity_reward` / `_advance_activity`）。三个 action：
##
##   `2326:0:<档位数>:<逐个任务次数>:<已领档位>:<总活跃分>`
##       ⚠️ 那段次数本身就是冒号连接的，会被 `split(":")` 切开 ——
##       所以后面的"已领档位/总活跃分"要**按 fields[2] 声明的个数**去定位，不能写死下标。
##   `2326:1:<档位>`   领取结果。**档位变大=成功、不变=失败**，没有独立布尔
##                     （服务端 :32314 / :32321 失败时回的就是原档位）。
##   `2326:2:<槽位(1基)>:<累计次数>:<本次新增活跃分>`   单任务增量。
##
## ⚠️ 那 15 项是**每日任务的完成次数**，**不是**奖励门槛 —— 门槛在 `数据/活跃度奖励.json`
##    （`游戏数据.活跃度奖励()`）。旧代码把前者命名成 `thresholds`，这里改正为 `task_counts`。
func _handle_activity_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var action := int(fields[1])
	if action == 0:
		var 档位数 := maxi(0, int(fields[2]))
		if fields.size() < 3 + 档位数 + 2:
			return
		var 次数表: Array[int] = []
		for index in 档位数:
			次数表.append(int(fields[3 + index]))
		authoritative_activity = {
			"task_counts": 次数表,
			"claimed_level": int(fields[3 + 档位数]),
			"points": int(fields[3 + 档位数 + 1]),
		}
	elif action == 1:
		# 没有独立成功布尔：档位比原来大就是领到了。
		var 新档位 := int(fields[2])
		var 旧档位 := int(authoritative_activity.get("claimed_level", -1))
		authoritative_activity["claimed_level"] = 新档位
		authoritative_activity["claim_success"] = 新档位 > 旧档位
	elif action == 2:
		if fields.size() < 5:
			return
		var 槽位 := int(fields[2])          # 1 基
		var 次数 := int(fields[3])
		var 新增分 := int(fields[4])
		var 表: Array = authoritative_activity.get("task_counts", [])
		if 槽位 >= 1 and 槽位 <= 表.size():
			表[槽位 - 1] = 次数
		authoritative_activity["task_counts"] = 表
		authoritative_activity["points"] = int(authoritative_activity.get("points", 0)) + 新增分
	else:
		return
	activity_state_received.emit(authoritative_activity.duplicate(true))

func _handle_bridge_text(text: String) -> void:
	var fields := text.split(":", true)
	if fields.is_empty() or not String(fields[0]).is_valid_int():
		return
	var opcode := int(fields[0])
	match opcode:
		OP_CHANGE_NAMES:
			_handle_change_name_text(fields)
		OP_HUODONG_ACTION:
			_handle_huodong_countdowns_text(fields)
		OP_CAN_JUAN_ACTION:
			# 夹具回帧 `1352:0:<0/1>`（cmd=0 + readBoolean，`AllInOneProcessor.handleCanJuan` 的 text 等价）
			if fields.size() >= 3 and int(fields[1]) == 0:
				can_juan_result_received.emit(String(fields[2]) == "1")
		OP_PORTAL_PANEL:
			# `1349:<request_id>:<正文>` —— Boss 房门那一步：服务端把换图挂起等人回话。
			# 不接这一帧 ⇒ CHANGE_MAP 被服务端吃进 `pending_map_confirmation` 后就不再往下走
			# （`_warp_to_map` 根本不会被调到），表现是**所有 Boss 图的门点了没反应**。
			# 正文本身可能带全角标点，按 `:` 拼回剩余段，别只取 fields[2]。
			if fields.size() >= 3:
				portal_panel_received.emit(int(fields[1]), ":".join(fields.slice(2)))
		OP_SPIRIT_ACTION:
			# `1823:<cmd>:<参数…>` → 会话拆状态；cmd 越界（>8）当噪声丢（服务端只发 0..8）。
			if fields.size() >= 2 and String(fields[1]).is_valid_int():
				var 命令号 := int(fields[1])
				if 命令号 >= 0 and 命令号 <= 8:
					spirit_action_received.emit(命令号, fields.slice(2))
		OP_PVE_ACTION:
			# `1572:0:<pve_progress>:<pve_points>`（服务端 `_send_pve_status:30856`）。
			# 只认 action 0 那一帧；action 2 是百炼关卡表（`_send_pve_enter_list`），归百炼页，不在此拆。
			if fields.size() >= 4 and int(fields[1]) == 0:
				pve_status_received.emit(int(fields[2]), int(fields[3]))
		OP_HERO_ACTION:
			if fields.size() >= 2 and String(fields[1]).is_valid_int():
				hero_action_received.emit(int(fields[1]), fields.slice(2))
		OP_SKILL_CHANGE_TMP:
			_handle_skill_change_tmp_text(fields)
		10:
			_handle_character_list_text(fields)
		32:
			_handle_inventory_change(fields)
		34:
			_handle_stats_text(fields)
		OP_GIVE_BUFF:
			_handle_give_buff_text(fields)
		OP_CANCEL_BUFF:
			_handle_cancel_buff_text(fields)
		OP_SYSTEM_BUF_ACTION:
			_handle_system_buff_text(fields)
		OP_GIVE_FOREIGN_BUFF:
			_handle_give_foreign_buff_text(fields)
		OP_CANCEL_FOREIGN_BUFF:
			_handle_cancel_foreign_buff_text(fields)
		OP_COUPLE_ATTACK:
			_handle_couple_attack_text(fields)
		OP_PLAYER_DAMAGE_PLAYER:
			_handle_player_damage_by_player_text(fields)
		OP_PLAYER_HP:
			_handle_player_hp_text(fields)
		39:
			_handle_skill_text(fields)
		58:
			_handle_character_info_text(fields)
		65:
			if fields.size() >= 3:
				server_message_received.emit(String(fields[2]))
		129:
			if fields.size() >= 7:
				_apply_map_state(int(fields[2]), int(fields[4]), int(fields[5]), int(fields[6]))
		132:
			_handle_warp_character_text(fields)
		162:
			_handle_spawn_player_text(fields)
		163:
			_handle_remove_map_entity_text(fields)
		187:
			_handle_move_player_text(fields)
		1328:
			_handle_player_attack_text(fields)
		40:
			_handle_close_range_attack_text(fields)
		194:
			_handle_damage_player_text(fields)
		238:
			_handle_spawn_monster_text(fields)
		237:
			_handle_item_cooldown_text(fields)
		239:
			_handle_kill_monster_text(fields)
		184:
			_handle_mob_attack_info_text(fields)
		241:
			_handle_move_monster_text(fields)
		243:
			_handle_damage_monster_text(fields)
		1291:
			_handle_lianzhan_text(fields)
		199:
			_handle_char_look_text(fields)
		252:
			_handle_monster_hp_text(fields)
		260:
			_handle_spawn_npc_text(fields)
		272:
			_handle_drop_item_text(fields)
		273:
			_handle_remove_drop_text(fields)
		OP_OPEN_SECRET_SHOP:
			_handle_secret_shop_text(fields)
		OP_OPEN_NPC_SHOP:
			_handle_npc_shop_text(fields)
		OP_CONFIRM_SHOP_TRANSACTION:
			if fields.size() >= 2:
				shop_transaction_received.emit(int(fields[1]))
		OP_OPEN_STORAGE:
			_handle_storage_text(fields)
		OP_PET_ACTION_RESPONSE:
			_handle_pet_action_text(fields)
		OP_COPY_RESPONSE:
			_handle_copy_action_text(fields)
		OP_HANG_ACTION:
			_handle_hang_action_text(fields)
		OP_CHAR_CONFIG:
			_handle_char_config_text(fields)
		OP_CHANGE_NAMES:
			_handle_change_name_text(fields)
		OP_CHANGE_WEATHER:
			_handle_weather_text(fields)
		OP_OPEN_PVP_ACTION:
			_handle_pk_mode_text(fields)
		OP_VIP:
			_handle_vip_text(fields)
		325, 328:
			_handle_npc_dialog_text(opcode, fields)
		444:
			_handle_quest_update_text(fields)
		513:
			_handle_npc_quest_status_text(fields)
		OP_SHOW_STATUS_INFO:
			_handle_show_status_info_text(fields)
		OP_SHOW_QUEST_COMPLETION:
			_handle_quest_completion_text(fields)
		OP_STONE_MERGE_RESPONSE, OP_EQUIP_INLAY_INFO, OP_WASH_PLUS_VALUE_RESPONSE, OP_EQUIP_FORGE_STRENGTH_RESULT, OP_EQUIP_FORGE_ADDITIVE_RESULT, OP_EQUIP_KUNCHONG_STRENGTH_RESULT, OP_BADGE_STONE_MERGE_RESPONSE:
			_handle_item_change_result(opcode, fields)
		# 十拳剑（灵器）炼制与忍具开光的结果帧走的是**同一条 ItemChange 语义**
		# （原版 `LingEquipProcessor.handleLingEquipOperationResult:75-99` /
		#  `RenJuProcessor.handleRenJuOperationResult:53-73` 都是「一个动作字节 + 后面跟载荷」）。
		# 惟 4/5/6（改变外观）在原版是**另一个处理函数**（`handleLingQiFaceList` 一族），
		# 载荷形状也不同 ⇒ 先在 action 上分叉，别让它落进 0-3 那条解析。
		OP_LING:
			if fields.size() >= 2 and String(fields[1]).is_valid_int() and int(fields[1]) >= 4:
				_handle_ling_qi_appearance_text(fields)
			else:
				_handle_item_change_result(opcode, fields)
		OP_RENJU:
			_handle_item_change_result(opcode, fields)
		OP_AUTO_CONSUME:
			_handle_timed_item_effect_text("auto_consume", fields)
		OP_DOUBLE_EXP:
			_handle_double_exp_text(fields)
		OP_ATTRIBUTE_EFFECT:
			_handle_timed_item_effect_text("attribute_boost", fields)
		OP_STONE_MERGE_EFFECT:
			_handle_timed_item_effect_text("stone_merge", fields)
		OP_CASH_MONEY_RESPONSE:
			if fields.size() >= 2:
				## 元宝数。原版 `Client.onCashMoneyInfo:9062-9070` 在这里**顺带**出一条
				## 「元宝 +N」的右下角提示 ⇒ 先按差值报，再灌进属性表。
				var 元宝数 := int(fields[1])
				_报元宝提示(元宝数)
				_apply_stats({"cash": 元宝数})
		OP_CASH_CATEGORY_RESPONSE:
			_handle_cash_shop_list_text(fields, "category")
		OP_CASH_SEARCH:
			_handle_cash_shop_list_text(fields, "search")
		OP_CASH_ITEM_INFO_RESPONSE:
			_handle_cash_item_info_text(fields)
		OP_CASH_CATEGORY_CAPACITY:
			if fields.size() >= 2:
				authoritative_cash_shop_capacity = maxi(0, int(fields[1]))
				cash_shop_capacity_received.emit(authoritative_cash_shop_capacity)
			# ⚠️ 同一个 opCode 也用来回「背包已扩充到 N 格」（服务端 :25979）——
			# `_extend_item_capacity` 里背包那条发的就是 `CASH_CATEGORY_CAPACITY`。
			# 所以这里还要把背包格数更新掉（`common_slots` 就是 `ItemWindow2` 的 totalCell）。
			if fields.size() >= 2:
				var 新格数 := maxi(0, int(fields[1]))
				if 新格数 > 0:
					authoritative_bag_capacity = 新格数
					bag_capacity_received.emit(新格数)
		OP_CASH_STORAGE_CAPACITY:
			# 仓库那条：`1085:新容量`（服务端 `_extend_item_capacity` 尾部）
			if fields.size() >= 2:
				authoritative_storage_capacity = maxi(0, int(fields[1]))
				storage_received.emit(authoritative_storage.duplicate(),
					authoritative_storage_gold, authoritative_storage_capacity)
				# ⚠️ **光写权威值不够**：仓库窗的总格数读的是**会话**的 `storage_capacity`
				#   （`仓库窗口._仓库总格数` → `会话.storage_capacity`），而那个字段只在
				#   `apply_backend_storage` 里被写。不在这里补一次，玩家点了「扩充仓库」、
				#   密卷也扣了，仓库上还是旧格数（`storage_received` 信号全工程零连接点，
				#   2026-10-11 扫"emit 了没人接"逮到）。走既有的那个入口，口径与仓库帧一致。
				var 会话 := get_node_or_null("/root/GameSession")
				if 会话 != null and 会话.has_method("apply_backend_storage"):
					会话.apply_backend_storage(authoritative_storage, authoritative_storage_gold,
						authoritative_storage_capacity)
		OP_CHAR_SEARCH:
			_handle_char_search_text(fields)
		OP_PAI_HANG:
			_handle_pai_hang_text(fields)
		OP_GUILD:
			_handle_guild_text(fields)
		OP_MAP_FLAG_ACTION:
			_handle_flag_text(fields)
		OP_GUILD_BOSS:
			_handle_guild_boss_text(fields)
		OP_FRIEND_RESPONSE:
			_handle_friend_text(fields)
		OP_PARTY_RESPONSE:
			_handle_party_text(opcode, fields)
		OP_PARTY_MEMBER_STATE:
			## ⚠ 203 **不是动作帧**：`<203>:<角色号>:<hp>:<maxhp>:<mp>:<maxmp>`
			## （服务端 `_party_member_stats_payload:23669-23675`）。以前并到 `_handle_party_text`
			## 里按"第二段是动作号"解 ⇒ 角色号被当成 action、match 不到任何一支，整条静默丢。
			_handle_party_member_stats_text(fields)
		OP_GIFT:
			_handle_gift_text(fields)
		OP_EXCHANGE:
			_handle_exchange_text(fields)
		OP_FUDAI_RESPONSE:
			_handle_fudai_text(fields)
		OP_ACTIVITY:
			_handle_activity_text(fields)
		OP_WAR_PANEL:
			_handle_war_panel_text(fields)
		OP_ARENA_PK:
			_handle_arena_text(fields)
		OP_ACHIEVEMENT:
			_handle_achievement_text(fields)
		OP_HEAL_RESPONSE:
			_handle_heal_text(fields)
		OP_TARGET_INFO:
			_handle_target_info_text(fields)
		OP_STALL_ACTION:
			_handle_stall_text(fields)
		OP_MUYE_BATTLE:
			_handle_muye_battle_text(fields)
		OP_TRADE_RESPONSE:
			_handle_trade_text(fields)
		OP_TUTOR:
			_handle_tutor_text(fields)
		OP_CARD:
			_handle_card_text(fields)
		OP_CHEST:
			_handle_chest_text(fields)
		OP_BUFF_FUSION:
			_handle_buff_fusion_text(fields)
		OP_AN_QI:
			_handle_anqi_text(fields)
		1348:
			_handle_char_skill_level_text(fields)
		OP_JIE_YIN:
			_handle_jieyin_text(fields)
		1290, 1821, 2307, 2313:
			_handle_cultivation_text(opcode, fields)
		1536:
			_handle_chat_text(fields)
		2051, 2052, 100000:
			_handle_inventory_snapshot(opcode, fields)
		OP_EQUIPED_KUNCHONG:
			_handle_equipped_kun_chong(fields)

## 排行榜（`1346`）回帧分派。三种 cmd 的读序**互不相同**，逐条照解码器抄、不猜：
## · cmd 0 `handlePaiHangUpdateTitles:62-91` = `charId(int)` + `cnt(int)` + `cnt × title(int)`
##   —— 原版喂 `CharacterHandler.updatePaiHangTitle`（人物头顶那枚榜单徽记）。
## · cmd 1 `handlePaiHangSearchResult:122-156` = `tabId(int)` + `bJiangHu(bool)` + `rank(int)` + 行
## · cmd 2 `handleHidePaiHangResult:28-60` = `tabId(int)` + `rank(int)` + 行（**没有** bool 那一段）
## 行 = `PaiHangInfo.decode:28-35` 的五段 `serverId & charId & name & petUid & value`，
## 服务端文本化用 `@` 连行、空表写 `-`（`fake_flash_server.py:27511-27518`）。
## ⚠ 原版把 cmd 1 的 `rank` **丢掉了**（`RankWindowManager.onPaiHang_searchResult:86-92` 只往
##   `setData` 传 tabId/bool/行），「你的当前排名」是客户端**扫行找自己**算出来的
##   （`RankWindow2.queryMyRank:86-101`，找不到 ⇒ `RANK_MY_RANK_NOT_ENOUGH`）。这里两个都存：
##   `rank` 原样留着（门要钉服务端给的那个数），UI 走原版的扫行口径。
func _handle_pai_hang_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	match int(fields[1]):
		0:
			if fields.size() < 4:
				return
			var 称号: Array[int] = []
			var 人数 := int(fields[3])
			if 人数 > 0 and fields.size() >= 5 and String(fields[4]) != "-":
				for 段 in String(fields[4]).split("@", false):
					称号.append(int(段))
			authoritative_ranking_titles[int(fields[2])] = 称号
			## ⚠ 空表也要发：原版 `Character.updatePaiHangTitle:1186-1191` 拿到空数组是
			##   `removeChild(pane)`（把那一摞摘掉），不是"当没看见"。
			榜单徽记收到.emit(int(fields[2]), 称号)
		1:
			# cmd 1 有 `bJiangHu` 那一段 ⇒ 底座比 cmd 2 多一格
			if fields.size() < 6:
				return
			_存排行榜列表(int(fields[2]), String(fields[3]) != "false", int(fields[4]), String(fields[5]))
		2:
			# 跨服活动窗（`KuaFuActivityWindow.as:92` 那条 `requestPaiHangHide(0)`）本工程未实装，
			# 而这个客户端从不发 action 1 ⇒ 本条实际不可达；留着是为了"服务端真发了别当没看见"，
			# 存进同一张表、榜号与 cmd 1 同键（忍界位按原版缺省 = true）。
			if fields.size() < 5:
				return
			_存排行榜列表(int(fields[2]), true, int(fields[3]), String(fields[4]))


func _存排行榜列表(榜单: int, 忍界位: bool, 服务端名次: int, 编码: String) -> void:
	var 行: Array = []
	if 编码 != "-" and not 编码.is_empty():
		for 文本 in 编码.split("@", false):
			var 段 := String(文本).split("&", true)
			if 段.size() < 5:
				continue
			行.append({
				"server_id": int(段[0]), "char_id": int(段[1]), "name": String(段[2]),
				"pet_uid": float(段[3]), "value": String(段[4]),
			})
	authoritative_rankings[榜单] = {
		"rows": 行, "rank": 服务端名次, "江湖": 忍界位,
	}
	ranking_state_received.emit({"tab": 榜单, "entries": 行, "rank": 服务端名次, "江湖": 忍界位})


func _handle_bridge_character(data: Dictionary) -> void:
	# ⚠️ 这里原来有一条"`data` 是字节数组 → 解原始角色列表"的分支，**不可达**（见文件头），已删。
	var character := {}
	for key in ["id", "name", "gender", "skinColor", "face", "hair", "level", "job", "hp", "maxHp", "mp", "maxMp", "remainingAp", "remainingSp", "fame", "mapId", "zq", "vip", "vipLevel", "vip_level", "shengwang", "crime", "charType", "lingFace", "lingColor", "cashBind"]:
		if data.has(key):
			character[key] = data[key]
	## 服务端的角色包叫 `lingColor`（`CharacterState.to_dict`），客户端内部统一叫
	## `lingQiColor`（`自身外观` / 灵器外观选择窗 / 199 第 13 位都读这个键）。
	## 不在这里归一，两个后果都实测过：`应用人物` 每次登录刷一条「没这个键」的警告；
	## 进图时 `authoritative_stats` 只有脸没有色 ⇒ 第一次打开外观窗颜色永远显示原色。
	if character.has("lingColor"):
		character["lingQiColor"] = int(character["lingColor"])
		character.erase("lingColor")
	for pair in [["ap_ATK", "apAtk"], ["ap_DEF", "apDef"], ["ap_DEX", "apDex"], ["ap_PHY", "apPhy"], ["experience", "exp"]]:
		if data.has(pair[0]):
			character[pair[1]] = data[pair[0]]
	character_id = int(character.get("id", 0))
	## ⚠ **「这个号还没有角色」服务端回的是只带 maxChars 的一条 jylx:10**
	## （实测抓包 `{"jylx":10,"maxChars":1}`，见 测试/原版协议抓包.json 的 charlist 那一步）。
	## 以前无条件把这一条当成"一枚角色"塞进列表 ⇒ 列表长度 1、内容全空、编号 0 ⇒
	## `select_character(0)` 第一行就 return ⇒ 界面永远停在"正在读取角色"，
	## 既不报错也不提示（用户 2026-10-09 报的"注册完能用但进不去游戏"就是这一条）。
	var 空号 := character_id <= 0 and String(character.get("name", "")).is_empty()
	characters.clear()
	if 空号:
		character_list_received.emit(characters.duplicate(true), int(data.get("maxChars", 1)))
		_set_status("需要创建角色", "这个账号还没有角色")
		return
	_apply_vip_from_character(character)
	character_received.emit(character)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.apply_backend_character(character)
	characters.append(character.duplicate(true))
	character_list_received.emit(characters.duplicate(true), int(data.get("maxChars", 1)))
	if _auto_select_character:
		select_character(character_id)

func _send_enter_game() -> void:
	if _enter_sent or character_id <= 0:
		return
	_enter_sent = true
	_set_status("进入游戏", "正在载入服务器角色状态")
	_send_bridge_request(11, "11:%d" % character_id)

func _handle_stats_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var names := {
		4: "level", 5: "job", 6: "hp", 7: "mp", 9: "apAtk", 10: "apDef",
		11: "apDex", 12: "apPhy", 13: "maxHp", 14: "maxMp", 16: "attack",
		17: "defense", 18: "critical", 19: "dodge", 20: "attack_speed",
		21: "move_speed", 22: "zq", 23: "remainingAp", 24: "remainingSp",
		25: "exp", 26: "fame", 27: "gold",
		# ⭐ **30 = CASH_BIND = 点券**（原版 `CocoStatType.CASH_BIND:int=30`，
		# `DataCenter.as:2625-2643` 收到即更新 `bandMoney` + 刷背包货币行 + 刷商城）。
		# 之前这张表到 27 就断了 —— **用点券礼包时服务端发的 `30&数量` 被静默丢弃**，
		# 表现就是用户实机报的"点券用了不加、背包/商城都不变"。
		# 键名用 `cashBind`（不是 `cash_bind`）：**复用 `服务端会话同步.应用人物` 里已有的
		# `"cashBind": "cash_bind"` 映射**，那条再把值写进 `player_stats.cash_bind` 并 emit
		# `player_stats_changed`（背包窗口那行读的就是它）。走这条现成的路，不另建同步。
		30: "cashBind",
		# 29 = `StatType.PET_LIMIT`（`fake_flash_server.py:1084`）= **兽栏容量**。
		# ⚠ 扩完兽栏服务端**只发这一条 stats、不重发宠物列表**（`:26320`）⇒ 这张表原来没有 29、
		#   29 被静默扔掉 ⇒ 容量永远不变（用户报："只提示已请求扩展兽栏，并不会扩展"）。落点见 `_apply_stats`。
		29: "petCapacity",
		# ⭐ **33 = CRIME = 罪恶值**。原版人物属性窗那一行取的就是它
		# （`DataCenter.as:1464` `_loc1_.fame = this.stats.crime`，`:2359` 同）。
		# 原来这张表没有 33、而窗口读的是 `fame`（字段 26）—— 服务端**从不发 26**
		# （`_send_all_stats` 只发 27/28/30/33），⇒ 玩家看到的罪恶值永远是旧数。
		33: "crime",
		# 下列字段服务端**确实在发**（`_send_all_stats` 的 28、`_client_base_combat_stats` 的
		# 35/39/40/41/42/43），原版 `DataCenter.as` 也逐个处理 —— 收下来，别静默丢。
		# 本客户端暂无对应界面（原版人物窗也不画这几条），键先建好，落点见 `_apply_stats`。
		28: "moneyBind", 35: "anqiTrigger",
		41: "damageReflect", 42: "damageReduce", 43: "ignoreDef",
		39: "addJobSkillLevel", 40: "addWorldSkillLevel",
	}
	var result := {}
	_记属性帧()
	for entry in String(fields[1]).split("@", false):
		var pair := entry.split("&", false)
		if pair.size() < 2:
			continue
		var field_id := int(pair[0])
		## 先按**字段号**算获得提示（原版 `DataCenter.updateOneStatu` 就是这个粒度），
		## 再走名字表决定要不要往会话里灌 —— 两件事各自判，谁也不挡谁。
		_报属性提示(field_id, float(pair[1]))
		if names.has(field_id):
			result[names[field_id]] = float(pair[1]) if field_id == 25 else int(pair[1])
		elif not _已警告字段号.has(field_id):
			# ⚠️ **别静默丢弃** —— 2026-09-25 那次「攻速/移速恒为 0」就是这张表漏了 20/21：
			#    服务端一直在发，客户端不吭声地把它扔了，谁都不知道，直到有人盯着面板看出两个 0。
			#    这里对**没警告过的**字段号警告一次（去重，免得每次属性推送都刷屏）。
			#    服务端确实会发一些我们没建模的字段（28/29/30/33/35/41/42/43 —— 见
			#    `fake_flash_server.py:1058-1095` 的 StatType），它们各警告一次之后就安静了。
			_已警告字段号[field_id] = true
			push_warning("统计包里有客户端**未登记**的字段号 %d（值 %s）—— 漏一个就有一个属性静默为 0；"
				% [field_id, pair[1]] + "要接的话在 `_handle_stats_text` 的 names 表里补上。")
	_apply_stats(result)

## 1811 系统增益：`0:<type>:<value>:<剩余秒>:<总秒>` / `1:<type>`。
## 原版 `SystemBuffStat.decode` 的字段序是 `type:u8, value:double, time:int, duration:int`
## （`as3/com/mxw/data/buff/SystemBuffStat.as:18-22`）；服务端二进制 `struct.pack("<BBdii")`
## 前面多一个 action 字节 ⇒ 文本这里第 2 段是 action、第 3 段才是 type。
func _handle_system_buff_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var 动作 := int(fields[1]) if String(fields[1]).is_valid_int() else -1
	var 类型 := int(fields[2]) if String(fields[2]).is_valid_int() else -1
	if 动作 < 0 or 类型 < 0:
		return
	var 值 := 0.0
	var 剩余 := 0
	var 总 := 0
	if 动作 == 0 and fields.size() >= 6:
		值 = float(fields[3])
		剩余 = int(fields[4])
		总 = int(fields[5])
	system_buff_received.emit(动作, 类型, 值, 剩余, 总)


func _handle_give_buff_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	for encoded in String(fields[1]).split("@", false):
		var values := encoded.split("&", true)
		if values.size() < 5:
			continue
		_apply_buff({
			"type": int(values[0]),
			"value": float(values[1]),
			"skill_id": int(values[2]),
			"skill_level": int(values[3]),
			"duration_ms": maxi(0, int(values[4])),
		})
	_emit_buffs()

func _handle_cancel_buff_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	for value in String(fields[1]).split("@", false):
		if value.is_valid_int():
			authoritative_buffs.erase(int(value))
	_emit_buffs()

## 把一条 `GIVE_BUFF` 补成 HUD 能直接画的样子。
##
## 真值（`SkillHandler.applyBuff:858-890`）：
##   · `skillId < 1000` ⇒ **宠物技能**：名字/图标/描述都走 PetSkill 那套
##     （`StringTool.getPetSkillString` / `PicTool.getPetSkillPic` /
##      `SkillDataTool.getPetSkillBuffDesc`）；
##   · 其余 ⇒ 玩家技能：名字走 String/Skill，**描述不是技能详情说明**，而是
##     `getSkillBuffDesc`（String/Skill 的 `buffDesc`），并把 `valueTotal` / `duration`
##     换成本次帧里的实际值。
## ⚠️ 以前只查 `数据/技能.json` 并写 `description` 键，而 HUD 读的是 `desc`
##    ⇒ 宠物 buff 没有名字/图标，所有 buff 的悬停描述都是空的。
func _apply_buff(state: Dictionary) -> void:
	var buff_type := int(state.get("type", -1))
	if buff_type < 0:
		return
	var skill_id := int(state.get("skill_id", 0))
	var skill_level := maxi(1, int(state.get("skill_level", 1)))
	var duration_ms := maxi(0, int(state.get("duration_ms", 0)))
	# 服务端帧里的 `value` 是 `value_percent / 100`（见 `_apply_timed_skill_buff` 的
	# `format(value_percent / 100.0)`）；原版 applyBuff 第一件事就是 `value *= 100`。
	var 值百分比 := maxf(0.0, float(state.get("value", 0.0)) * 100.0)
	var 名 := ""
	var 述 := ""
	var 图 := ""
	if skill_id < 1000:
		var 宠 := GAME_DATA.pet_skill(skill_id)
		名 = String(宠.get("name", ""))
		述 = String(宠.get("buff_desc", ""))
		if 述.is_empty():
			述 = String(宠.get("desc", ""))
		var 宠图 = 宠.get("icon", "")
		if 宠图 is String:
			图 = 宠图
	else:
		var 文案 := GAME_DATA.skill_text(skill_id)
		var 定义 := GAME_DATA.skill(skill_id)
		名 = String(文案.get("name", ""))
		if 名.is_empty():
			名 = String(定义.get("name", ""))
		述 = String(文案.get("buffDesc", ""))
		if 述.is_empty():
			述 = String(定义.get("description", ""))
		图 = String(定义.get("icon", ""))
	if 名.is_empty():
		名 = "状态效果 %d" % buff_type
	state["skill_level"] = skill_level
	state["name"] = 名
	state["desc"] = _填buff描述(述, 值百分比, duration_ms)
	state["description"] = state["desc"]        # 旧键，留着给老调用方
	state["icon"] = 图
	state["received_at_msec"] = Time.get_ticks_msec()
	authoritative_buffs[buff_type] = state.duplicate(true)


## `SkillDataTool.getSkillBuffDesc` 的占位符替换：`valueTotal` → 值（两位小数）、
## `duration` → 秒（整数）。值取本次帧里的，不按 1 级另算 —— 帧就是服务端的结算口径。
static func _填buff描述(模板: String, 值百分比: float, 时长毫秒: int) -> String:
	if 模板.is_empty():
		return ""
	var 秒 := roundi(float(maxi(0, 时长毫秒)) / 1000.0)
	return 模板.replace("valueTotal", "%.2f" % 值百分比).replace("duration", str(秒))

func _emit_buffs() -> void:
	var buffs: Array[Dictionary] = []
	for buff_type in authoritative_buffs:
		buffs.append((authoritative_buffs[buff_type] as Dictionary).duplicate(true))
	buffs.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("type", 0)) < int(b.get("type", 0)))
	buffs_received.emit(buffs)

## 201 **别人**身上的 buff（旁观者侧，原版 `AllInOneProcessor.handleGiveForeignBuffPacket:1043-1060`
## → `Client.onGiveForeignBuff:2654` → `SkillHandler.applyOtherPlayerBuff:363`）。
## 服务端文本行式（`fake_flash_server:42018/42112`）：`201:<角色号>:<行>@<行>:<延迟>`，
## 行 = `<type>&<value>&<skillId>&<skillLevel>&<durationMs>` —— 与 35 那条**同一行式**，
## 只是多了第一段"施加给谁"。⚠ 别复用 `_apply_buff`：那一支写的是自己的 `authoritative_buffs`
## 与 HUD 状态排，把别人的状态挂到自己身上就是假象（原版两条链从一开始就分开）。
func _handle_give_foreign_buff_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var 角色号 := int(fields[1])
	if 角色号 <= 0:
		return
	var 列表: Array = []
	for encoded in String(fields[2]).split("@", false):
		var values := encoded.split("&", true)
		if values.size() < 5:
			continue
		列表.append({
			"type": int(values[0]),
			"value": float(values[1]),
			"skill_id": int(values[2]),
			"skill_level": int(values[3]),
			"duration_ms": maxi(0, int(values[4])),
		})
	if 列表.is_empty():
		return
	foreign_buff_received.emit(角色号, 列表, int(fields[3]) if fields.size() > 3 else 0)


## 202 别人身上的 buff 掉了（原版 `:515-535` → `cancelOhterPlayerBuff:691`）。
## 服务端文本：`202:<角色号>:<type>@<type>`（`fake_flash_server:42181/37978`）。
func _handle_cancel_foreign_buff_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var 角色号 := int(fields[1])
	if 角色号 <= 0:
		return
	var 类型表: Array = []
	for value in String(fields[2]).split("@", false):
		if value.is_valid_int():
			类型表.append(int(value))
	if 类型表.is_empty():
		return
	foreign_buff_cancelled.emit(角色号, 类型表)


## 203 队伍成员的血/蓝（服务端 `_party_member_stats_payload:23669-23675`）：
## `<203>:<角色号>:<hp>:<maxhp>:<mp>:<maxmp>`。**不是动作帧**（见分派臂那条注释）。
func _handle_party_member_stats_text(fields: PackedStringArray) -> void:
	if fields.size() < 6:
		return
	for i in range(1, 6):
		if not String(fields[i]).is_valid_int():
			return
	party_member_stats_received.emit(int(fields[1]), int(fields[2]), int(fields[3]), int(fields[4]), int(fields[5]))


## 1329 玩家打玩家（原版 `handlePlayerDamageByPlayer:791-810` → `AbstractSkillEffect.applyPlayerSkillHit:331`）。
## ⚠ 服务端文本把**被打者放在最后一段**（`fake_flash_server:41485/42855/43309` 三处一致），
## 而原版二进制是"先读被打者、再 decode 七位"。本工程的文本桥按服务端实际发的这一段序解：
## `1329:<打人者>:<伤害>:<暴击>:<招号>:<招级>:<状态是否生效 true|false>:<方向>:<被打者>`。
## （`57992-58005` 那个"转回原版二进制"的桥用的也是这个段序 ⇒ 两处互相印证。）
## ⚠ 另有一条**段序不同**的发送点 `:41286`（`hub is None` 的兜底：被打者在第 1 段、第 8 段是方向）
## —— 那一支只在"场上没有别人"时发给受害者自己，按本函数解会得到一个不存在的角色号 ⇒ 什么都不画。
## 已记进 `真值/世界/PVP与合击帧.md` 的未收口，等服务端口径统一（改服务端要点头）。
func _handle_player_damage_by_player_text(fields: PackedStringArray) -> void:
	if fields.size() < 9:
		return
	for i in [1, 2, 3, 4, 5, 7, 8]:
		if not String(fields[i]).is_valid_int():
			return
	player_damage_by_player_received.emit({
		"attacker_id": int(fields[1]),
		"damage": int(fields[2]),
		"bsk": int(fields[3]) != 0,
		"skill_id": int(fields[4]),
		"skill_level": int(fields[5]),
		"skill_trigger": String(fields[6]).to_lower() == "true",
		"direction": int(fields[7]),
		"victim_id": int(fields[8]),
	})


## 1330 旁观者看到的别人血条（原版 `handlePlayerHpInfo:1081-1102`）。
## 服务端：`1330:<角色号>:<maxhp>:<hp>`（`fake_flash_server:41492/42164/43314` 等多处）。
func _handle_player_hp_text(fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	for i in range(1, 4):
		if not String(fields[i]).is_valid_int():
			return
	# 原版 `Client.as:5977-5985`：**是自己的那一条直接丢**（自己的血条走 34 状态帧，不走这里）。
	if int(fields[1]) == character_id:
		return
	player_hp_received.emit(int(fields[1]), int(fields[2]), int(fields[3]))


## 1313 双修合击（原版 `handleCoupleAttackPacket:2798-2815` → `AttackHandler.addAttack`）。
## 段序 = `CoupleAttackInfo.decode:51-66` 那 11 位；服务端 `handle_couple_attack:40728`
## 把施法者的上行**剥掉时间戳后原样广播**给同屏其他人 ⇒ 观察端收到的就是这个段序。
func _handle_couple_attack_text(fields: PackedStringArray) -> void:
	if fields.size() < 12:
		return
	couple_attack_received.emit({
		"char_id": int(fields[1]),
		"ta_id": int(fields[2]),
		"stance": int(fields[3]),
		"direction": int(fields[4]),
		"speed": int(fields[5]),
		"skill_id": int(fields[6]),
		"skill_level": int(fields[7]),
		"enemy_player_id": int(fields[8]),
		"enemy_mob_id": int(fields[9]),
		"skill_pos_x": int(fields[10]),
		"skill_pos_y": int(fields[11]),
	})


## 1825 回包。**上行与下行的子命令号不是同一张表**（`WarPanelProcessor.as`）：
## 上行 `:122/:28/:129/:89/:238/:60/:21/:96` = 0 取列表 / 1 选服进场 / 2 要收益 / 3 领全部 /
## 4 查冠军 / 5 某人资料 / 6 领冠军奖 / 7 领 3v3 奖；
## 下行 `handleWarPanelAction:213-235` = 0 频道列表 / 1 收益数 / 2 战区内经验倍率 /
## 3 冠军列表 / 4 `CharacterFullInfo` / 5 战区经验倍率 / 6 绑定神器。
## 这边只有 0 有消费者（本工程只做了频道那一扇窗，6 个下行子命令里其余 5 个的窗都没移植 ⇒ 直接丢）。
## 本机服务端另有一条**对不上**的形态：`handle_war_panel_action:21095-21098` 拿 `1825:7:<0|1>`
## 回 6/7/8 三个上行 ⇒ 原版下行**根本没有 7 这一档**（switch 无 default ⇒ 落到那儿什么也不做），
## 且 `:21090` 的 `1825:4:<角色号>` 只是一个 int、原版那一档要的是整份 `CharacterFullInfo`。
## 已记进 `真值/世界/外来帧与上行接线.md` §③，改不改等他点头。
func _handle_war_panel_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		return
	if int(fields[1]) != 0:
		return
	var 列表: Array = []
	for 行 in String(fields[2]).split("@", false):
		var 段 := String(行).split("&", true)
		if 段.size() < 3:
			continue
		列表.append({"channel_id": int(段[0]), "name": String(段[1]), "load": int(段[2])})
	if 列表.is_empty():
		return
	war_panel_received.emit(列表, int(fields[3]) if fields.size() > 3 else 0)


## 要跨服战场频道列表（原版 `WarPanelProcessor.as:122-127` `requestWarPanel_warServerList`
## = `writeByte(0)`；20 秒节流在窗那一侧 `KuaFuChannelWindow.refreshHandler:237-245`）。
func request_war_panel_list() -> bool:
	return send_game_request(OP_WAR_PANEL, "0")


## 刷新护送任务品质（原版 `QuestProcessor.as:229-232` `requestMixin_refresh(品质)` =
## `requestMixin_common(1, {"color":品质})`）。服务端 `handle_mixin:34380-34405`：护送进行中 ⇒ 回
## 「护送进行中不能刷新任务品质。」；已最高 ⇒ 回「护送任务已经是最高品质。」；否则品质 +1。
## ⚠ **这边不本地改品质**（那是服务端的账），也不猜回帧 —— 状态帧 `2325:1` 服务端只发
## **二进制原帧**（`_send_mixin_state:34540` 走 `send_original_packet`，没有文本形态）⇒ 文本桥这边收不到，
## 玩家看到的只有那两句系统消息。已记进未收口（要文本形态得改服务端，等点头）。
func request_escort_refresh(品质: int) -> bool:
	return send_game_request(OP_MIXIN, "1:{\"color\":%d}" % 品质)


## 开启护送（原版 `QuestProcessor.as:121-124` `requestMixin_startQuest` = `requestMixin_common(2, {})`）。
func request_escort_start() -> bool:
	return send_game_request(OP_MIXIN, "2:{}")


## 进战场（原版 `WarPanelProcessor.as:28-34` `requestWarPanel_selectWarServer` =
## `writeByte(1) + writeInt(channel_id)`，`KuaFuChannelWindow.enterBattleHandler:118-122` 发完就
## `onCloseBtnClick(null)` 关窗 ⇒ **这一档没有对应的应答帧**，换图由服务端另外发）。
func request_war_panel_enter(频道号: int) -> bool:
	return send_game_request(OP_WAR_PANEL, "1:%d" % 频道号)


## ── 竞技场 2306 ──────────────────────────────────────────────────────────────
## 分派表照 `PkProcessor.as:306-357` 那 12 档，字段名照五个数据类 `decode()` 的原序
## （`真值/窗口/竞技场.md` §2B 逐条对过服务端 `fake_flash_server.py:29240-29345`）。
## 行分隔 `@`、字段分隔 `&`、空表是字面量 `-`。
## ⚠ **动作 10 是唯一的例外**：服务端发之前把那一行的 `&` 换成了 `:`
## （`:29399` `.replace('&', ':')`）⇒ 这一档按 `:` 段读回那 8 个字段。
func _handle_arena_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		return
	var 动作 := int(fields[1])
	var 值: Dictionary = {}
	match 动作:
		0:
			if fields.size() < 10:
				return
			值 = _竞技场计数(fields)
			值["排名"] = int(fields[7])
			值["候选"] = _竞技场候选(fields[8])
			值["战报"] = _竞技场战报(fields[9])
		1:
			if fields.size() < 3:
				return
			值["排名"] = int(fields[2])
		2:
			值["候选"] = _竞技场候选(fields[2] if fields.size() > 2 else "-")
		3:
			值["战报"] = _竞技场战报(fields[2] if fields.size() > 2 else "-")
		4:
			if fields.size() < 7:
				return
			值 = _竞技场计数(fields)
		5, 6:
			值["秒"] = int(fields[2]) if fields.size() > 2 else 0
		7:
			值["胜"] = String(fields[2]) == "1" if fields.size() > 2 else false
			值["阅历"] = int(fields[3]) if fields.size() > 3 else 0
		8:
			值["排名"] = int(fields[2]) if fields.size() > 2 else 0
			值["阅历"] = int(fields[3]) if fields.size() > 3 else 0
		9:
			值["英雄"] = _竞技场英雄(fields[2] if fields.size() > 2 else "-")
		10:
			值["战报"] = _竞技场战报段(fields.slice(2))
			if (值["战报"] as Dictionary).is_empty():
				return
		11:
			值["排名"] = int(fields[2]) if fields.size() > 2 else 0
			值["状态"] = int(fields[3]) if fields.size() > 3 else 0
		_:
			return
	竞技场帧.emit(动作, 值)


## `PkCharInfo.decode`（`PkCharInfo.as:24-31`）前四段 + 服务端那个"距明天秒"。
## ★ 第 5 段两边语义不同（AS3 = `awardRemainSeconds`，服务端 = `_seconds_until_tomorrow()`）
## ⇒ 这边按服务端来，键名就叫 `距明天`，别当剩余领奖时间用（真值 §7-1）。
func _竞技场计数(fields: PackedStringArray) -> Dictionary:
	return {
		"已用": int(fields[2]), "上限": int(fields[3]),
		"冷却": int(fields[4]), "连胜": int(fields[5]), "距明天": int(fields[6]),
	}


func _竞技场行表(串: String) -> Array:
	if 串 == "-" or 串.is_empty():
		return []
	var 出: Array = []
	for 行 in String(串).split("@", false):
		出.append(String(行).split("&", true))
	return 出


func _竞技场候选(串: String) -> Array:
	var 出: Array = []
	for 段v in _竞技场行表(串):
		var 段: PackedStringArray = 段v
		if 段.size() < 12:
			continue
		出.append({
			"charId": int(段[0]), "pkLevel": int(段[1]), "face": int(段[2]),
			"playerLevel": int(段[3]), "name": String(段[4]),
			"inBattle": int(段[5]) == 1,
			"atk": int(段[6]), "def": int(段[7]), "bsk": int(段[8]),
			"avd": int(段[9]), "atkspeed": int(段[10]), "wlkspeed": int(段[11]),
		})
	return 出


func _竞技场战报(串: String) -> Array:
	var 出: Array = []
	for 段v in _竞技场行表(串):
		var 一 := _竞技场战报段(段v)
		if not 一.is_empty():
			出.append(一)
	return 出


## `BattleReportItem.decode`（`BattleReportItem.as:30-40`）八段；不足八段 ⇒ 空字典（调用方丢这条）。
func _竞技场战报段(段: PackedStringArray) -> Dictionary:
	if 段.size() < 8:
		return {}
	return {
		"challenger": int(段[0]), "winnerId": int(段[1]), "winnerName": String(段[2]),
		"loserId": int(段[3]), "loserName": String(段[4]),
		"timeStamp": int(段[5]), "timeIntv": int(段[6]), "resultPkLevel": int(段[7]),
	}


## `PkHero.decode`（`PkHero.as:24-31`）五段；服务端第一段发的是**排名**（占 `pkLevel` 那个位）。
func _竞技场英雄(串: String) -> Array:
	var 出: Array = []
	for 段v in _竞技场行表(串):
		var 段: PackedStringArray = 段v
		if 段.size() < 5:
			continue
		出.append({
			"pkLevel": int(段[0]), "charId": int(段[1]), "charLevel": int(段[2]),
			"name": String(段[3]), "trend": int(段[4]),
		})
	return 出


## 开面板（`PkProcessor.as:194-199` `PK_requestOpenPanel` = `writeByte(0)`）。
func request_arena_panel() -> bool:
	return send_game_request(OP_ARENA_PK, "0")


## 发起挑战（`:208-215` `PK_requestStartPk(目标id, 类型)`）。类型 0 = 真打、1 = 只看那条战报
## （`PvpPlayerPanel.as:170` / `:219`）。
func request_arena_challenge(目标id: int, 类型: int) -> bool:
	return send_game_request(OP_ARENA_PK, "1:%d:%d" % [目标id, 类型])


## 清冷却（`:201-206` `PK_requestKillCd`）。
func request_arena_clear_cooldown() -> bool:
	return send_game_request(OP_ARENA_PK, "2")


## 买一次挑战次数（`:431-438` `PK_requestAddPkCount`）。
func request_arena_add_count() -> bool:
	return send_game_request(OP_ARENA_PK, "3")


## 查英雄榜（`:54-59` `PK_searchHeroPaiHang`）。
func request_arena_heroes() -> bool:
	return send_game_request(OP_ARENA_PK, "4")


## 领排名奖（`:137-142` `PK_gainPaiHangPrize`）。
func request_arena_rank_prize() -> bool:
	return send_game_request(OP_ARENA_PK, "5")


## 清冷却并开战（`:185-192` `PK_killCdAndStart`）⇒ 服务端与 1 合用一条，只差 `clear_cooldown`。
func request_arena_clear_and_start(目标id: int, 类型: int) -> bool:
	return send_game_request(OP_ARENA_PK, "6:%d:%d" % [目标id, 类型])


func _handle_weather_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	authoritative_weather_type = int(fields[1])
	weather_received.emit(authoritative_weather_type)

func _handle_pk_mode_text(fields: PackedStringArray) -> void:
	if fields.size() < 4 or int(fields[1]) != 2:
		return
	var updated_character_id := int(fields[2])
	var mode := clampi(int(fields[3]), 1, 5)
	if updated_character_id == character_id:
		authoritative_pk_mode = mode
	pk_mode_received.emit(updated_character_id, mode)

func _handle_vip_text(fields: PackedStringArray) -> void:
	if fields.size() >= 4 and int(fields[1]) == 2:
		_apply_vip_level(int(fields[3]))

func _handle_vip_dictionary(data: Dictionary) -> void:
	var level := int(data.get("vipLevel", data.get("vip_level", data.get("level", data.get("vip", 0)))))
	_apply_vip_level(level)

func _apply_vip_from_character(character: Dictionary) -> void:
	var level := int(character.get("vipLevel", character.get("vip_level", character.get("vip", 0))))
	_apply_vip_level(level)

func _apply_vip_level(level: int) -> void:
	authoritative_vip_level = maxi(0, level)
	vip_state_received.emit(authoritative_vip_level)

func _apply_stats(result: Dictionary) -> void:
	if result.is_empty():
		return
	# 兽栏容量不是 `player_stats` 的字段（它是列表容量）⇒ 单独落到 `会话.pet_capacity`。
	# 不单独落的话：服务端把容量改成 11 了，客户端列表还按旧容量画 ⇒ 看不出扩过。
	if result.has("petCapacity"):
		var 会话 := get_node_or_null("/root/GameSession")
		if 会话 != null:
			会话.set("pet_capacity", maxi(0, int(result["petCapacity"])))
			会话.emit_signal("pets_changed", 会话.get("pets"))
		result = result.duplicate()
		result.erase("petCapacity")
	authoritative_stats.merge(result, true)
	stats_received.emit(result)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.apply_backend_character(result)


## ── 右下角「获得提示」的差值引擎 ──────────────────────────────────────────────
## 原版 `DataCenter.updatePlayerStats:2278-2293` 做两件事：**先**维护 `isInitUpdate`，
## **再**逐条 `updateOneStatu` 拿上一帧的值算差。这里 1:1 搬这两步，
## 差值该不该出、符号怎么带全在 `获得提示文案.gd`（那张表逐条带 AS3 行号）。

## `:2281-2288`：第一帧只记起点（`isInitUpdate` 仍是 true）；之后**再有帧进来**且距起点
## 超过 5000ms，才把它翻成 false。注意是"来帧才翻"，不是定时器 —— 别改成 timeout。
func _记属性帧() -> void:
	var 现在 := Time.get_ticks_msec()
	if _首帧属性毫秒 == 0:
		_首帧属性毫秒 = 现在
	elif _初更新 and 现在 - _首帧属性毫秒 > 初始化窗口毫秒:
		_初更新 = false


## 单条属性 → **两处**输出：右下角那一列 + 角色头顶飘字。
## 原版 `updateOneStatu` 每个 `case` 的形状都是「**先减旧值** → 判 → `player_addAttriChangeTip`
## + `addNotice` → **最后才把新值写进 `this.stats.X`**」⇒ 基准必须在同一条链里记，
## 而且记基准那句在 `isInitUpdate` 判断**之外**（进游戏那 5 秒照样打底）。
func _报属性提示(字段号: int, 新值: float) -> void:
	var 会列 := 获得提示文案.会提示(字段号)		# 右下角那一列出不出
	var 会飘 := 头顶飘字规则.会飘(字段号)		# 头顶飘不飘
	## 两处都不出的字段（等级/职业/point 之类）⇒ 连基准都不存，照原版。
	if not 会列 and not 会飘:
		return
	var 键 := str(字段号)
	var 旧值 = _提示旧值.get(键)
	_提示旧值[键] = 新值
	if 旧值 == null:
		return
	## 原版是 `int` 变量的减法（`:2434` `_loc4_ = param1.value - this.stats.experience`）：
	## **先减再取整**，不是各取整再减（经验在协议里是 float，两种算法能差 1）。
	var 差 := int(新值 - float(旧值))
	if 差 == 0:
		return
	## 右下角那一列：12 档**全部**吃 `isInitUpdate`（判据在文案层，这里只挡那 5 秒）。
	if 会列 and not _初更新:
		## 判空**必须留在这里再做一次**：经验那一族原版只在"变多"时提示（`if(_loc4_ > 0)`），
		## 变少时文案层给的是空串 —— 直接 emit 会在右下角挂出一行**空行**（2026-10-10 探针抓到）。
		var 文本 := 获得提示文案.属性(字段号, 差)
		if 文本 != "":
			获得提示.emit(文本)
	## 头顶那一族：**逐档**判吃不吃那个抑制 —— MP 那一档原版漏了那个判断（`:2485-2490`），
	## 所以不能像上面那样在这一层统一挡掉，得把 `_初更新` 交给规则表自己按档决定。
	if 会飘:
		var 条 := 头顶飘字规则.飘字(字段号, 差, _初更新)
		if not 条.is_empty():
			属性飘字.emit(String(条["前缀"]), int(条["数值"]), bool(条["是增"]), 条["颜色"] as Color)


## 元宝（`Client.onCashMoneyInfo:9062-9070`）：差 != 0 就提示，同样吃 `isInitUpdate`。
## 原版那个 5 秒起点是**属性帧**建的，元宝帧自己不开新起点 ⇒ 这里也只读 `_初更新`。
func _报元宝提示(新值: int) -> void:
	var 旧值 = _提示旧值.get("元宝")
	_提示旧值["元宝"] = 新值
	if 旧值 == null or _初更新:
		return
	获得提示.emit(获得提示文案.元宝(int(新值 - int(旧值))))


## 背包一条获得/失去提示（`ItemManager` 那 5 处 `addNotice`）。文案空 = 原版判掉了。
func _提示物品(文本: String) -> void:
	if 文本 == "":
		return
	获得提示.emit(文本)

func _handle_skill_dictionary(data: Dictionary) -> void:
	_apply_skill(int(data.get("skillId", -1)), int(data.get("level", 0)), int(data.get("masterLevel", data.get("master_level", 0))))
	if data.has("remainingSp"):
		_apply_stats({"remainingSp": int(data.remainingSp)})

func _handle_skill_text(fields: PackedStringArray) -> void:
	if fields.size() >= 4:
		_apply_skill(int(fields[1]), int(fields[2]), int(fields[3]))
		return
	if fields.size() < 2:
		return
	# PacketBuilder.BuildUpdateSkillPacket 使用 39:id&level&masterLevel。
	for encoded_skill in String(fields[1]).split("@", false):
		var values := encoded_skill.split("&", false)
		if values.size() >= 3:
			_apply_skill(int(values[0]), int(values[1]), int(values[2]))

func _apply_skill(skill_id: int, level: int, master_level: int) -> void:
	if skill_id < 0:
		return
	var 旧: Dictionary = authoritative_skills.get(skill_id, {}) as Dictionary
	## 熟练度增量 = 新 − 旧。**第一次见到这条技能时差必须是 0** —— 原版 `updateSkill`
	## 对"表里本来没有"那一条只 `push` 进 `skillInfoList`，不飘字（`:1592` 在 else 分支）。
	var 差 := master_level - int(旧.get("master_level", master_level))
	authoritative_skills[skill_id] = {"level": level, "master_level": master_level}
	if 差 > 0:
		var 名 := 心法名(skill_id)
		## `名 != ""` 就是原版的 `SkillDataTool.isSkillXinfa()`（心法表 = GameData
		## `info.desc.xinfa == 1` 那 21 条）。涨层 ⇒ 头顶蓝字 + 右下角一行，同一个 if 里两件事。
		if 名 != "":
			心法熟练度增加.emit(名, 差)
			_提示物品(获得提示文案.心法熟练度(名, 差))
	skill_received.emit(skill_id, level, master_level)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.apply_backend_skill(skill_id, level, master_level)


## 心法的显示名（非心法返回空串 = 原版那句 `isSkillXinfa` 为假）。
## 名字与"是不是心法"同一张表：`数据/界面/心法表.json`（生产链从 GameData 解出来的 21 条，
## 键 = `ImgUtil.getSkillNumName()` 那套 7 位补零符号名 ⇒ 与原版 `StringTool.getSkillString` 同源）。
## 懒加载：不进图的页（登录/选角）不该为这张表付一次解析。
static var _心法名表: Dictionary = {}


static func 心法名(号: int) -> String:
	if _心法名表.is_empty():
		var 表: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://数据/界面/心法表.json"))
		if 表 is Dictionary and (表 as Dictionary).has("条目"):
			var 条: Dictionary = (表 as Dictionary)["条目"] as Dictionary
			for 键 in 条.keys():
				_心法名表[int(String(键))] = String((条[键] as Dictionary).get("名称", ""))
	return String(_心法名表.get(号, ""))

## 原版 CharacterWarpInfo 的 skillInfoList 文本形态："<id>&<lvl>&<master>@<id>&<lvl>&<master>…"，
## 无忍术时为 "-"（服务端 _encode_skill_list）。Python 服务端进入游戏时不补发 39 帧，
## 已学忍术只在 WARP_CHAR_INFO 的 legacy 字段序第 41 项下发。
func _apply_skill_list_text(blob: String) -> void:
	if blob.is_empty() or blob == "-":
		return
	for entry in blob.split("@", false):
		var values := entry.split("&", false)
		if values.size() < 3:
			continue
		_apply_skill(int(values[0]), int(values[1]), int(values[2]))

func _apply_map_state(map_id: int, x: int, y: int, hp: int) -> void:
	_switch_authoritative_map(map_id)
	authoritative_position = Vector2(x, y)
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.apply_backend_map_state(map_id, x, y, hp)

func _switch_authoritative_map(map_id: int) -> void:
	if map_id <= 0 or map_id == authoritative_map_id:
		return
	authoritative_map_id = map_id
	map_players.clear()
	map_monsters.clear()
	map_npcs.clear()
	npc_quest_status.clear()		# 标记按 object_id 存，换图必清（新图会重发一轮 513）
	map_drops.clear()
	_pending_skill_hits.clear()
	_player_spawn_order.clear()
	_monster_spawn_order.clear()

func _record_entity_spawn(source: String, entity_id: int) -> void:
	_entity_spawn_sequence += 1
	if source == "player":
		_player_spawn_order[entity_id] = _entity_spawn_sequence
	else:
		_monster_spawn_order[entity_id] = _entity_spawn_sequence

func _handle_login_status_value(login_status: int) -> void:
	login_status_received.emit(login_status)
	match login_status:
		0:
			authenticated = true
			_set_status("已登录", "账号验证成功，正在读取角色")
		1:
			authenticated = true
			_set_status("需要角色", "该账号尚未创建角色")
		2:
			_fail_connection("账号验证失败")
		3:
			_fail_connection("账号已被封禁")
		4:
			_fail_connection("账号或密码错误")
		5:
			_fail_connection("账号不存在")
		_:
			_fail_connection("登录失败（状态 %d）" % login_status)

func _handle_character_list_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var count := int(fields[1])
	var max_characters := int(fields[2])
	var offset := 3
	characters.clear()
	for _index in count:
		if offset + 29 > fields.size():
			_fail_connection("角色列表文本格式异常")
			return
		characters.append({
			"id": int(fields[offset]), "name": String(fields[offset + 1]),
			"gender": int(fields[offset + 2]), "skinColor": int(fields[offset + 3]),
			"face": int(fields[offset + 4]), "hair": int(fields[offset + 5]),
			"level": int(fields[offset + 6]), "job": int(fields[offset + 7]),
			"apAtk": int(fields[offset + 8]), "apDef": int(fields[offset + 9]),
			"apDex": int(fields[offset + 10]), "apPhy": int(fields[offset + 11]),
			"hp": int(fields[offset + 12]), "maxHp": int(fields[offset + 13]),
			"mp": int(fields[offset + 14]), "maxMp": int(fields[offset + 15]),
			"remainingAp": int(fields[offset + 16]), "remainingSp": int(fields[offset + 17]),
			"exp": float(fields[offset + 18]), "fame": int(fields[offset + 19]),
			"mapId": int(fields[offset + 20]), "vip": fields[offset + 24] == "true",
			"shengwang": int(fields[offset + 25]), "crime": int(fields[offset + 26]),
			"charType": int(fields[offset + 27]), "lingFace": int(fields[offset + 28]),
		})
		offset += 29
	character_list_received.emit(characters.duplicate(true), max_characters)
	if _auto_select_character and not characters.is_empty():
		var character: Dictionary = characters[0]
		character_received.emit(character)
		var session := get_node_or_null("/root/GameSession")
		if session != null:
			session.apply_backend_character(character)
		select_character(int(character.id))

func _handle_spawn_player_text(fields: PackedStringArray) -> void:
	if fields.size() < 17:
		return
	var state := {
		"character_id": int(fields[1]), "name": String(fields[2]), "job": int(fields[3]),
		"gender": int(fields[4]), "skin_color": int(fields[5]), "face": int(fields[6]),
		"hair": int(fields[7]), "x": int(fields[14]), "y": int(fields[15]),
		## 第 17 段是 movement_flag（1=爬 2=落地），**不是朝向** —— 原版 162 里根本没有朝向，
		## 人物朝向由之后的移动帧决定（`Character` 的 faceLeft 是移动时刷的），所以这里照原样存。
		"direction": int(fields[16]),
		"movement_action": int(fields[17]) if fields.size() > 17 else 0,
		"level": int(fields[19]) if fields.size() > 19 else 1,
		## ⚠ 第 23/24 段是**家族号与家族名**（服务端 `_foreign_player_payload:15188-15230` 里
		## `_account_family_id()` / `_current_family_name()` 那两格）。以前这里读到 fields[28]
		## 就直接收尾、把这两段跳过了 ⇒ 双修邀请窗那行「家族：」永远空着
		## （原版那一行读的是 `dataCenter` 里那个人的 guildName = 就是这一段）。
		## 没家族服务端发的是字面 `-` ⇒ 原样存，显示侧自己当"没有"。
		"family_id": int(fields[22]) if fields.size() > 22 else 0,
		"family_name": String(fields[23]) if fields.size() > 23 else "",
		"char_type": int(fields[28]) if fields.size() > 28 else 0,
		"map_id": authoritative_map_id,
	}
	map_players[state.character_id] = state
	_record_entity_spawn("player", state.character_id)
	player_spawned.emit(state)

func _handle_remove_map_entity_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var entity_id := int(fields[1])
	var has_player := map_players.has(entity_id)
	var has_monster := map_monsters.has(entity_id)
	if not has_player and not has_monster:
		return
	var remove_player := has_player and not has_monster
	if has_player and has_monster:
		remove_player = int(_player_spawn_order.get(entity_id, -1)) >= int(_monster_spawn_order.get(entity_id, -1))
	if remove_player:
		map_players.erase(entity_id)
		_player_spawn_order.erase(entity_id)
		player_removed.emit(entity_id)
	else:
		map_monsters.erase(entity_id)
		_monster_spawn_order.erase(entity_id)
		monster_removed.emit(entity_id)

func _handle_move_player_text(fields: PackedStringArray) -> void:
	## ⚠ **字段序以服务端实际拼串为准**，两处同源（`fake_flash_server.py` 项目内那份）：
	##   · `handle_move()` 的广播 `34705-34724` ⇒ `187:<command>:<character_id>:<type>:<type>:<x>:<y>:<速度x>:…`
	##   · 服务端自己的「文本→原版」翻译器 `61159-61200` ⇒ 同一串里 `fields[2]=character_id`、
	##     `fields[5]/[6]=x/y`、`fields[7]=速度x`（注释原话 "Derive facing from the fragment velocity"）。
	## 这里以前按 `187:<charId>:<x>:<y>:<state>` 读（少认一段 command）⇒ charId 读成 0、
	## x 读成对方的角色编号、y 读成移动类型，`map_players` 里查不到键 0 就整帧扔掉 ——
	## **对面的位置永远停在进图那一刻**：两个号各走各的、屏幕上互相看不见
	## （用户 2026-10-14 报「同一个地图谁都看不到对面」）。同族的 241 怪物移动一直是按
	## `opcode:0:id:…` 读的，只有这一条偏了一格。
	if fields.size() < 7:
		return
	var 编号 := int(fields[2])
	var x := int(fields[5])
	var y := int(fields[6])
	var 速度x := int(fields[7])
	## 第 11 段是**动作号**（`PLAYER_MOVEMENT_ACTION_*`：站立1/跳2/走3/爬梯4/爬绳5/打坐7，
	## 出处 `fake_flash_server.py:111-118`；广播里它在 `handle_move():34706` 那段拼串的
	## `self._safe_int(fields[2], 0)` 位）。对面播不播走路帧就看这一格。
	var 动作 := int(fields[10]) if fields.size() > 10 else 0
	var 旧: Variant = map_players.get(编号)
	var 朝向 := int(旧.direction) if 旧 is Dictionary else 1
	## ★ 第 12 段是**发帧那一端自己的朝向**（`Character` 的采样帧里就有 `direction` 这一格，
	## 收端 `CommandController` 直接照它转身）。给了就以它为准 —— 以前只能"按速度符号推"，
	## 于是**站着不动的人停在上一次移动的那个朝向**：双修时他该朝左、屏幕上却还朝右（10-17）。
	## 老客户端不发 ⇒ 读到 0 = "没给"，退回下面那两条推算，不会把所有人刷成朝右。
	var 广播朝向 := int(fields[11]) if fields.size() > 11 else 0
	if 广播朝向 != 0:
		朝向 = 广播朝向
	elif 速度x != 0:
		朝向 = -1 if 速度x < 0 else 1
	elif 旧 is Dictionary and x != int(旧.x):
		## 速度槽没给（我们自己发的 `36:x:y:朝向` 就只有三段，服务端在那一格补 0）⇒
		## 按位移推，和服务端维护自己 `self.direction` 是同一条规则（`x 变大 = 朝右`）。
		朝向 = 1 if x > int(旧.x) else -1
	var state := {
		"character_id": 编号, "x": x, "y": y,
		"direction": 朝向,
		"movement_action": 动作,
		## ⚠ **`velocity_x` 必须给**（2026-10-14）：`地图实体._on_server_player_moved()` 拿它
		## 当"两包之间按什么速度往前走"的那个数（原版 `CommandController.as:56` 把片段的
		## `pixelsPerSecond` 交给角色自己的物理）。这一格以前**根本没往 state 里放** ⇒
		## 收端永远拿到 0 ⇒ 外推那条一整段是死的 ⇒ 只能靠"追点"，稳态永远欠几十毫秒 ——
		## 用户实机那句"延迟还是很大"就是它。`velocity_y` 一直在，所以只有横向坏，看不出来。
		"velocity_x": 速度x,
		"velocity_y": int(fields[8]),
		"movement_state": int(fields[4]),
	}
	if 旧 is Dictionary:
		(旧 as Dictionary).merge(state, true)
	player_moved.emit(state)

func _handle_close_range_attack_text(fields: PackedStringArray) -> void:
	## 40 = 服务端转发过来的**别人的一次普攻**（`handle_attack()` 开头新加的那条 `_send_visible`）。
	## 段序与我们自己发出去的那套一致（见 `request_basic_attack()` 的注释）：
	## `[2]`角色编号、`[11]`stance（动作号，普攻=11）、`[12]`朝向。
	## ⚠ **只演动作，绝不算伤害** —— 伤害照旧由服务端自己的回包（243/252/239）说，
	## 这里碰血量就会把"客户端自算伤害"那条老路重新引回来。
	if fields.size() < 13:
		return
	player_cast.emit({
		"character_id": int(fields[2]),
		"stance": int(fields[11]),
		"direction": int(fields[12]),
		"skill_id": 0, "x": 0, "y": 0,
	})

func _handle_player_attack_text(fields: PackedStringArray) -> void:
	## 1328 的文本形状 = 服务端 `_send_player_attack_info()`（项目内那份 `:15466`）：
	## `1328:<charId>:<attack>:<defence>:<critical>:<evasion>:<stance>:<direction>:<speed>
	##  :<skillId>:<skillLevel>:<x>:<y>:<players@>:<monsters@>:-:-:<tag>`
	## `stance` 就是出手动作号（`Action.as:6` 那张表：11=attack、12~14=stab1~3、6=alert）。
	if fields.size() < 8:
		return
	player_cast.emit({
		"character_id": int(fields[1]),
		"stance": int(fields[6]),
		"direction": int(fields[7]),
		"skill_id": int(fields[9]) if fields.size() > 9 else 0,
		"x": int(fields[11]) if fields.size() > 11 else 0,
		"y": int(fields[12]) if fields.size() > 12 else 0,
		## 被打中的是谁（`@` 分隔）—— 旁观者要拿它把**飞行物**指到那只怪/那个人身上，
		## 否则只有一团起手特效、看不到球飞出去（用户 2026-10-14："看不到技能特效"）。
		"players": String(fields[13]) if fields.size() > 13 else "-",
		"monsters": String(fields[14]) if fields.size() > 14 else "-",
	})

func _handle_spawn_monster_text(fields: PackedStringArray) -> void:
	if fields.size() < 16:
		return
	## ★ **竞技场对手那一支**：服务端把对手做成一只"权威怪"（血量/伤害/选中都走怪物那条账），
	## 但第 1 段发的是字面量 `arena-player`、后面挂的是**玩家**的字段
	## （`服务端/runtime/tools/fake_flash_server.py:29490-29533`，共 26 段：
	##  2=oid 4=肤色 5=图 6/7=坐标 9/10=落脚点 14/15=出生 16=头像 17=等级 18=名字
	##  19=攻速 20=移速 21=招式 22=装备 23=灵面 24=灵色 25=神器）。
	## 按普通怪读会把 `int("arena-player")=0` 当 spawn_type、把**肤色**当模板号、把招式串当精英串
	## ⇒ 进图后对手根本不成形。
	if String(fields[1]) == "arena-player":
		_arena_对手帧(fields)
		return
	var state := {
		"spawn_type": int(fields[1]), "object_id": int(fields[2]), "monster_id": int(fields[4]),
		"map_id": int(fields[5]), "x": int(fields[6]), "y": int(fields[7]),
		"direction": 0, "new_spawn": fields[12] == "true",
		# 精英属性 = **`fields[19]`**（不是 18）。逐段数过服务端 `_monster_spawn_payload`
		# （`服务端/runtime/tools/fake_flash_server.py:17673-17681`）：
		# `0=op 1='1' 2=oid 3='0' 4=模板号 5=图 6=x 7=y 8='0' 9=落脚点 10=落脚点 11='0'
		#  12='true' 13=first_attack 14=出生x 15=出生y 16='0' 17='0' 18='-' 19=精英串`
		# ⇒ 第 18 段恒为字面量 `"-"`，拿它当精英就是"在线怪永远没有精英"
		#   （`战斗角色.gd:459` 的血量乘子与 `玩家.gd:304` 全都静默退化）。
		# 原版 `Monster.clientCombatMaxHp:846-863` 正是拿这一串乘最大血量 —— 不读的话
		# 精英/BOSS 的分母偏小，目标框与世界血条的比例全错。
		"jingying": _解析精英(fields[19]) if fields.size() > 19 else [],
		## 落脚点号（服务端把同一个值写了两遍：9 与 10）。**仅作对照**：挑怪判"同不同层"
		## 走我们自己的烘焙落脚点表反查（`地表.find_foothold`），因为那套 id 与玩家
		## `current_fh_id` 同源，拿服务端的号来比是两套编号互相顶。
		"foothold": int(fields[9]) if fields.size() > 9 else -1,
		## `attackedByMob` = **第 23 段**（`_monster_spawn_payload:17678` 的
		## `monster.attacked_by_mob`；原版 `MonsterSpawnInfo.as:125 readBoolean()`）。
		## 挂机挑怪要排掉它为真的怪（`SkillHandler.canAttack:447-450`）。
		"attacked_by_mob": (String(fields[23]) == "true") if fields.size() > 23 else false,
	}
	map_monsters[state.object_id] = state
	_record_entity_spawn("monster", state.object_id)
	monster_spawned.emit(state)

## 竞技场对手帧 → `monster_spawned`。**沿用怪物那一本账**（object_id / 落脚点 / 权威血量 /
## 位移帧全照怪物走），这样选中、追打、掉血、死亡一条都不必另写；另外把玩家的样子挂在
## `对手` 上，只用来**画**与头顶显示，不参与任何结算（那是服务端的账）。
func _arena_对手帧(fields: PackedStringArray) -> void:
	if fields.size() < 19:
		return
	var 招: Array = []
	for 项 in String(fields[21] if fields.size() > 21 else "-").split("@", false):
		var 两段 := String(项).split("&", false)
		if 两段.size() >= 2:
			招.append({"id": int(两段[0]), "level": int(两段[1])})
	var 装: Array = []
	for 项 in String(fields[22] if fields.size() > 22 else "-").split("@", false):
		var 两段 := String(项).split("&", false)
		if 两段.size() >= 2:
			装.append({"position": int(两段[0]), "item_id": String(两段[1])})
	var 神: Array = []
	for 项 in String(fields[25] if fields.size() > 25 else "-").split("@", false):
		if String(项).is_valid_int():
			神.append(int(项))
	var object_id := int(fields[2])
	var 状态 := {
		"spawn_type": 1, "object_id": object_id, "monster_id": 0,
		"map_id": int(fields[5]), "x": int(fields[6]), "y": int(fields[7]),
		"direction": 0, "new_spawn": fields[12] == "true",
		"foothold": int(fields[9]) if fields.size() > 9 else -1,
		"jingying": [], "attacked_by_mob": false,
		"spawn_x": int(fields[14]), "spawn_y": int(fields[15]),
		"对手": {
			"face": int(fields[16]), "level": int(fields[17]), "name": String(fields[18]),
			"attack_speed": int(fields[19]) if fields.size() > 19 else 0,
			"walk_speed": int(fields[20]) if fields.size() > 20 else 0,
			"skills": 招, "equipment": 装,
			"ling_face": int(fields[23]) if fields.size() > 23 else 0,
			"ling_color": int(fields[24]) if fields.size() > 24 else 0,
			"shenqi": 神, "skin_color": int(fields[4]),
		},
	}
	map_monsters[object_id] = 状态
	_record_entity_spawn("monster", object_id)
	monster_spawned.emit(状态)


## 精英属性段格式：`"attrType&value@attrType&value…"`，没有精英属性时是 `"-"`。
func _解析精英(字段: String) -> Array:
	if 字段.is_empty() or 字段 == "-":
		return []
	var 结果: Array = []
	for 项 in 字段.split("@", false):
		var 两段 := 项.split("&", false)
		if 两段.size() >= 2:
			结果.append({"attr_type": int(两段[0]), "value": int(两段[1])})
	return 结果

func _handle_kill_monster_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var object_id := int(fields[1])
	var animation := int(fields[2]) if fields.size() > 2 else 0
	map_monsters.erase(object_id)
	_monster_spawn_order.erase(object_id)
	monster_killed.emit(object_id, animation)

## `237:<物品号>:<冷却档>:<秒>` —— 原版 `ITEM_COOLDOWN`（`ReceiveOpCodes.as:88`）。
## 真值 `AllInOneProcessor.handleItemCooldownPacket:537-565`：**秒 > 0** ⇒ `onItemCooldown`
## → `DataCenter.setItemsCoolWithCoolType`（格子盖一层倒计时）；**秒 <= 0** ⇒ `onItemCooldownCancel`
## → `SkillHandler.cancelItemCooltime`。服务端一共六处发它（`fake_flash_server.py:50336/50394/`
## `50540/50551/50620`），其中**四处是"这次使用被拒"的取消帧**：五行封印、竞技场内、
## 共享药剂 CD 中、**血/蓝已满**（`:50540-50551` 那条还连致一帧权威资源）。
## 2026-10-17 巡检 #20-C：客户端原来**整条不接**（全工程没有 237 的分支）⇒ 这些拒绝在玩家那头
## 是纯静默 no-op —— 双击血药什么也没发生，也没有原版那句「你的血值已经满了!」。
## ⚠️ 档（coolType）在原版是"同一档共享一个 CD"的键，服务端这里恒 0；服务端另有
## `item_cooldowns[-1]` 那份**共享** 0.5 秒（`ITEM_PUBLIC_COOLDOWN_SECONDS:11072`），
## 但它只报被点那一件的号 ⇒ 客户端学不到，只能在下一件药剂的取消帧里被动清。
var item_cooldown_until := {}

## 秒 > 0 时的剩余（给格子遮罩/提示用；0 = 好了）。
signal 物品冷却变更(物品号: int, 剩余秒: int)


func _handle_item_cooldown_text(fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	var 物品号 := int(fields[1])
	var 剩余秒 := int(fields[3])
	if 剩余秒 > 0:
		item_cooldown_until[物品号] = Time.get_ticks_msec() + 剩余秒 * 1000
	else:
		item_cooldown_until.erase(物品号)
	物品冷却变更.emit(物品号, maxi(0, 剩余秒))


## 本地那一秒的闸（原版 `SkillHandler.isItemCooling:777-784`）。到期就顺手清掉 ——
## 这件没人再点的话没必要留着，也省一个定时器。
func 物品冷却中(物品号: int) -> bool:
	var 到期 = item_cooldown_until.get(物品号, null)
	if 到期 == null:
		return false
	if Time.get_ticks_msec() >= int(到期):
		item_cooldown_until.erase(物品号)
		return false
	return true


func _handle_move_monster_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	if int(fields[1]) == 1:
		_handle_monster_attack_text(fields)
		return
	if int(fields[1]) != 0:
		return
	if fields.size() < 18:
		return
	# ⚠️ 第 12 段（fields[11]）**不是时长** —— 服务端 `_broadcast_monster_movement` 那一串里
	# 它就是常量 0。原来我们把它当 `duration_ms` 用，`max(1, 0)` = **1 毫秒** →
	# 补间 0.001 秒 → 怪**瞬移**（用户 2026-09-27 报的第 1 条）。
	# 服务端给的其实是**速度**：`[7]vx [8]vy [5][6] 起点 [10] 移动状态 [12] 脚点`，
	# 原版客户端 `onMoveMonster` → `addMonsterMovement()` 把它当移动段播。
	# 两个包之间客户端要**自己按速度积分**（服务端只在移动段变化时才发）。
	var state := {
		"object_id": int(fields[2]),
		"start_x": int(fields[5]), "start_y": int(fields[6]),
		"vx": int(fields[7]), "vy": int(fields[8]),
		"direction": -1 if (int(fields[10]) & 1) == 1 else 1,
		"foothold": int(fields[12]),
	}
	if map_monsters.has(state.object_id):
		map_monsters[state.object_id].merge(state, true)
	monster_moved.emit(state)

func _handle_monster_attack_text(fields: PackedStringArray) -> void:
	if fields.size() < 12:
		return
	var targets: Array[int] = []
	for value in String(fields[9]).split("@", false):
		var target_id := int(value)
		if target_id > 0:
			targets.append(target_id)
	monster_attacked.emit({
		"object_id": int(fields[2]), "action": int(fields[3]),
		"direction": int(fields[4]), "skill_id": int(fields[5]),
		"skill_level": int(fields[6]), "x": int(fields[7]), "y": int(fields[8]),
		"target_character_ids": targets,
	})

func _handle_damage_monster_text(fields: PackedStringArray) -> void:
	# 243 = 原版的 `DAMAGE_MONSTER`，只有 `(mobId, damage)` 两 int（`Client.as:9961`
	# `onDamageMonster(int,int)` → `MonsterHandler.addMonsterDamage` 一律画白字 `MOB_HP_COMMON`）。
	# **这条帧上没有暴击位** —— 玩家的出手结算（含 `damage*bsk`）走 184（见
	# `_handle_mob_attack_info_text`）。这里收到的是 DoT/相位伤这类"非出手"的数字，永远非暴击。
	if fields.size() >= 3:
		var object_id := int(fields[1])
		var damage := int(fields[2])
		# 243 这条是 DoT/相位跳伤（原版 `onDamageMonster(int,int)`），只画数字、不播受击动画
		monster_damaged.emit(object_id, damage, false, false, false, true)
		var pending: Dictionary = _pending_skill_hits.get(object_id, {})
		_pending_skill_hits.erase(object_id)
		if not pending.is_empty() and int(pending.get("expires_at", 0)) >= Time.get_ticks_msec():
			monster_skill_hit.emit(object_id, int(pending.get("skill_id", 0)), damage)

## 出手结算帧（服务端 `_send_mob_attack_result`；原版 `AttackInfo` 的文本桥形态）。
## 字段序（**含 opcode**，`_handle_bridge_text` 的 `split(":")` 不剥头，和别的 handler 一样）：
##   [0]184 [1]isPlayer [2]characterId [3]petUid [4]level [5]damageCount [6]hitCount
##   [7]skillTrigger [8]skillLevel [9]skillId [10]stance [11]direction
##   [12]hits = `objId&alive&damage*bsk`（多目标 `@` 连接；去掉 opcode 就是
##   `MobDamage`/`MobDamageItem` 的字段序）
## ⭐ 这就是原版**伤害数字（含暴击红字）的真身**：`AbstractSkillEffect.applySkillHitMob`
##    拿 `MobDamageItem(damage, bsk)` 走 `player_addAttriChangeTip` ——
##    `MOB_HP_COMMON` 白 / `MOB_HP_BSK`(16711680) 红（`Monster.as` 402-430）。
##    我们以前**根本没接 184**：在线普攻不弹任何数字、技能数字只在 DoT 的 243 上偶然出现。
func _handle_mob_attack_info_text(fields: PackedStringArray) -> void:
	if fields.size() < 13:
		return
	var skill_id := int(fields[9])
	for 段 in String(fields[12]).split("@", false):
		var 部 := 段.split("&", false)
		if 部.size() < 3:
			continue
		var object_id := int(部[0])
		if object_id <= 0:
			continue
		var 伤害串 := String(部[2]).split("*", false)
		var damage := int(伤害串[0]) if 伤害串.size() > 0 else 0
		# `MobDamageItem(damage, bsk)` 的第二位就是暴击位（原版 `readByte`）
		var 暴击 := 伤害串.size() > 1 and int(伤害串[1]) != 0
		# 184 = 出手命中，要播受击动画（第 4 参 true）
		# `objId&alive&damage*bsk` 的第二位 = 这一包打完怪**还活着吗**（击飞判据要），
		# `isPlayer[1] + characterId[2]` 两位合起来才是原版的"是玩家自己打出的"（震屏判据要）。
		## ⚠ alive 位服务端发的是**文本 `true`/`false`**（`fake_flash_server.py:44177`
		## 的 `str(result.monster.hp > 0).lower()`），不是 0/1 —— 同一行的 `damage*bsk` 才是数字。
		## 用 `int()` 解会把 `"true"` 读成 0 ⇒ **每一发都当成"已死"**：在线只要暴击就把活怪打飞、
		## 而"打死了才击飞"这条判据整条失效（2026-10-11 新增协议门当场逮到）。
		## 解析口径照工程既有的 `_parse_bool_list`（`:3390`）：`true`/`1` 算真。
		var 活着 := true
		if 部.size() > 1:
			var 活串 := String(部[1]).strip_edges().to_lower()
			活着 = 活串 == "true" or 活串 == "1"
		monster_damaged.emit(object_id, damage, 暴击, true,
				int(fields[1]) == 1 and int(fields[2]) == int(character_id), 活着)
		if skill_id > 0:
			monster_skill_hit.emit(object_id, skill_id, damage)
			_pending_skill_hits.erase(object_id)
		var pending: Dictionary = _pending_skill_hits.get(object_id, {})
		_pending_skill_hits.erase(object_id)
		if not pending.is_empty() and int(pending.get("expires_at", 0)) >= Time.get_ticks_msec():
			monster_skill_hit.emit(object_id, int(pending.get("skill_id", 0)), damage)

func _handle_monster_hp_text(fields: PackedStringArray) -> void:
	if fields.size() >= 3:
		monster_hp_changed.emit(int(fields[1]), clampi(int(fields[2]), 0, 100))

func _handle_spawn_npc_text(fields: PackedStringArray) -> void:
	if fields.size() < 9:
		return
	var state := {
		"object_id": int(fields[1]), "npc_id": int(fields[2]), "x": int(fields[3]),
		"y": int(fields[4]), "rx0": int(fields[5]), "rx1": int(fields[6]),
		"direction": int(fields[7]), "foothold": int(fields[8]), "map_id": authoritative_map_id,
	}
	map_npcs[state.object_id] = state
	npc_spawned.emit(state)

func _handle_drop_item_text(fields: PackedStringArray) -> void:
	if fields.size() < 13:
		return
	var state := {
		"object_id": int(fields[1]), "is_meso": fields[2] == "true", "item_id": int(fields[3]),
		"item_name": GAME_DATA.item_name(fields[3]), "owner_id": int(fields[6]),
		## 原版 `ItemDropInfo.decode():62-75` 的字段序是
		## `oid, isMeso, itemId, touchUp, equipAptitude, ownerCharId, ...`
		## ⇒ fields[4] 就是 `touchUp`（**身体碰到就自动捡**，原版这种不给鼠标事件）。
		## 原先这里没读 ⇒ 这一档整个丢了，所有掉落物都变成"只能点"。
		"touch_up": fields[4] == "true",
		## `equipAptitude` = **`fields[5]`**（金币时为 0；服务端 `:46993-47007` 那一串里就在
		## `touchUp` 之后、`ownerCharId` 之前）。原先整段没读 ⇒ 挂机窗那枚「拾取品质」
		## 没有任何数据可判（`数据/物品.json` 里也**没有**品质字段，只能吃这一帧）。
		## 数值口径与背包里的装备同源：`装备品质.档(资质)`（1白…6金）。
		"aptitude": int(fields[5]) if fields.size() > 5 else 0,
		"x": int(fields[7]), "y": int(fields[8]), "from_x": int(fields[9]),
		"from_y": int(fields[10]), "drop_mode": int(fields[11]), "foothold": int(fields[12]),
		"map_id": authoritative_map_id,
	}
	map_drops[state.object_id] = state
	map_drop_spawned.emit(state)

func _handle_remove_drop_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	## 字段序 = 服务端 `fake_flash_server.py:58068` 打的那串，也是原版
	## `RemoveItemInfo.decode()`：`273 : animation : oid : pet : cid [: slot]`
	var object_id := int(fields[2])
	var 动画 := int(fields[1])
	var 是宠物 := fields[3].to_lower() in ["1", "true"] if fields.size() > 3 else false
	var 角色号 := int(fields[4]) if fields.size() > 4 else 0
	map_drops.erase(object_id)
	map_drop_removed.emit(object_id, 动画, 角色号, 是宠物)

func _handle_damage_player_text(fields: PackedStringArray) -> void:
	if fields.size() < 9:
		return
	var state := {
		"character_id": int(fields[1]), "skill_id": int(fields[2]),
		"skill_trigger": fields[3] == "true", "damage": int(fields[4]),
		"monster_action": int(fields[5]), "monster_object_id": int(fields[6]),
		"hit_flag": int(fields[7]), "fake": int(fields[8]),
	}
	player_damaged.emit(state)
	if int(state.character_id) == character_id:
		acknowledge_damage(int(state.monster_object_id), int(state.damage))

## 1291 的两条子命令各发一条信号；段数不够（老端/噪声）整条丢，不拿默认值凑半个真状态。
func _handle_lianzhan_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		return
	match int(fields[1]):
		1:
			if fields.size() >= 3 and String(fields[2]).is_valid_int():
				lianzhan_count_changed.emit(int(fields[2]))
		2:
			if fields.size() >= 7:
				lianzhan_stage_changed.emit(int(fields[2]), int(fields[3]),
						int(fields[4]), int(fields[5]), int(fields[6]))

## 199 换装/变身回帧。段数不够（老端、噪声）**整条丢** ⇒
## 绝不拿默认值凑半个样子：凑出来的会是"裸体"或"半身穿帮"，比不变更难查。
func _handle_char_look_text(fields: PackedStringArray) -> void:
	if fields.size() < 12:
		return
	if not String(fields[1]).is_valid_int() or not String(fields[4]).is_valid_int() \
			or not String(fields[5]).is_valid_int() or not String(fields[6]).is_valid_int() \
			or not String(fields[11]).is_valid_int():
		return
	var 角色号 := int(fields[1])
	var 性别 := int(fields[4])
	var 肤色 := int(fields[5])
	var 脸 := int(fields[6])
	var 灵气脸 := int(fields[11])
	var 装备串 := String(fields[9])
	## 第 13 位（本服扩展）：灵器颜色 id。老帧没有这一位 ⇒ 不动颜色。
	var 灵气色 := int(fields[12]) if fields.size() >= 13 and String(fields[12]).is_valid_int() else -1
	if 角色号 == character_id and not authoritative_stats.is_empty():
		## 本人：这些值就是 `游戏会话.自身外观()` 的唯一取值口（身体 / 左上角头像 / 人物窗立绘共用）。
		## 只覆盖 face/gender/skinColor/灵器两键 ⇒ 等级、经验那些别的帧在管的值一律不碰。
		authoritative_stats["face"] = 脸
		authoritative_stats["gender"] = 性别
		authoritative_stats["skinColor"] = 肤色
		authoritative_stats["lingFace"] = 灵气脸
		if 灵气色 >= 0:
			authoritative_stats["lingQiColor"] = 灵气色
	char_look_changed.emit(角色号, 性别, 肤色, 脸, 灵气脸, 装备串)
	if 灵气色 >= 0:
		ling_color_changed.emit(角色号, 灵气色)


## 十拳剑「改变外观」文本回帧。
##   4：`2081:4:<脸数>:<脸行@…>:<色数>:<色行@…>`
##   5/6：`2081:5|6:<成功>:<值>`
## 分隔符 `@`/`&` 与 `_parse_named_rows` 同口径；服务端保证名字里不会出现它们。
static func _parse_ling_qi_face_rows(encoded: String) -> Array:
	var 表: Array = []
	if encoded.is_empty() or encoded == "-":
		return 表
	for 行 in encoded.split("@", false):
		var 段 := String(行).split("&", true)
		if 段.size() < 4:
			continue
		表.append({
			"id": int(段[0]),
			"required_stage": int(段[1]),
			"unlocked": int(段[2]) != 0,
			"name": String(段[3]),
		})
	return 表


static func _parse_ling_qi_color_rows(encoded: String) -> Array:
	var 表: Array = []
	if encoded.is_empty() or encoded == "-":
		return 表
	for 行 in encoded.split("@", false):
		var 段 := String(行).split("&", true)
		if 段.size() < 10:
			continue
		表.append({
			"id": int(段[0]), "name": String(段[1]),
			"red_mul": float(段[2]), "green_mul": float(段[3]), "blue_mul": float(段[4]),
			"alpha_mul": float(段[5]),
			"red_offset": int(段[6]), "green_offset": int(段[7]),
			"blue_offset": int(段[8]), "alpha_offset": int(段[9]),
		})
	return 表


func _handle_ling_qi_appearance_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		return
	var action := int(fields[1])
	if action == 4:
		if fields.size() < 6:
			return
		ling_qi_face_list_received.emit(
			_parse_ling_qi_face_rows(String(fields[3])),
			_parse_ling_qi_color_rows(String(fields[5]))
		)
		return
	if fields.size() < 4:
		return
	var 成功 := int(fields[2]) != 0
	var 值 := int(fields[3])
	if 成功 and not authoritative_stats.is_empty():
		if action == 5:
			authoritative_stats["lingFace"] = 值
		elif action == 6:
			authoritative_stats["lingQiColor"] = 值
	ling_qi_appearance_result.emit(action, 成功, 值)


func _handle_warp_character_text(fields: PackedStringArray) -> void:
	if fields.size() < 32:
		return
	character_id = int(fields[3])
	_switch_authoritative_map(int(fields[23]))
	## 换线帧只带灵气脸（`fields[31]`），**没有颜色位** —— 颜色得从登录时的角色包补。
	## 不补的话：换线/重进图后 `authoritative_stats` 里只剩下 lingFace、lingQiColor 丢失，
	## 玩家身上那层须佐能乎会退回原色。
	var 角色包 := {}
	for 行: Dictionary in characters:
		if int(行.get("id", 0)) == character_id:
			角色包 = 行
			break
	var character := {
		"id": character_id, "name": String(fields[4]), "gender": int(fields[5]),
		"skinColor": int(fields[6]), "face": int(fields[7]), "hair": int(fields[8]),
		"level": int(fields[9]), "job": int(fields[10]), "apAtk": int(fields[11]),
		"apDef": int(fields[12]), "apDex": int(fields[13]), "apPhy": int(fields[14]),
		"hp": int(fields[15]), "maxHp": int(fields[16]), "mp": int(fields[17]),
		"maxMp": int(fields[18]), "remainingAp": int(fields[19]), "remainingSp": int(fields[20]),
		"exp": float(fields[21]), "fame": int(fields[22]), "mapId": int(fields[23]),
		"vip": fields[27] == "true", "shengwang": int(fields[28]), "crime": int(fields[29]),
		"charType": int(fields[30]), "lingFace": int(fields[31]),
		"lingQiColor": int(角色包.get("lingQiColor", 0)),
	}
	_apply_stats(character)
	# 特殊装备四截：37 神器 / 38 魂结 / 39 灵器 / 40 忍具。这是**负槽**唯一的来源
	# （普通 2050 快照只带正槽）；少了它，人物窗灵器格为空、`改变外观` 菜单永远不出现。
	# ⚠️ 忍具（40，原版 `CharacterWarpInfo.as:79-81` 的 renJuItems）以前没读也没发 ——
	#    服务端 `_send_equipped_info` 只收 ZhuangBei，忍具是独立 codec 两边都不带 ⇒
	#    上线后忍具槽(-24)永远空。之后穿第二枚走 flag 13 交换时，被顶下来的那件
	#    回填不到客户端那个"其实是空"的格位 ⇒ 两端背包视图分叉，再点卸下会把件换成别的
	#    （2026-11-04 用户报「穿上八咫镜就不能卸装备了」）。
	authoritative_special_equipment.clear()
	for 下标 in [37, 38, 39, 40]:
		if fields.size() <= 下标:
			continue
		for 物: Dictionary in _parse_item_list(String(fields[下标])):
			var 位 := int(物.get("slot_index", 0))
			if 位 < 0:
				authoritative_special_equipment[位] = 物
	_merge_special_equipment()
	# 快照已到就立刻重发给会话；还没到的话，后面 `_handle_inventory_snapshot` 会带上这份。
	if not authoritative_inventory.is_empty():
		_apply_inventory_to_session()
	# 背包格数（原版 `CharacterWarpInfo` 里紧跟在点券后面那一段，即 legacy 字段序第 36 项）。
	# ⚠️ 2026-09-27 用户报「活跃度奖励提示背包空间不足，实际上我背包是有空间的」——
	#    真因是**这条链两头都断了**：服务端那一格**写死成 96**（原版是 `bag_capacity`），
	#    而客户端**根本没解析它**，背包页于是走 `common_slots` 的兜底 96。
	#    实测那台夹具的 `bag_capacity` 是 **90** —— 玩家在界面上看到 6 个根本不存在的空格，
	#    以为还能放，服务端却按 90 算、判定"背包已满"。
	if fields.size() > 36:
		var 背包格数 := int(fields[36])
		if 背包格数 > 0:
			authoritative_bag_capacity = 背包格数
			bag_capacity_received.emit(背包格数)
	# legacy 字段序第 41 项为 skillInfoList（忍具段占走原第 40 项之后顺移一位）；
	# 服务端不发 39 帧，已学忍术只在这里。
	if fields.size() > 41:
		_apply_skill_list_text(String(fields[41]))
	if not in_game:
		in_game = true
		_set_status("已连接", "人物、背包、任务和社交数据已接入原版后端")
		entered_game.emit(character_id)
		# 原版 `Client.as:8540-8542`（`swapMap()` 之后）每次进图都查这三份礼包状态；
		# 等级礼包这一发会触发服务端的成长礼包发放（`GIFT_QUERY_LEVEL = 21`）。
		# 以前只在打开「福利」页时查 ⇒ 玩家升到 5 级后不重登/不开福利就永远看不到首只礼包。
		send_game_request(OP_GIFT, str(GIFT_QUERY_LEVEL))
		send_game_request(OP_GIFT, str(GIFT_QUERY_WEEKLY))
		send_game_request(OP_GIFT, str(GIFT_QUERY_MONTHLY))

## 「查看信息」的完整回帧（`58:4:<...>`）—— 原版 `CharacterFullInfo.decode:133` 的字段序。
## ⚠ 号别记混：**上行** 94（`ClientOpcode.CHAR_INFO_REQUEST`）、**下行** 58（`ServerOpcode.CHAR_INFO`）。
## ⚠ 段数不够**整条丢掉**，不拿默认值凑：凑出来的会把别人的属性填到我打开的窗上。
## 上一版这个函数是个空壳（只做一次段数检查就返回）⇒ 服务端发了也没人接，
## 「人物属性（看别人）」这扇窗因此一直没数据（10-15 用户令：窗口和数据都要，服务端一起接）。
const 他人信息段数 := 29		## 至少要到 `chengjiuPoints`（下标 28）才够喂战斗属性那六行 + 三行进度
## 尾巴那一截（30..51）**够几段算几段**，缺的键**不塞默认值**：只读页拿不到键就照原样
## 停在"没数据"，比拿 0 冒充对方的阶诚实（`真值/窗口/人物属性_看别人.md` §⑥/§⑧）。
## 夹具 `_full_character_info_fields` 实发 **52 段**（`看别人属性窗回归测试` 逐下标钉）。

## 「查看信息」的完整回帧（`58:0:<...>`）—— 原版 `CharacterFullInfo.decode2` 的字段序。
## ⚠ 号别记混：**上行** 94（`ClientOpcode.CHAR_INFO_REQUEST`）、**下行** 58（`ServerOpcode.CHAR_INFO`）。
##    上行包体第一段是**动作字节**：0 = 查完整档案（「查看信息」）、4 = 只要顶栏血蓝（选中玩家）。
## ⚠ 段数不够**整条丢掉**，不拿默认值凑：凑出来的会把别人的属性填到我打开的窗上。
## 上一版这个函数是个空壳（只做一次段数检查就返回）⇒ 服务端发了也没人接，
## 「人物属性（看别人）」这扇窗因此一直没数据（10-15 用户令：窗口和数据都要，服务端一起接）。

func _handle_character_info_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var 命令 := int(fields[1])
	if 命令 == 2:
		_处理花档帧(fields)
		return
	## 分支的夹具/服务端走 `58:0`（完整档案），master 后来改走 `58:4`（同形状）；
	## 两条都认 —— 6 = 别的档，其余不收。
	if 命令 != 0 and 命令 != 4:
		return
	## ⚠ 同一形状服务端**进游戏时也会发一条我自己的**（`_send_full_character_info`）⇒
	## 按号判：号 == 我自己 ⇒ 那是自己的档案，**不许开"看别人"那扇窗**。
	## （原版靠"只有 `onCharInfo` 被外来请求触发"绕开了这一条；我们的服务端两条都是 cmd 0，
	##   所以只能按号判 —— 这条判据在 `测试/他人人物窗回归测试.gd` ① 里钉着。）
	if 命令 == 0 and fields.size() > 2 and int(fields[2]) == character_id:
		return
	if fields.size() < 他人信息段数:
		push_warning("58:%d 段数只有 %d（< %d）⇒ 整条丢掉，不拿默认值凑"
			% [命令, fields.size(), 他人信息段数])
		return
	## 下标 0..29 按原版解码器 `CharacterFullInfo.as:139-169` 的位置对，**不按名字猜**：
	## 服务端那两个函数叫 `_current_critical/_current_evasion`，原版字段却叫 bsk/avd。
	## ⚠️ **30 往后就不按原版序了**（见下面 `_他人尾巴键`）—— 对位只对到 29。
	他人详细信息 = {
		"cid": int(fields[2]), "名": String(fields[3]), "等级": int(fields[4]),
		"职业": int(fields[5]), "头像": int(fields[6]), "家族": String(fields[7]),
		"配偶": String(fields[8]), "声望": int(fields[9]), "罪恶值": int(fields[10]),
		"经验": int(float(fields[11])), "经验上限": int(float(fields[12])),
		"精华": int(fields[13]), "宠物上限": int(fields[14]),
		"血": int(fields[15]), "血上限": int(fields[16]),
		"蓝": int(fields[17]), "蓝上限": int(fields[18]),
		"攻击": int(fields[19]), "防御": int(fields[20]),
		"暴击": int(fields[21]), "闪避": int(fields[22]),
		"攻击速度": int(fields[23]), "移动速度": int(fields[24]),
		"忍术境界": int(fields[25]), "经脉等级": int(fields[26]),
		"八门进度": int(fields[27]), "成就点": int(fields[28]),
		"装备串": String(fields[29]) if fields.size() > 29 else "-",
		"段数": fields.size(),
	}
	他人详细信息号 = int(fields[2])
	_他人尾巴入档(fields)
	## 原文用 `":".join` 还原：入口是 `text.split(":", true)`（`allow_empty = true`，见
	## `_handle_bridge_text`），冒号不转义 ⇒ 拼回去与收到那串逐字节相同。
	他人详细信息原文 = ":".join(fields)
	他人详细信息收到.emit(他人详细信息)


## `58:4` 尾巴 30..51 入档：**够几段算几段**，缺的键不塞默认值。
##
## ⚠⚠ 这一段跟着**本工程服务端**的排布走，不是 `CharacterFullInfo.as:139-169` 的原版序。
##    写者是 `fake_flash_server.py:20310-20336` 那个 list，与原版解码器**实测差四处**：
##      · 原版 31 = `ringItems`（戒指），夹具那格发的是 `HunJie`（人物面板的**羁绊**格）；
##      · 原版 34 = `renJuItems`（忍具）**夹具整段没发** ⇒ 夹具的 anqi 四件套比原版**前移一格**
##        （原版 35..38 → 夹具 34..37）；
##      · 顺序也换了：原版 写轮眼 40/41 → 柔拳 42/43 → 轮眼 44/45 → `lunhuiSkills` 46 → 结印 47/48，
##        夹具是 柔拳 39/40 → 轮眼 41/42 → `-` 43 → 结印 44/45 → 写轮眼 46/47；
##      · 原版 49..51 = `damageReflect/damageReduce/ignoreDef`、52..55 = 四张**图鉴数组**，
##        夹具 48..51 发的是**四个计数** ⇒ 「藏品图鉴」那页**没有数据源**；
##        **用户 2026-10-20 明确决定完全不做**（更早 2026-09 也是“原版无用部分”）
##        ⇒ 不再补服务端字段、不再排期（`真值/窗口/人物属性_看别人.md` §⑧-1 只作真值记录）。
##    ⇒ 将来接真 Java 服务端时，要么把服务端排布改成原版序，要么在这里换一张表；
##      两种改法都必须同时改 `看别人属性窗回归测试`（那条门逐下标钉这张表）。
const 他人尾巴整数 := {
	34: "手里剑阶", 35: "手里剑级", 36: "手里剑熟练", 37: "手里剑触发",
	39: "柔拳阶", 40: "柔拳进度", 41: "轮回六道阶", 42: "轮回六道进度",
	44: "结印阶", 45: "结印进度", 46: "写轮眼阶", 47: "写轮眼进度",
	48: "卡片已领", 49: "卡片总数", 50: "变身卡已得", 51: "变身卡总数",
}
## 分支（`挂机按原版逐句转写-1019`）把 41/42 那两个键叫「轮眼阶/轮眼进度」，
## 它的门直接读这两个名字；master 那套页面读「轮回六道阶/轮回六道进度」。
## 两套名字指向同一段（帧里只有一组轮眼字段）⇒ 入档时补一份别名，别让两条门各认各的。
const 他人尾巴别名 := {41: ["轮眼阶"], 42: ["轮眼进度"]}
const 他人尾巴文本 := {30: "神器串", 31: "魂结串", 32: "宠物串", 33: "灵器串", 38: "意志串",
	43: "轮眼技能"}
## 进「装备表」的四截（`宠物串` 是宠物清单，不算装备；`意志串` 是意志页另算）。
## ⚠️ **忍具没有数据源**：原版 `CharacterFullInfo.as:170-186` 里的 `renJuItems`，本工程夹具
##    `_full_character_info_fields`（`fake_flash_server.py:20337-20366`）那个 list **根本没有 RenJu**
##    ⇒ 看别人那扇的忍具格永远空。这是**服务端缺字段**，不是客户端漏画，别拿空格子冒充实现
##    （真值 `真值/窗口/人物属性_看别人.md` §⑧-2）。
const 他人装备串键 := ["装备串", "神器串", "魂结串", "灵器串"]

func _他人尾巴入档(fields: PackedStringArray) -> void:
	for 下标 in 他人尾巴整数:
		if fields.size() > 下标:
			他人详细信息[String(他人尾巴整数[下标])] = int(fields[下标])
			for 别名 in (他人尾巴别名.get(下标, []) as Array):
				他人详细信息[String(别名)] = int(fields[下标])
	for 下标 in 他人尾巴文本:
		if fields.size() > 下标:
			他人详细信息[String(他人尾巴文本[下标])] = String(fields[下标])
	他人详细信息["装备"] = _他人装备表()

## 把四截装备串解成 `装备位置(int) → 物品字典`，给「人物属性（看别人）」画**他的**装备格。
## 走的是**同一份** `_parse_item_list` ⇒ 资质/强化/镶嵌/破碎/耐久那六层角标需要的字段天然齐全，
## 不必另立解码器。原版对应链路：`Client.as:3009-3035 onCharInfo` → `CharacterFullInfo.decode:133`
## → `CharOtherWindow2.as:194-204 initWindow()` 五路喂**他的**装备表（忍具那路本工程没有数据源）。
func _他人装备表() -> Dictionary:
	var 表 := {}
	for 键 in 他人装备串键:
		for 物 in _parse_item_list(String(他人详细信息.get(键, "-"))):
			var 位 := int(物.get("equip_position", 0))
			if 位 != 0:
				表[位] = 物
	return 表
## `58:2:<号>:<脸>:<友好度>:<总朵>:<本周>:<今日次数>:<记录串>:<档位串>` —— 一共**十个段**。
## 段序 = 服务端那份 `return` 数组（`fake_flash_server.py` 的 `_flower_character_info_fields`），
## 它与原版 `FlowerCharInfo.decode:44-91` 逐条对上；区别只在文本桥把两段二进制列表拍平成
## `&`/`@` 串，**没有原版那个前置条数** ⇒ 条数只能数串里的条目，空列表服务端写 `-`（`logs or "-"`）。
## ⚠ 经验那一位是 `float()` 出来的（"1234.0"）⇒ 必须 `float()`，`int()` 会解成 0。
func _处理花档帧(fields: PackedStringArray) -> void:
	if fields.size() < 10:
		push_warning("58:2 段数只有 %d（< 10）⇒ 整条丢掉，不拿默认值凑" % fields.size())
		return
	var 记录: Array = []
	if String(fields[8]) != "-":
		for 条 in String(fields[8]).split("@", false):
			var 段: PackedStringArray = String(条).split("&", false)
			if 段.size() < 8:
				continue
			## 八个字段的序 = 服务端 `_flower_character_info_fields` 那个元组，与原版
			## `FlowerCharInfo.decode:62-69` 逐条对上：名 & 号 & 朵 & **经过秒** & 脸 & 职 & 级 & 花号。
			## ⚠ 第四段**不是墙上时钟**，是"离现在多少秒"：`MarryZengHuaLogCell:115-139` 拿它
			## `<60 ⇒ 刚刚`、再 `/60 /60 /24` 逐级印，`FlowerCharInfo:76` 还按它**升序**排
			## ⇒ 传绝对 epoch 会把每行都印成几千万分钟前、且最新那条沉到最后。
			## 换算在服务端 `_flower_send_elapsed` 里做（客户端不碰时钟，门才能钉死四档）。
			var 名 := String(段[0])
			var 号 := int(段[1])
			## `FlowerCharInfo.checkExist:29-41`：号**和**名都撞上才算重复，重复的那条**不 push**
			## ⇒ 同一个人一天送两次，窗里那一列只有一行（原版就这样，不是去重成最后一条）。
			var 重 := false
			for 旧 in 记录:
				if int(旧.get("senderId", 0)) == 号 and String(旧.get("senderName", "")) == 名:
					重 = true
					break
			if 重:
				continue
			记录.append({"senderName": 名, "senderId": 号, "count": int(段[2]),
					"sendTime": int(段[3]), "face": int(段[4]), "job": int(段[5]),
					"level": int(段[6]), "flowerid": int(段[7])})
	var 档: Array = []
	for 条 in String(fields[9]).split("@", false):
		var 段: PackedStringArray = String(条).split("&", false)
		if 段.size() < 6:
			continue
		## 六个字段 = `FlowerInfo.decode`：朵 & 经验 & 花费 & 友好度 & type & 花号。
		档.append({"count": int(段[0]), "exp": float(段[1]), "cost": int(段[2]),
				"youhaodu": int(段[3]), "type": int(段[4]), "flowerid": int(段[5])})
	## 排序在**收端**做（原版 `FlowerCharInfo.as:77/:91`：记录按 sendTime、档位按 youhaodu 都升序）
	## ⇒ 三格恒是 1 朵 → 20 朵 → 99 朵蓝妖姬，窗里按 `flowerInfo[i]` 顺位摆，不许自己再排一次。
	## 记录的升序 = **经过秒的升序** = 最新那条排第一（sendTime 是"离现在多少秒"，见上面那段）。
	记录.sort_custom(func(a, b): return int(a.get("sendTime", 0)) < int(b.get("sendTime", 0)))
	档.sort_custom(func(a, b): return int(a.get("youhaodu", 0)) < int(b.get("youhaodu", 0)))
	authoritative_flower = {
		"cid": int(fields[2]), "face": int(fields[3]), "youhaodu": int(fields[4]),
		"totalFlowers": int(fields[5]), "weeklyFlowers": int(fields[6]), "count": int(fields[7]),
		"flowerDayLogInfo": 记录, "flowerInfo": 档,
	}
	花档收到.emit(authoritative_flower.duplicate(true))


## `2330:<结果>:<消息>[:<名单>]` —— 改名族四档共用的一条下行（解码器
## `AllInOneProcessor.as:130-169 handleChangeNamePacket`：`readUnsignedByte` + `readUTF`，
## 结果 10/12 再 `readShort` 个数、逐条 `readUTF`）。
## 服务端文本桥把名单压成第 4 段的 `@` 串、**空表写 `-`**（`_send_change_name_result`）。
## ⚠ 段数不足 3 整条丢掉：结果码与消息都不许猜（猜成 0 就是"改名成功"，会去动本地档案）。
func _handle_change_name_text(fields: PackedStringArray) -> void:
	if fields.size() < 3 or not String(fields[1]).is_valid_int():
		push_warning("2330 段数/结果码不对（%d 段）⇒ 整条丢掉" % fields.size())
		return
	var 名单 := PackedStringArray()
	if fields.size() > 3:
		## 名字本身不许含冒号（整条文本桥都按 `:` 切），但名单是 `@` 串、万一带了冒号，
		## 这里按**剩余整段**还原，比只取 `fields[3]` 稳。
		var 串 := ":".join(fields.slice(3))
		if 串 != "-":
			名单 = 串.split("@", true)
	改名结果码 = int(fields[1])
	改名消息 = String(fields[2])
	改名名单 = 名单
	改名回帧收到.emit(改名结果码, 改名消息, 改名名单)

func _handle_npc_dialog_text(opcode: int, fields: PackedStringArray) -> void:
	# 普通对话为 325:type:npcId:text，带菜单的扩展对话为 328:npcId:text。
	var npc_index := 2 if opcode == 325 else 1
	var message_index := 3 if opcode == 325 else 2
	if fields.size() <= message_index:
		return
	var npc_id := int(fields[npc_index])
	var message := String(fields[message_index])
	# 328 帧一共 8 段：`npcId : text : playerText : menu : selection : - : -`
	# （2026-10-04 合并「纲手三页」包：原先只取前两段 ⇒ 菜单整段被丢，客户端只能自己编按钮。
	#   按原版 `NPCTalkProcessor.as:34-55` 把 menu 拆成 [[文字,动作值],...]，`-` = 无菜单。）
	last_npc_dialog = {"npc_id": npc_id, "message": message,
		"player_text": String(fields[message_index + 1]) if fields.size() > message_index + 1 else "",
		"menu": _解析NPC菜单(fields[message_index + 2]) if fields.size() > message_index + 2 else [],
		# selection 段（原版 `_data.selection`）= **任务行**，与 menu 段不是一种东西：
		# 每行 `文字&questId&状态&次数&上限`，`&` 后那个数**不是动作值** ⇒ 单独解析成字典。
		"selection": _解析NPC任务行(fields[message_index + 3]) if fields.size() > message_index + 3 else []}
	npc_dialog_received.emit(npc_id, message)


static func _解析NPC菜单(段: String) -> Array:
	var 出: Array = []
	if 段 == "" or 段 == "-":
		return 出
	for 项 in 段.split("@"):
		var 分: PackedStringArray = String(项).split("&", true, 1)
		if 分.size() == 2:
			出.append([分[0], int(分[1])])
	return 出

static func _解析NPC任务行(段: String) -> Array:
	var 出: Array = []
	if 段 == "" or 段 == "-":
		return 出
	for 项 in 段.split("@"):
		var 分: PackedStringArray = String(项).split("&", true)
		if 分.size() < 2:
			continue
		出.append({"文字": String(分[0]), "任务id": int(分[1]),
				"状态": int(分[2]) if 分.size() > 2 else 0,
				"次数": int(分[3]) if 分.size() > 3 else 0,
				"上限": int(分[4]) if 分.size() > 4 else 0})
	return 出


## `MessagePosition.CHAR_NOTICE = 512`（`MessagePosition.as:18`）：原版对这一位**不进聊天面板**，
## 走 `UI.as:376-377` 的 `addNotice(text, CN.COLOR_MID_PROM, true)` ⇒
## `addNoticeImmidate:1567-1573` ⇒ `MessageTipPane.showMessage`（屏幕浮动黄字）。
## ⚠️ 2026-10-21 修（用户实机报「一键学习/拾取/卖出点了没反应」）：这里原来无条件只发
##    `chat_received`，而 `聊天面板._render_chat_messages` 按页签位过滤
##    （MISC4/GENERAL8/WHISPER16/PARTY32/GUILD64/WORLD128/LABA256）——**512 哪个页签都不匹配**
##    ⇒ 消息存进 `_chat_messages` 却永远渲染不出来。服务端 397 处
##    `_send_character_notice`（= `_send_system_chat`/`_send_native_server_message`）
##    全是这个位 ⇒ 全游戏的「诚实反馈」玩家一句都看不见。
##    修法：512 改走本文件的 `_通知()`（等价 `API.ui.addNotice`：会话
##    `notification_requested` ⇒ 小地图 toast + 聊天面板「系统」频道一行，两端都实测可见）。
func _handle_chat_text(fields: PackedStringArray) -> void:
	if fields.size() < 7:
		return
	# ⚠️ **服务端拒绝/告知走的是这一位，不是宠物动作回帧**（§3.204 的更正）。
	#    原版 `UI.as:287-388 onChatMessage` 按 `MessagePosition` 分派、`msgType` 只管名字与配色：
	#    `CHAR_NOTICE(512)` ⇒ `addNotice(text, CN.COLOR_MID_PROM, true)`（`UI.as:375-377`，
	#    黄字浮动提示），**不进聊天记录**。夹具 `_send_character_notice`
	#    （`fake_flash_server.py:40422-40439`）发的就是 `1536:1:512:文本:系统:...`，
	#    宠物的每条拒绝（`_put_on_pet_equipment:39039/39042` 等）都从这里出来
	#    ⇒ 接到本工程的提示口子，界面才看得见。
	var 位 := int(fields[2])
	if 位 == POS_CHAR_NOTICE:
		_通知(String(fields[3]))
	chat_received.emit({
		"type": int(fields[1]), "positions": 位, "message": String(fields[3]),
		"name": String(fields[4]), "character_id": int(fields[5]), "level": int(fields[6]),
		"target_name": String(fields[8]) if fields.size() > 8 else "",
	})

func _handle_npc_shop_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var tabs: Array[Dictionary] = []
	var products: Array[Dictionary] = []
	if String(fields[2]) != "-":
		for tab_text in String(fields[2]).split("@", false):
			var tab_parts := String(tab_text).split("&", true, 1)
			if tab_parts.size() < 2:
				continue
			var tab_name := String(tab_parts[0])
			var tab_items: Array[Dictionary] = []
			for item_text in String(tab_parts[1]).split("!", false):
				var values := String(item_text).split("#", true)
				if values.size() < 7:
					continue
				var item_id := String(values[0]).pad_zeros(8) if String(values[0]).is_valid_int() else String(values[0])
				var item_type := int(values[5])
				var item := _item_display_fields(item_id, item_type)
				item.merge({
					"id": item_id, "item_type": item_type, "price": int(values[1]),
					"buy_count": int(values[2]), "unit_price": float(values[3]), "slot_max": int(values[4]),
					"can_recharge": String(values[6]).to_lower() in ["1", "true", "ture"], "tab": tab_name,
				}, true)
				tab_items.append(item)
				products.append(item)
			tabs.append({"name": tab_name, "items": tab_items})
	authoritative_npc_shop = {"npc_id": int(fields[1]), "tabs": tabs, "items": products, "secret": false}
	npc_shop_received.emit(authoritative_npc_shop.duplicate(true))
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_npc_shop"):
		session.apply_backend_npc_shop(authoritative_npc_shop)

## 线序（`SecretShopInfo.decode:21-40`：前 2 个 int + 每条 6 个 int + 尾巴 1 个 int）：
## `324 : 剩余秒 : [itemid&count&yb&moneyType&meso&hasBought]（条间 @） : 折扣`，空货架那一段发 `-`。
## ⚠ 窗上显示的价格是 **`yb`**（这里叫 `cash_price`），不是 `meso`（`price`）——
## `MysteryCell.setData:114` 用的是 `data.yb`，`meso` 那一整段原版解析了但**从不显示**。
## ⚠ 这里**不写** `authoritative_npc_shop`、**不 emit** `npc_shop_received`，也**不**喂
## `session.apply_backend_npc_shop`：那三条是 NPC 商店按 `npc_id` 开的账，
## 神秘商店挤进去会把上一个 NPC 的货架整片盖掉（§3.222 的根因）。
func _handle_secret_shop_text(fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	var products: Array[Dictionary] = []
	if String(fields[2]) != "-":
		for item_text in String(fields[2]).split("@", false):
			var values := String(item_text).split("&", true)
			if values.size() < 6:
				continue
			var item_id := String(values[0]).pad_zeros(8) if String(values[0]).is_valid_int() else String(values[0])
			var item := _item_display_fields(item_id, 2)
			item.merge({
				"id": item_id, "quantity": int(values[1]), "cash_price": int(values[2]),
				"money_type": int(values[3]), "price": int(values[4]), "purchased": int(values[5]) != 0,
			}, true)
			products.append(item)
	authoritative_mystery_shop = {
		"items": products, "remaining_seconds": int(fields[1]), "discount_percent": int(fields[3]),
	}
	mystery_shop_received.emit(authoritative_mystery_shop.duplicate(true))

func _handle_storage_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	match action:
		1:
			if fields.size() < 7:
				return
			if _storage_expected_count == 0:
				_storage_chunks.clear()
			authoritative_storage_capacity = int(fields[3])
			authoritative_storage_gold = int(float(fields[4]))
			_storage_expected_count = int(fields[5])
			for item in _parse_item_list(String(fields[6])):
				_storage_chunks[int(item.slot_index)] = item
			if _storage_chunks.size() < _storage_expected_count:
				return
			authoritative_storage.assign(_storage_chunks.values())
			_storage_chunks.clear()
			_storage_expected_count = 0
			## 分块拼完才算"仓库开出来了"⇒ 这是唯一的开窗时刻（原版那一帧就是整包，
			## 本端拆成 `_storage_expected_count` 块 ⇒ 半途 emit 会把空架子画出来）。
			storage_opened.emit()
		2:
			storage_full_received.emit()
			return
		3:
			if fields.size() < 4:
				return
			authoritative_storage_capacity = int(fields[2])
			authoritative_storage_gold = int(float(fields[3]))
		4:
			if fields.size() < 3:
				return
			var item := _parse_item_entry(String(fields[2]))
			if not item.is_empty():
				_set_storage_item(int(item.slot_index), item)
		5:
			if fields.size() < 3:
				return
			_clear_storage_item(int(fields[2]))
		6:
			if fields.size() < 5:
				return
			authoritative_storage_capacity = int(fields[2])
			authoritative_storage_gold = int(float(fields[3]))
			_apply_storage_sort(String(fields[4]))
	authoritative_storage.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("slot_index", 0)) < int(right.get("slot_index", 0)))
	_apply_storage_to_session()

func _set_storage_item(slot: int, item: Dictionary) -> void:
	_clear_storage_item(slot)
	var stored := item.duplicate(true)
	stored["slot_index"] = slot
	authoritative_storage.append(stored)

func _clear_storage_item(slot: int) -> void:
	for index in range(authoritative_storage.size() - 1, -1, -1):
		if int(authoritative_storage[index].get("slot_index", 0)) == slot:
			authoritative_storage.remove_at(index)

func _apply_storage_sort(encoded: String) -> void:
	if encoded.is_empty() or encoded == "-":
		authoritative_storage.clear()
		return
	var sorted_items: Array[Dictionary] = []
	for row_text in encoded.split("@", false):
		var values := String(row_text).split("&", true)
		if values.size() < 4:
			continue
		var item_id := String(values[0])
		var unique_id := int(float(values[3]))
		var matched := {}
		for item in authoritative_storage:
			if (unique_id > 0 and int(item.get("unique_id", 0)) == unique_id) or (unique_id <= 0 and int(item.get("id", 0)) == int(item_id)):
				matched = item.duplicate(true)
				break
		if matched.is_empty():
			matched = _item_display_fields(item_id, 2)
			matched.merge({"id": item_id, "type": 2, "unique_id": unique_id}, true)
		matched["slot_index"] = int(values[1])
		matched["quantity"] = int(values[2])
		sorted_items.append(matched)
	authoritative_storage.assign(sorted_items)

func _apply_storage_to_session() -> void:
	storage_received.emit(authoritative_storage.duplicate(true), authoritative_storage_gold, authoritative_storage_capacity)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_storage"):
		session.apply_backend_storage(authoritative_storage, authoritative_storage_gold, authoritative_storage_capacity)

func _handle_pet_action_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var result := {"action": action}
	match action:
		0:
			authoritative_pet_capacity = int(fields[2]) if fields.size() > 2 else 10
			authoritative_pets.clear()
			if fields.size() > 3 and String(fields[3]) != "-":
				for encoded in String(fields[3]).split("@", false):
					var pet := _parse_pet_fields(String(encoded).split("&", true), 0, "!", "#")
					if not pet.is_empty():
						authoritative_pets.append(pet)
		1, 2, 15:
			# ⚠️ 这几种**整宠帧**的内部行分隔是 "@"、字段分隔是 "&"（`_encode_pet_update`），
			#    与列表帧的 "!"/"#" **不是一套** —— 混用会把 skills/equipment 解析成空数组，
			#    表现是"融魂/升级之后技能图标全没了"。2026-09-28 由融魂用例抓到。
			var pet := _parse_pet_fields(fields, 2, "@", "&")
			if not pet.is_empty():
				_set_authoritative_pet(pet)
				result["pet"] = pet
		3:
			if fields.size() > 2:
				var unique_id := int(fields[2])
				_remove_authoritative_pet(unique_id)
				result["unique_id"] = unique_id
		4, 5:
			var spawn := _parse_pet_spawn(fields)
			if not spawn.is_empty():
				_set_pet_position(int(spawn.unique_id), int(spawn.position))
				pet_spawned.emit(spawn.duplicate(true))
				result.merge(spawn, true)
		6:
			if fields.size() > 4:
				var owner_id := int(fields[2])
				var unique_id := int(fields[3])
				var position := int(fields[4])
				_set_pet_position(unique_id, position)
				pet_removed.emit(owner_id, unique_id, position)
				result.merge({"character_id": owner_id, "unique_id": unique_id, "position": position}, true)
		7:
			result["movement"] = Array(fields.slice(2))
		8:
			if fields.size() > 3:
				result.merge({"character_id": int(fields[2]), "unique_id": int(fields[3])}, true)
		9:
			# 宠物**喊话**帧，不是拒绝（§3.204 更正）。原版 `PetProcessor.handlePetAction_chat:472-490`
			# 的字段序是 `charId(int) / petUid(double) / action(short) / text(UTF)`，解成
			# `PetChatInfo` 后交给 `channelListener.onPetChat` —— 而 `Client.as:1821-1823`
			# 那个实现**是空的**，`ReceiveOpCodes.PET_CHAT` 也从没注册过监听 ⇒ 原版收到就丢掉。
			# 这里照原版**只解析、不消费**（`pet_action_received` 仍发出去，留给人调试）。
			if fields.size() > 5:
				result.merge({
					"character_id": int(fields[2]), "unique_id": int(fields[3]),
					"chat_action": int(fields[4]), "message": String(fields[5]),
				}, true)
		10:
			result["stats"] = Array(fields.slice(2))
		11:
			if fields.size() > 4:
				var unique_id := int(fields[3])
				_update_pet_value(unique_id, "name", String(fields[4]))
				result.merge({"character_id": int(fields[2]), "unique_id": unique_id, "name": String(fields[4])}, true)
		12:
			if fields.size() > 6:
				var unique_id := int(fields[3])
				_upsert_pet_skill(unique_id, int(fields[4]), int(fields[5]), int(fields[6]))
				result.merge({"character_id": int(fields[2]), "unique_id": unique_id, "skill_id": int(fields[4]), "level": int(fields[5]), "master_level": int(fields[6])}, true)
		13, 14:
			if fields.size() > 4:
				var unique_id := int(fields[3])
				if action == 13:
					var equipment := _parse_item_entry(String(fields[4]))
					if not equipment.is_empty():
						_set_pet_equipment(unique_id, equipment)
						result.merge({"character_id": int(fields[2]), "unique_id": unique_id, "equipment": equipment}, true)
				else:
					var equipment_slot := int(fields[4])
					_remove_pet_equipment(unique_id, equipment_slot)
					result.merge({"character_id": int(fields[2]), "unique_id": unique_id, "equipment_slot": equipment_slot}, true)
		16:
			if fields.size() > 3:
				result.merge({"unique_id": int(fields[2]), "effect": int(fields[3])}, true)
		17:
			if fields.size() > 4:
				var unique_id := int(fields[3])
				_update_pet_value(unique_id, "skills", _parse_pet_skills(String(fields[4]), "@", "&"))
				result.merge({"character_id": int(fields[2]), "unique_id": unique_id}, true)
		18:
			if fields.size() > 4:
				result.merge({"item_id": int(fields[2]), "remaining_seconds": int(fields[3]), "total_seconds": int(fields[4])}, true)
		19:
			if fields.size() > 4:
				result.merge({"character_id": int(fields[2]), "unique_id": int(fields[3]), "success": int(fields[4]) != 0}, true)
	authoritative_pets.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("unique_id", 0)) < int(right.get("unique_id", 0)))
	_apply_pets_to_session()
	pet_action_received.emit(action, result.duplicate(true))

func _parse_pet_fields(values: PackedStringArray, offset: int, 行分隔 := "!", 字段分隔 := "#") -> Dictionary:
	if values.size() < offset + 31:
		return {}
	var item_id := int(values[offset])
	var position := int(values[offset + 1])
	var unique_id := int(values[offset + 8])
	return {
		"id": str(item_id).pad_zeros(8), "item_id": item_id, "position": position,
		"unique_id": unique_id, "name": String(values[offset + 10]), "level": int(values[offset + 11]),
		"blessing": int(values[offset + 14]), "aptitude": int(values[offset + 15]),
		"savvy": int(values[offset + 16]), "experience": int(values[offset + 17]),
		"faith": int(values[offset + 18]), "max_faith": 100,
		"attack": int(values[offset + 19]), "defense": int(values[offset + 20]),
		"dexterity": int(values[offset + 21]), "strength": int(values[offset + 22]),
		"max_attack": int(values[offset + 23]), "max_defense": int(values[offset + 24]),
		"max_dexterity": int(values[offset + 25]), "max_strength": int(values[offset + 26]),
		"face": int(values[offset + 27]), "stage": maxi(1, int(values[offset + 15])),
		"can_trade": int(values[offset + 5]) != 0,
		"equipment": _parse_pet_equipment(String(values[offset + 28]), 行分隔, 字段分隔),
		"skills": _parse_pet_skills(String(values[offset + 29]), 行分隔, 字段分隔),
		"attached": position == 0, "deployed": position == 125,
		# ↓ **服务端语义名**。19..22/23..26 是潜力 real/total（`_encode_pet` 的
		#   potential_real_atk…potential_total_str）——上面 attack/defense 那组旧名是
		#   自造宠物窗留下的**错位名**（潜力不是攻击力）。`脚本/角色/宠物数值.gd` 只认这套。
		#   字段 30 = `pet.dream` = 原版 CocoPet.decode 尾部的 `lingZhuNum`（梦幻灵珠数，
		#   梦幻度第四分量），旧解析一直漏读。旧键暂留着（战斗汇总与离线示例在读）。
		"potential_real_atk": int(values[offset + 19]), "potential_real_def": int(values[offset + 20]),
		"potential_real_dex": int(values[offset + 21]), "potential_real_str": int(values[offset + 22]),
		"potential_total_atk": int(values[offset + 23]), "potential_total_def": int(values[offset + 24]),
		"potential_total_dex": int(values[offset + 25]), "potential_total_str": int(values[offset + 26]),
		"ling_zhu": int(values[offset + 30]) if values.size() > offset + 30 else 0,
	}

func _parse_pet_skills(encoded: String, row_separator: String, field_separator: String) -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return skills
	for row in encoded.split(row_separator, false):
		var values := String(row).split(field_separator, true)
		if values.size() < 3:
			continue
		var skill_id := int(values[0])
		skills.append({"id": skill_id, "name": "宠物技能 %d" % skill_id, "level": int(values[1]), "master_level": int(values[2]), "description": ""})
	return skills

func _parse_pet_equipment(encoded: String, 行分隔 := "!", 字段分隔 := "#") -> Array[Dictionary]:
	var equipment: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return equipment
	for row in encoded.split(行分隔, false):
		# ⚠️ 宠物装备行**没有"物品类型"那一位**：服务端 `_encode_pet_equipment` 是
		#    `_encode_item_payload(item).split("&")[1:]`（原版 `CocoEquip.decode:248` 本来就不读它）。
		#    而 `_parse_item_entry` 按"第 0 位 = 类型"解析（与服务端 `common_fields` 对齐）——
		#    直接喂进去会**整体错位一格**：id 读成槽位、unique_id 读成资质……
		#    表现是"服务端确实穿上了，但面板不显示、`宠物真实事务` 报原实例没转移"。
		#    这里补一位类型把它对齐（1 = 普通装备）。
		var item := _parse_item_entry("1&" + String(row).replace(字段分隔, "&"))
		if not item.is_empty():
			item["equipment_slot"] = int(item.get("slot_index", 0))
			equipment.append(item)
	return equipment

func _parse_pet_spawn(fields: PackedStringArray) -> Dictionary:
	if fields.size() < 12:
		return {}
	return {
		"character_id": int(fields[2]), "unique_id": int(fields[3]), "item_id": int(fields[4]),
		"name": String(fields[5]), "x": int(fields[6]), "y": int(fields[7]), "stance": int(fields[8]),
		"foothold": int(fields[9]), "face": int(fields[10]), "position": int(fields[11]),
	}

func _pet_index(unique_id: int) -> int:
	for index in authoritative_pets.size():
		if int(authoritative_pets[index].get("unique_id", 0)) == unique_id:
			return index
	return -1

func _set_authoritative_pet(pet: Dictionary) -> void:
	var index := _pet_index(int(pet.get("unique_id", 0)))
	if index >= 0:
		authoritative_pets[index] = pet.duplicate(true)
	else:
		authoritative_pets.append(pet.duplicate(true))

func _remove_authoritative_pet(unique_id: int) -> void:
	var index := _pet_index(unique_id)
	if index >= 0:
		authoritative_pets.remove_at(index)

## 把某一帧里的 `unique_id/position` 落到权威宠物表。**只动这一只** ——
## 以前是循环里每一只都写 `attached/deployed`（`and uid==unique_id` 只是把**别的**宠物刷成 false），
## 于是"一只附身 + 一只出战"并存时，后一条帧会把先那只的状态**本地清掉**：服务端明明允许
## 两态并存（`_normalize_active_pet_positions()`），客户端却只留最后一只、地图上也只有一只 actor。
func _set_pet_position(unique_id: int, position: int) -> void:
	for index in authoritative_pets.size():
		var pet: Dictionary = authoritative_pets[index]
		if int(pet.get("unique_id", 0)) != unique_id:
			continue
		pet["position"] = position
		pet["attached"] = position == 0
		pet["deployed"] = position == 125
		authoritative_pets[index] = pet

func _update_pet_value(unique_id: int, key: String, value: Variant) -> void:
	var index := _pet_index(unique_id)
	if index < 0:
		return
	var pet: Dictionary = authoritative_pets[index]
	pet[key] = value
	authoritative_pets[index] = pet

func _upsert_pet_skill(unique_id: int, skill_id: int, level: int, master_level: int) -> void:
	var index := _pet_index(unique_id)
	if index < 0:
		return
	var pet: Dictionary = authoritative_pets[index]
	var skills: Array = pet.get("skills", [])
	for skill_index in skills.size():
		if int(skills[skill_index].get("id", 0)) == skill_id:
			var skill: Dictionary = skills[skill_index]
			skill.merge({"level": level, "master_level": master_level}, true)
			skills[skill_index] = skill
			pet["skills"] = skills
			authoritative_pets[index] = pet
			return
	skills.append({"id": skill_id, "name": "宠物技能 %d" % skill_id, "level": level, "master_level": master_level, "description": ""})
	pet["skills"] = skills
	authoritative_pets[index] = pet

func _set_pet_equipment(unique_id: int, equipment: Dictionary) -> void:
	var index := _pet_index(unique_id)
	if index < 0:
		return
	var pet: Dictionary = authoritative_pets[index]
	var items: Array = pet.get("equipment", [])
	var equipment_slot := int(equipment.get("slot_index", equipment.get("equipment_slot", 0)))
	var stored := equipment.duplicate(true)
	stored["equipment_slot"] = equipment_slot
	for item_index in items.size():
		if int(items[item_index].get("equipment_slot", items[item_index].get("slot_index", 0))) == equipment_slot:
			items[item_index] = stored
			pet["equipment"] = items
			authoritative_pets[index] = pet
			return
	items.append(stored)
	pet["equipment"] = items
	authoritative_pets[index] = pet

func _remove_pet_equipment(unique_id: int, equipment_slot: int) -> void:
	var index := _pet_index(unique_id)
	if index < 0:
		return
	var pet: Dictionary = authoritative_pets[index]
	var items: Array = pet.get("equipment", [])
	for item_index in range(items.size() - 1, -1, -1):
		if int(items[item_index].get("equipment_slot", items[item_index].get("slot_index", 0))) == equipment_slot:
			items.remove_at(item_index)
	pet["equipment"] = items
	authoritative_pets[index] = pet

func _apply_pets_to_session() -> void:
	pets_received.emit(authoritative_pets.duplicate(true), authoritative_pet_capacity)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_pets"):
		session.apply_backend_pets(authoritative_pets, authoritative_pet_capacity)

func _handle_item_change_result(opcode: int, fields: PackedStringArray) -> void:
	var result := {}
	match opcode:
		OP_STONE_MERGE_RESPONSE:
			if fields.size() < 10:
				return
			result = {
				"kind": "stone_merge",
				"success_count": int(fields[1]), "success_item_id": int(fields[2]), "success_level": int(fields[3]),
				"failed_count": int(fields[4]), "failed_item_id": int(fields[5]), "failed_level": int(fields[6]),
				"left_count": int(fields[7]), "left_item_id": int(fields[8]), "left_level": int(fields[9]),
			}
		OP_EQUIP_INLAY_INFO:
			if fields.size() < 3:
				return
			result = {
				"kind": "equipment_inlay", "equipment_position": int(fields[1]),
				"inlays": _parse_named_rows(String(fields[2]), ["stone_id", "stone_level", "attribute_type", "skill_id", "attribute_value"], "@", "&"),
			}
		OP_WASH_PLUS_VALUE_RESPONSE:
			if fields.size() < 4:
				return
			result = {
				"kind": "wash_plus_value", "equipment_position": int(fields[1]), "result": int(fields[2]),
				"plus_attributes": _parse_named_rows(String(fields[3]), ["attribute_type", "attribute_value"], "@", "&"),
			}
		# ⚠️ 这两个包的字段序是 **`<opcode>:<槽位>:<结果>`** —— **槽位在前**，
		# 2026-09-23 由 `装备打造在线回归测试` 的精炼那一段逮到的：
		# 原来读的是 `fields[1]`，那其实是**槽位**（武器槽 -1），于是界面上一直显示
		# "附加属性精炼结果：失败（-1）" —— 结果码被槽位顶掉了。
		# 出处：服务端 `_forge_level_eleven` / `_forge_additive` 的 `f"{op}:{item.slot}:{result}"`，
		# 以及 AS3 `handleEquipForgeStrengthResponse`（先 `readInt()` 到 `equipSlot`、再一个到 `result`）。
		# 隔壁 `OP_EQUIP_KUNCHONG_STRENGTH_RESULT` 本来就是对的（槽位+结果两个都留），照它改。
		OP_EQUIP_FORGE_STRENGTH_RESULT:
			if fields.size() < 3:
				return
			result = {"kind": "forge_strength", "equipment_position": int(fields[1]), "result": int(fields[2])}
		OP_EQUIP_FORGE_ADDITIVE_RESULT:
			if fields.size() < 3:
				return
			result = {"kind": "forge_additive", "equipment_position": int(fields[1]), "result": int(fields[2])}
		OP_EQUIP_KUNCHONG_STRENGTH_RESULT:
			if fields.size() < 3:
				return
			# 身上四格的槽位服务端回的是**原版客户端的件序 73..76**（`_strengthen_kun_chong` 的
			# `73 + (KUN_CHONG_A - slot)`，原版 `_itemData.position` 就是这套数）。本端口的装备位
			# 是 -200..-203，不折回来的话 `收昆虫强化回帧` 的「槽位对不上 ⇒ 一句不发」永远命中
			# —— 成功提示不弹、自动循环的续跳也断在半路（2026-10-31 与星级不同步同轮逮到）。
			var 虫位 := int(fields[1])
			if 虫位 >= 73 and 虫位 <= 76:
				虫位 = 装备部位.昆虫一 - (虫位 - 73)
			result = {"kind": "kunchong_strength", "equipment_position": 虫位, "result": int(fields[2])}
		OP_BADGE_STONE_MERGE_RESPONSE:
			if fields.size() < 5:
				return
			result = {
				"kind": "badge_stone_merge", "success_count": int(fields[1]), "success_item_id": int(fields[2]),
				"left_count": int(fields[3]), "left_item_id": int(fields[4]),
			}
		# 灵器炼制回帧 `2081:<动作>:<成功>[:<附加属性>]`（夹具 `handle_ling_qi:52082`、
		# `_spiritualize_ling_qi:52291`、`_wash_ling_qi:52307`；拒绝也回这一条，只是成功位是 0）。
		# 附加属性那一段 = `类型&数值@类型&数值…`、没有就写 `-`（`_encode_ling_qi_attributes:52247`）。
		# ⚠ 原版**二进制**的洗炼回帧在成功位后面还夹一个 `upValue`
		#   （`LingEquipProcessor.as:150-160`：`success、upValue、plusSize、成对`），文本通道没有这一位 ——
		#   而客户端那头 `LingQiManager.onLingEquipWashUpResult:306-322` 拿到 param2 **一眼都没看**
		#   ⇒ 两边一致地丢掉，不是漏读。
		OP_LING:
			if fields.size() < 3:
				return
			result = {
				"kind": "ling_qi_result", "action": int(fields[1]), "result": int(fields[2]),
				"plus_attributes": _parse_named_rows(
					String(fields[3]) if fields.size() > 3 else "",
					["attribute_type", "attribute_value"], "@", "&"),
			}
		# 忍具（八咫镜）回帧 `2082:<动作>:<成功>`（`_send_renju_result:52179`）：只带一个 int，
		# 所以原版 `RenJuProcessor.onRenJuKaiGuangResult:75-89` 也只读一个 `readInt()`。
		OP_RENJU:
			if fields.size() < 3:
				return
			result = {"kind": "ren_ju_result", "action": int(fields[1]), "result": int(fields[2])}
	if not result.is_empty():
		item_change_result_received.emit(opcode, result)

func _handle_timed_item_effect_text(kind: String, fields: PackedStringArray) -> void:
	if fields.size() < 4:
		return
	_apply_item_effect(kind, {
		"item_id": int(fields[1]), "remaining_seconds": int(fields[2]), "total_seconds": int(fields[3]),
	})

func _handle_double_exp_text(fields: PackedStringArray) -> void:
	if fields.size() < 6:
		return
	_apply_item_effect("double_exp", {
		"type": int(fields[1]), "rate": int(fields[2]), "item_id": int(fields[3]),
		"remaining_seconds": int(fields[4]), "total_seconds": int(fields[5]),
	})

## 一条限时道具效果。**不能只按 `kind` 存**：
##   · `shuxing` 攻击/防御/健体药剂是三种不同的 itemId，原版 BuffCell 每个 itemId 一格；
##   · `shuangbei` 还有 exp/zq/petexp 三种 type（`SystemBuffStat.type`），原版也各一格。
## 旧实现按类型单键存 ⇒ 吃第二瓶时第一瓶的图标被顶掉（属性仍在加，玩家却看不到）。
## 键规则照原版的去重维度：属性类按 itemId、双倍类按 type、自动补给按 itemId。
func _item_effect_key(kind: String, state: Dictionary) -> String:
	match kind:
		"attribute_boost", "auto_consume", "stone_merge":
			return "%s:%d" % [kind, int(state.get("item_id", 0))]
		"double_exp":
			return "%s:%d" % [kind, int(state.get("type", 0))]
		_:
			return kind

func _apply_item_effect(kind: String, state: Dictionary) -> void:
	var key := _item_effect_key(kind, state)
	state["effect_key"] = key
	state["kind"] = kind
	state["received_at_msec"] = Time.get_ticks_msec()
	if state.has("remaining_seconds") and int(state.get("remaining_seconds", 0)) <= 0:
		authoritative_item_effects.erase(key)
	else:
		authoritative_item_effects[key] = state.duplicate(true)
	item_effect_received.emit(kind, state.duplicate(true))
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_item_effect"):
		session.apply_backend_item_effect(kind, state)

func _parse_named_rows(encoded: String, names: Array, row_separator: String, field_separator: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return rows
	for row_text in encoded.split(row_separator, false):
		var fields := String(row_text).split(field_separator, true)
		if fields.size() < names.size():
			continue
		var row := {}
		for index in names.size():
			row[String(names[index])] = int(fields[index])
		rows.append(row)
	return rows

func _handle_inventory_snapshot(opcode: int, fields: PackedStringArray) -> void:
	var encoded := "-"
	if opcode == 100000:
		if fields.size() < 3:
			return
		encoded = String(fields[2])
		for item in _parse_item_list(encoded):
			_inventory_chunks[int(item.slot_index)] = item
		if _inventory_chunks.size() < int(fields[1]):
			return
		authoritative_inventory.assign(_inventory_chunks.values())
		_inventory_chunks.clear()
	elif opcode == 2051:
		if fields.size() >= 2:
			encoded = String(fields[1])
		authoritative_inventory.assign(_parse_item_list(encoded))
	else:
		if fields.size() >= 2:
			encoded = String(fields[1])
		authoritative_equipment.clear()
		for item in _parse_item_list(encoded):
			# 键 = **位置 int**（原版协议就是这个数：`UpdateEquipSlotInfo.position` 是 readInt）。
			# 原来拿中文名当键是客户端自造的中间层，和协议、和存档都对不上，已去掉。
			authoritative_equipment[int(item.equip_position)] = item
	_apply_inventory_to_session()


## `2054:<物品体>@<物品体>…`（空四位是 `-`）—— 只喂**寄坏虫四格**（-200..-203）。
## ⚠️ 键必须取**包里的 slot**（`values[2]` → `slot_index`），不能取 `equip_position`：
## 后者是 `装备部位.位置(id)` 按 id 前缀算的，那张表里昆虫只有**昆虫包**（前三位 131），
## 真昆虫一件都算不出来 ⇒ 全按 0 存就把整份装备表覆盖了。原版也是这个口径
## （`ItemList.decode` 拿 `EqpData.position`，位置由服务端在包里给）。
## 语义按**整包快照**：先把四个位清掉再灌 —— 卸完虫服务端发的就是 `-`，不清就留着旧虫回显。
func _handle_equipped_kun_chong(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var 虫位 := [装备部位.昆虫一, 装备部位.昆虫二, 装备部位.昆虫三, 装备部位.昆虫四]
	for 位置 in 虫位:
		authoritative_equipment.erase(位置)
	for item in _parse_item_list(String(fields[1])):
		var 位置 := int(item.get("slot_index", 0))
		if 位置 in 虫位:
			item["equip_position"] = 位置
			item["slot"] = 装备部位.显示名(位置)
			authoritative_equipment[位置] = item
	_apply_inventory_to_session()

func _handle_inventory_change(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var flag := int(fields[1])
	match flag:
		0:
			if fields.size() >= 6:
				var added := _parse_item_entry(String(fields[2]))
				if not added.is_empty():
					var 落位 := int(fields[5])
					_set_item_at_slot(落位, added)
					## 原版 `ItemManager.addInventorySlot:571-575`：`slotId > 0`（装备槽是负数 ⇒ 这列
					## 不报）**且 `fromDrop != 2`**（2 = 进游戏时那份整包初始化，原版靠它压住"一上线
					## 刷一屏获得了"）才按**包里带来的数量**报一条。
					## 段序出处：服务端 `_send_inventory_add:50797-50800` 发
					## `flag : 物品体 : from_drop : inventoryType : slot`，与 AS3
					## `AddInventorySlotInfo.decode:30-39`（fromDrop/inventoryType/slotId/item）同序。
					if 落位 > 0 and int(fields[3]) != 2:
						_提示物品(获得提示文案.道具获得(int(added.get("quantity", 0)),
							String(added.get("name", ""))))
		1:
			if fields.size() >= 6:
				var slot := int(fields[4])
				var updated := _item_at_slot(slot)
				if not updated.is_empty():
					var item_id := String(fields[3])
					updated.merge(_item_display_fields(item_id, int(updated.get("type", 2))), true)
					var 旧数量 := int(updated.get("quantity", 0))
					updated["quantity"] = int(fields[5])
					updated["common"] = fields.size() < 7 or int(fields[6]) == 1
					updated["can_trade"] = fields.size() < 8 or int(fields[7]) == 1
					_set_item_at_slot(slot, updated)
					## 原版 `updateInventorySlot:431-445`：差 = 包里新数量 − **这格的旧数量**；
					## `fromDrop != 2 且 差 != 0` 才报，名字用**新** itemId 的名字（合成换物品时才对）。
					## `fromDrop` = `fields[2]`：服务端 `_send_inventory_update:50886-50890` 的段序
					## `flag : from_drop : item_id : slot : quantity : common : can_trade`，
					## 与 AS3 `UpdateInventorySlotInfo.decode:33-38` 同字段；服务端自己那份
					## 文本→二进制的转发（`:61692-61705`）也是按这个序 `struct.pack("<BBBiihB", …)`。
					var 差 := int(fields[5]) - 旧数量
					if int(fields[2]) != 2 and 差 != 0:
						_提示物品(获得提示文案.道具获得(差, String(updated.get("name", ""))) if 差 > 0
							else 获得提示文案.道具失去(-差, String(updated.get("name", ""))))
		2:
			if fields.size() >= 4:
				_swap_inventory_slots(int(fields[2]), int(fields[3]))
		3:
			# `MoveAndMergeInventoryItemInfo`（AS3 字段序 **src:int, dst:int, total:short**，
			# 见 `data/inventory/MoveAndMergeInventoryItemInfo.as:28-32`）：
			# `total` 是**目标格上的总数**，不是移动数量。
			#
			# 原版怎么处理的：`ItemManager.moveAndMergeInventoryItem`（`ItemManager.as:590-607`）
			# 只清 src 的界面格 + 把 dst 的显示数量设成 total —— **物品数据本身不动**，
			# 因为原版 `DataCenter` 里那份物品表是客户端自己的，这个包只是记账。
			#
			# 客户端原来是反的：清掉 src、又把 total 当数量去合并，结果**装备一穿就凭空消失**
			# （目标格是空装备槽，`_set_slot_quantity` 造不出物品）。现在改成把物品本身搬过去。
			if fields.size() >= 5:
				var source := int(fields[2])
				var destination := int(fields[3])
				var moved := _item_at_slot(source)
				if not moved.is_empty():
					_clear_item_at_slot(source)
					moved["slot_index"] = destination
					if destination < 0:
						moved["equip_position"] = destination
						moved["slot"] = _equipment_name(destination)
					_set_item_at_slot(destination, moved)
				# 无论搬没搬到，都以包里的 total 为准（合并同格堆叠时它才是权威）
				_set_slot_quantity(destination, int(fields[4]))
		4:
			if fields.size() >= 6:
				_set_slot_quantity(int(fields[2]), int(fields[3]))
				_set_slot_quantity(int(fields[4]), int(fields[5]))
		5:
			if fields.size() >= 5:
				## `ClearInventoryItemInfo`（原版 flag 5 分发见 `InventoryProcessor.as:145-152`）→
				## `ItemManager.clearInventoryItem:90-96`：**整堆**报「失去了 N 个X」，
				## 这里**没有** `fromDrop` 判断（原版那个字段只用来决定要不要刷界面）。
				var 清位 := int(fields[4])
				var 清物 := _item_at_slot(清位)
				if not 清物.is_empty():
					_提示物品(获得提示文案.道具失去(int(清物.get("quantity", 0)), String(清物.get("name", ""))))
				_clear_item_at_slot(清位)
		7:
			if fields.size() >= 3:
				## `DropInventoryItemInfo`（flag 7，只有一个 `src:int`）→
				## `ItemManager.dropInventoryItem:47-53`：同样是**整堆**「失去了 N 个X」。
				var 丢位 := int(fields[2])
				var 丢物 := _item_at_slot(丢位)
				if not 丢物.is_empty():
					_提示物品(获得提示文案.道具失去(int(丢物.get("quantity", 0)), String(丢物.get("name", ""))))
				_clear_item_at_slot(丢位)
		8:
			if fields.size() >= 4:
				_set_slot_quantity(int(fields[2]), int(fields[3]))
		11:
			# `UpdateEquipSlotInfo` —— **字段序和别的 flag 不一样**：它是
			# **槽位在前、物品体在后**（服务端 `_send_equipment_slot_update`：
			# `body = flag + pack("<iB", item.slot, inventory_type) + 物品体`）。
			# 其余 flag（0/1/12…）是"物品体在前、槽位在后"，这里原来照着它们读成了
			# `fields[2]=物品体 / fields[3]=槽位` → **服务端刷了装备客户端也不更新**
			# （2026-09-22 实测：强化后强化灵珠扣了 1 个、服务端确实跑了打造，
			#   但 `authoritative_equipment[武器].strengthen` 一直是 0）。
			if fields.size() >= 5:
				var 槽位 := int(fields[2])
				var refreshed := _parse_item_entry(String(fields[4]))
				if not refreshed.is_empty():
					_set_item_at_slot(槽位, refreshed)
		12, 13:
			# `PeiDaiOrXieXiaLingQiInfo`（flag 12 灵器 / 13 人具；AS3 `InventoryProcessor.as:201-215`）
			# 原版最终走 `addInventorySlot` → `moveItem_LingQi/RenJu(slotSrc, slotDst)`
			# → `exchangeSlots`：**src 那件搬到 dst，dst 原有的换回 src**（双向都成）。
			# 文本帧段序出自服务端 `_send_special_equipment_move:47847-47862`：
			# `flag : 物品体 : slotSrc : inventoryType : slotDst`。
			#
			# ⚠️ 这里必须**同时**维护 `authoritative_special_equipment`：`_apply_inventory_to_session`
			# 每次都会 `_merge_special_equipment()` 把 warp 缓存并回装备表。只 `_clear_item_at_slot(-23)`
			# 不清缓存，等于刚擦掉又被并回来 —— 实测：服务端已把十拳剑挪到背包 115 格、背包里也有剑，
			# 人物窗灵器格却一直挂着（2026-10-25 用户报「十拳剑不能卸下」的第二层病因）。
			# 缓存以「负槽当前权威件」为准同步：空了就删键，有件就覆盖。
			if fields.size() >= 6:
				var 搬件 := _parse_item_entry(String(fields[2]))
				var 源 := int(fields[3])
				var 目标 := int(fields[5])
				if not 搬件.is_empty() and 源 != 目标:
					var 目标原物 := _item_at_slot(目标)
					_clear_item_at_slot(源)
					_clear_item_at_slot(目标)
					_set_item_at_slot(目标, 搬件)
					if not 目标原物.is_empty():
						_set_item_at_slot(源, 目标原物)
					for 位 in [源, 目标]:
						if int(位) < 0:
							var 现有 := _item_at_slot(int(位))
							if 现有.is_empty():
								authoritative_special_equipment.erase(int(位))
							else:
								authoritative_special_equipment[int(位)] = 现有
	_sort_authoritative_inventory()
	_apply_inventory_to_session()
	inventory_delta_received.emit(flag, Array(fields))

func _parse_item_list(encoded: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for entry in encoded.split("@", false):
		var item := _parse_item_entry(entry)
		if not item.is_empty():
			result.append(item)
	return result

func _parse_item_entry(encoded: String) -> Dictionary:
	var values := encoded.split("&", true)
	if values.size() < 10:
		return {}
	var item_type := int(values[0])
	var item_id := String(values[1])
	var slot_index := int(values[2])
	var result := _item_display_fields(item_id, item_type)
	result.merge({
		"type": item_type, "id": item_id, "slot_index": slot_index,
		"quantity": int(values[3]), "price": int(values[4]), "unique_id": int(values[9]),
		# ⚠️ values[6] = canTrade（服务端 `fake_flash_server.py:50818-50829` common_fields
		# 的第 7 段，**所有 ItemCodec 家族都带它**）。原来这里没读 ⇒ 镜像里 can_trade 永远缺、
		# 各读点 `.get("can_trade", true)` 一律当真 —— **绑过定的物品在线照样显示"未绑定"、
		# 菜单里「绑定」项去不掉、绑定这条功能看着像没生效**（2026-10-02 实装绑定时逮到）。
		# 判缺口径与同族 UPDATE 分支（:2788）一致：字段短于 7 段按可交易。
		"can_trade": values.size() < 7 or int(values[6]) == 1,
	}, true)
	if item_type == 1 and values.size() >= 29:
		result.merge({
			"aptitude": int(values[10]), "max_endure": int(values[11]), "endure": int(values[12]),
			"base_attr_type": int(values[13]), "base_attr_value": int(values[14]),
			"born_attr_value": int(values[15]), "strength_value": int(values[16]),
			"plus_attributes": _parse_named_rows(String(values[17]), ["attribute_type", "attribute_value"], "!", "*"),
			"tale_attr_type": int(values[18]), "tale_attr_value": int(values[19]),
			"forge_additive_ratio": int(values[20]), "inlays": _parse_named_rows(String(values[21]), ["stone_id", "stone_level", "attribute_type", "skill_id", "attribute_value"], "!", "*"),
			"strengthen": int(values[22]), "strength_info": _parse_bool_list(String(values[23])),
			"crash_time": int(values[24]), "carve_id": int(values[25]), "carve_type": int(values[26]),
			"carve_value": int(values[27]), "stageup_120_percent": int(values[28]),
		}, true)
		# 特性四段（原版 `CocoEquip.decode` 的 `specialAttrList / specialLevel /
		# specialEffectType / afterimageFlag`）：文本桥**只在装备段尾部**才补，
		# 老帧（不足 33 段）当空/0 —— 变身卡的「特性」栏与装备提示框的特性段都用它。
		if values.size() >= 33:
			result.merge({
				"special_attributes": _parse_named_rows(String(values[29]), ["attribute_type", "attribute_value"], "!", "*"),
				"special_level": int(values[30]),
				"special_effect_type": int(values[31]),
				"afterimage_flag": int(values[32]),
			}, true)
	elif item_type == 6 and values.size() >= 11:
		result["plus_attributes"] = _parse_named_rows(String(values[10]), ["attribute_type", "attribute_value"], "!", "*")
	return result

func _parse_bool_list(encoded: String) -> Array[bool]:
	var result: Array[bool] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for value in encoded.split("!", false):
		result.append(String(value).to_lower() == "true" or String(value) == "1")
	return result

func _item_display_fields(item_id: String, item_type: int) -> Dictionary:
	var definition := GAME_DATA.item(item_id)
	# 装备位的判定**只看 id**（照原版 `EquipmentPosition.getItemEquipPosition`），
	# 不看线上传来的 `type` —— 那套 1/4/5/6 的口径覆盖不全，神器/灵器/人具都不在里面。
	var equip_position := 装备部位.位置(item_id)
	var is_equipment := equip_position != 0
	return {
		"name": GAME_DATA.item_name(item_id), "equip_position": equip_position,
		"slot": 装备部位.显示名(equip_position) if equip_position < 0 else "",
		"category": String(definition.get("category", "装备" if is_equipment else "物品")),
		"req_level": int(definition.get("required_level", 0)), "icon": GAME_DATA.item_icon_path(item_id),
		# 菜单「全部使用」的数据源（原版 `filtrateItemMenu` :520 读 `info.useAll`）；
		# 客户端表由 `开发工具/导出物品use_all.py` 从服务端 catalog 补齐（2026-10-01）。
		"use_all": int(definition.get("use_all", 0)),
	}

## 物品 id → 装备位置（原版 `EquipmentPosition.getItemEquipPosition`）。
## 原来这里是本地一张表，缺 2010(→灵器)/6500(→忍具)，且 `_item_display_fields` 那边
## 靠线上 `type ∈ 1/4/5/6` 判装备，那套口径覆盖不全。现在统一走 `脚本/单例/装备部位.gd`。
func _equipment_position_for_item(item_id: String) -> int:
	return 装备部位.位置(item_id)

func _item_at_slot(slot: int) -> Dictionary:
	if slot < 0:
		return (authoritative_equipment.get(slot, {}) as Dictionary).duplicate(true)
	for item in authoritative_inventory:
		if int(item.get("slot_index", 0)) == slot:
			return item.duplicate(true)
	return {}

func _set_item_at_slot(slot: int, item: Dictionary) -> void:
	_clear_item_at_slot(slot)
	var stored := item.duplicate(true)
	stored["slot_index"] = slot
	if slot < 0:
		stored["equip_position"] = slot
		stored["slot"] = _equipment_name(slot)
		authoritative_equipment[slot] = stored
	else:
		authoritative_inventory.append(stored)

func _clear_item_at_slot(slot: int) -> void:
	if slot < 0:
		authoritative_equipment.erase(slot)
		return
	for index in range(authoritative_inventory.size() - 1, -1, -1):
		if int(authoritative_inventory[index].get("slot_index", 0)) == slot:
			authoritative_inventory.remove_at(index)

func _set_slot_quantity(slot: int, quantity: int) -> void:
	if quantity <= 0:
		_clear_item_at_slot(slot)
		return
	var item := _item_at_slot(slot)
	if item.is_empty():
		return
	item["quantity"] = quantity
	_set_item_at_slot(slot, item)

func _swap_inventory_slots(source: int, destination: int) -> void:
	var source_item := _item_at_slot(source)
	var destination_item := _item_at_slot(destination)
	_clear_item_at_slot(source)
	_clear_item_at_slot(destination)
	if not source_item.is_empty():
		_set_item_at_slot(destination, source_item)
	if not destination_item.is_empty():
		_set_item_at_slot(source, destination_item)

func _sort_authoritative_inventory() -> void:
	authoritative_inventory.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.get("slot_index", 0)) < int(right.get("slot_index", 0)))

## 位置 → 显示名。原来本地那张表里 **-20 叫「神器」、-21 叫「神器附槽」是错的**
## （-20 是 EquipS1 勾玉、-21 是 EquipSZ 变身），错名会让两个槽互相认不出来。
## 现统一走 `脚本/单例/装备部位.gd`。
func _equipment_name(position: int) -> String:
	return 装备部位.显示名(position)

## 把 warp 帧那三截负槽特殊装备并进当前装备表。
## ⚠️ 2050 快照会 `authoritative_equipment.clear()`，所以每次快照应用前都要**重新并一次**，
## 不能只在 warp 那一下并。
func _merge_special_equipment() -> void:
	for 位 in authoritative_special_equipment:
		authoritative_equipment[位] = (authoritative_special_equipment[位] as Dictionary).duplicate(true)

func _apply_inventory_to_session() -> void:
	_merge_special_equipment()
	inventory_received.emit(authoritative_inventory.duplicate(true), authoritative_equipment.duplicate(true))
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_inventory"):
		session.apply_backend_inventory(authoritative_inventory, authoritative_equipment)

func _handle_card_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var action := int(fields[1])
	var state: Dictionary = authoritative_card.duplicate(true)
	state["action"] = action
	state["level"] = int(fields[2])
	if action == 0:
		var nodes: Array[Dictionary] = []
		if fields.size() >= 4 and fields[3] != "-":
			for encoded in fields[3].split("@", false):
				var part := encoded.split("&", false)
				if part.size() >= 2:
					nodes.append({"node_id": int(part[0]), "committed": int(part[1]) != 0,
						"claimed": int(part[2]) != 0 if part.size() >= 3 else false,
						"gain_ap": int(part[3]) if part.size() >= 4 else 0})
		state["nodes"] = nodes
		state["code"] = String(fields[4]) if fields.size() >= 5 else "ok"
	elif action == 1 and fields.size() >= 7:
		state["node_id"] = int(fields[3])
		state["committed"] = int(fields[4]) != 0
		state["claimed"] = int(fields[5]) != 0
		var items: Array[Dictionary] = []
		if fields[6] != "-":
			for encoded in fields[6].split("@", false):
				var part := encoded.split("&", false)
				if part.size() >= 2:
					# ⚠️ 第二个字段是**已提交数**，不是"背包拥有数" —— 原版
					# `CardNodeItemInfo.decode` 只有 `{itemId, count}` 两段，
					# 而 `GuwanshoujiInfoPanel.getCurCount:147-159` 拿它当"已收集"用
					# （`setTextFieldData:38` 那句"够了就整串绿"比的就是它）。
					# 旧名字叫 `owned`，容易读成"拥有" ⇒ 2026-10-11 改名 `submitted`。
					items.append({"item_id": int(part[0]), "submitted": int(part[1]),
						"required": int(part[2]) if part.size() >= 3 else 0})
		state["items"] = items
		state["gain_ap"] = int(fields[7]) if fields.size() >= 8 else 0
		state["code"] = String(fields[8]) if fields.size() >= 9 else "ok"
	authoritative_card = state
	card_state_received.emit(state.duplicate(true))

func _handle_chest_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var action := int(fields[1])
	var state: Dictionary = authoritative_chest.duplicate(true)
	state["action"] = action
	state["object_id"] = int(fields[2])
	match action:
		0:
			state["chest_id"] = int(fields[3]) if fields.size() >= 4 else int(fields[2])
			state["open"] = fields.size() >= 5 and int(fields[4]) != 0
			state["code"] = String(fields[7]) if fields.size() >= 8 else "ok"
		1:
			state["open"] = false
			state["code"] = String(fields[3]) if fields.size() >= 4 else "ok"
		2:
			state["open"] = fields.size() >= 4 and int(fields[3]) != 0
			state["code"] = String(fields[4]) if fields.size() >= 5 else "ok"
		3:
			var items: Array[Dictionary] = []
			if fields.size() >= 4 and fields[3] != "-":
				for encoded in fields[3].split("@", false):
					var part := encoded.split("&", false)
					if part.size() >= 5:
						items.append({"slot": int(part[0]), "item_id": int(part[1]), "quantity": int(part[2]),
							"bind": int(part[3]), "claimed": int(part[4]) != 0})
			state["items"] = items
			state["completed"] = fields.size() >= 5 and int(fields[4]) != 0
			state["code"] = String(fields[5]) if fields.size() >= 6 else "ok"
	authoritative_chest = state
	chest_state_received.emit(state.duplicate(true))

func _handle_buff_fusion_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	authoritative_buff_fusion = {
		"action": int(fields[1]), "item_id": int(fields[2]),
		"success": fields.size() >= 4 and int(fields[3]) != 0,
		"code": String(fields[4]) if fields.size() >= 5 else "ok",
	}
	buff_fusion_received.emit(authoritative_buff_fusion.duplicate(true))

## `1284:<对象号>:<type>:<id>:<hp>:<maxHp>:<mp>:<maxMp>` —— 服务端三处写者：
##   怪 `:20215-20220`（`type=0`，id = 模板号，mp 两槽写死 0）
##   玩家 `:20266-20273`（`type=1`，id = 角色号；这一发就是「查看信息」那颗钮换来的）
##   地图旗 `:20220-20224`（`type=2`，血 10000/10000）
## 段数不够（老端/噪声）**整条丢**，不拿默认值凑半条：凑出来的会把别人的血量填进当前目标。
func _handle_target_info_text(fields: PackedStringArray) -> void:
	if fields.size() < 8:
		return
	var 类 := int(fields[2])
	if not (类 in [0, 1, 2]):
		return
	target_info_received.emit({
		"object_id": int(fields[1]), "type": 类, "id": int(fields[3]),
		"hp": int(fields[4]), "max_hp": int(fields[5]),
		"mp": int(fields[6]), "max_mp": int(fields[7]),
	})


func _handle_heal_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state: Dictionary = authoritative_heal.duplicate(true)
	state["action"] = action
	match action:
		1:
			## ⚠ 段序与原版**不同**：原版 `HealProcessor.as:handleHealStateChange` 读的是
			## `state, partnerId, charId`，我们这条文本桥是 `state, character_id, partner_id`
			## （服务端 `_send_heal_state:35045-35050` 与同意那一支都是这个写法）。
			## 照原版段序解会把**单修/停坐**那两支持续丢帧（第 4 段是我的号，不是 0）⇒ 别去"改正"它，
			## 要改就同时改服务端（那是改协议，得点头）。
			var 态 := int(fields[2]) if fields.size() >= 3 else 0
			var 说的是谁 := int(fields[3]) if fields.size() >= 4 else character_id
			var 伙伴 := int(fields[4]) if fields.size() >= 5 else 0
			if 说的是谁 != character_id:
				## 原版**不是**"整条丢掉"：`HealHandler.as:250` 判完 `charId == stats.id` 之后还有一个
				## else 支（`:315-331`）—— 把这一帧写到**那一具身体**上去（`getCharacter(charId)`，
				## 态 0/1 清 `healPartnerId`、态 2 记 `healPartnerId = partnerId`）。
				## 服务端同意那一支给同一条连接连发两帧（`:34884/:34889` 两个号对调），
				## **正是为了让一台客户端同时知道两具身体各自的伙伴是谁** ⇒
				## `CharacterHandler.tickHealDouble:728` 那句 `_loc3_.healPartnerId != 0` 才可能真，
				## 才有"两个人一起浮、对面那具把 y 抄过来"（`:753-754 _loc3_.y = param1.y`）。
				## 少写这一半 ⇒ 我这侧的远程那具永远不跟浮（10-17 现查 AS3 才补上）。
				if 态 == 2:
					远程双修伙伴[说的是谁] = 伙伴
				else:
					远程双修伙伴.erase(说的是谁)
				return
			state["state"] = 态
			state["character_id"] = 说的是谁
			state["partner_id"] = 伙伴
		2:
			state["pending_inviter_id"] = int(fields[2]) if fields.size() >= 3 else 0
			state["pending_inviter_name"] = String(fields[3]) if fields.size() >= 4 else ""
		3:
			state["xinfa_id"] = int(fields[2]) if fields.size() >= 3 else 0
		4:
			state["denied_by"] = int(fields[2]) if fields.size() >= 3 else 0
		5:
			state["invited_character_id"] = int(fields[2]) if fields.size() >= 3 else 0
	authoritative_heal = state
	heal_state_received.emit(state.duplicate(true))

## 2318 的三个下行动作，字段**逐字照 `JieYinProcessor`**（`:85-132`）：
##   · 0 `action_UpdateJieYinStatus` = `stage:int, count:int` —— **只有这两个**。
##     原来这里还顺手补了 `need_zq/need_count/zq` 三个"缺省值"，那是**线上没有的字段**：
##     原版这两档消耗是客户端读的 Etc 表（`Etc.JieYin.stages.stageN.stageUp`，本工程
##     `数据/原版杂项.json`）⇒ 界面一律走表（见 `人物窗口.结印阶段配置`），不从帧里猜。
##   · 1 `action_showJieYinBuffEffect` = 6 个 int（buff 生效，走 `_handle_buff_*`，不在这一支）
##   · 2 `action_JieYinEatUpResult` = `result:int, addCount:int`
##     ⚠️ `result` **不是**"这一跳有没有加熟练度"，而是"**阶段推上下一层了没有**" ——
##     原版拿它只做一件事（`JieYinTiShengWindow.onJieYin_stageupResult:182-193`）：
##     1 就 `clearTimeout` 停自动、否则还在自动态就 0.8 秒后再跳一发。
##     ⚠️ 也别叫它"成功/失败"：结印**每一跳都会加**熟练度（`addCount`），
##     所以 `success` 这个键名在这里的含义 = **升阶**（`功能窗口._收到结印帧` 就按这个停）。
func _handle_jieyin_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state: Dictionary = authoritative_jieyin.duplicate(true)
	state["action"] = action
	if action == 0 and fields.size() >= 4:
		state.merge({"stage": int(fields[2]), "count": int(fields[3])}, true)
	elif action == 2:
		state.merge({"success": fields.size() >= 3 and int(fields[2]) != 0,
			"added": int(fields[3]) if fields.size() >= 4 else 0}, true)
	authoritative_jieyin = state
	authoritative_cultivation["结印"] = state.duplicate(true)
	jieyin_state_received.emit(state.duplicate(true))
	cultivation_received.emit("结印", state.duplicate(true))

func _handle_anqi_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state: Dictionary = authoritative_anqi.duplicate(true)
	state["action"] = action
	if action == 0 and fields.size() >= 6:
		state.merge({"stage": int(fields[2]), "level": int(fields[3]), "master": int(fields[4]),
			"open": fields[5] == "true" or int(fields[5]) != 0,
			"blessing": int(fields[6]) if fields.size() >= 7 else 0,
			"master_max": int(fields[7]) if fields.size() >= 8 else 5000,
			"need_item_id": int(fields[8]) if fields.size() >= 9 else 0,
			"need_item_count": int(fields[9]) if fields.size() >= 10 else 0,
			"need_gold": int(fields[10]) if fields.size() >= 11 else 0,
			"need_zq": int(fields[11]) if fields.size() >= 12 else 0}, true)
	elif action == 1:
		state["blessing"] = int(fields[2]) if fields.size() >= 3 else 0
	elif action == 3:
		# 升阶结果帧 `1817:3:<0|1>:<true|false>`（服务端 `_advance_stage_cultivation` 尾部
		# `result_action = 3 if server_opcode == AN_QI else RESULT`）。修前这里只存字段、
		# **一句提示不弹、也不发 `修炼结果帧`** ⇒ 手里剑突破成功/失败玩家零反馈（2026-10-20 报修 2.1）。
		# 文案逐字照 `JingMaiSource.as:271-286 onAnQi_stageupResult`（成功/失败 × 是否用神符四句）。
		# ⚠️ 本工程没有语言表可读，字面量按其余几族已落的同款写。
		var 手里剑成功 := fields.size() >= 3 and int(fields[2]) != 0
		var 手里剑用神符 := fields.size() >= 4 and (fields[3] == "true" or int(fields[3]) != 0)
		state.merge({"success": 手里剑成功, "used_guarantee": 手里剑用神符,
			"last_success": 手里剑成功, "last_used_fake": 手里剑用神符,
			"code": String(fields[4]) if fields.size() >= 5 else "ok"}, true)
		_通知("恭喜你，使用手里剑神符进阶成功" if 手里剑成功 and 手里剑用神符
			else "恭喜你进阶成功！" if 手里剑成功
			else "进阶失败，手里剑神符-1" if 手里剑用神符
			else "很抱歉，进阶失败！")
		修炼结果帧.emit("手里剑", 手里剑成功, 手里剑用神符)
	authoritative_anqi = state
	authoritative_cultivation["手里剑"] = state.duplicate(true)
	anqi_state_received.emit(state.duplicate(true))
	cultivation_received.emit("手里剑", state.duplicate(true))

func _handle_xiuxing_text(fields: PackedStringArray) -> void:
	cultivation_received.emit("修炼", {"fields": Array(fields)})

## 别人忍术境界总层数（`1348:<角色号>:<总层数>`，原版 `Character.setTotalSkillLevel`）。
## 摆位/贴图在 `地图实体`，这里只管把数落进 `map_players` 并转发。
func _handle_char_skill_level_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	var 角色号 := int(fields[1])
	var 总层 := int(fields[2])
	if 角色号 <= 0:
		return
	var 状态: Variant = map_players.get(角色号)
	if 状态 is Dictionary:
		(状态 as Dictionary)["总层数"] = 总层
	他人忍术境界收到.emit(角色号, 总层)


func _handle_cultivation_text(opcode: int, fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	# ⚠️ **这里没有 2318**：结印走自己的 `_handle_jieyin_text`。它的结果帧
	#   `2318:2:<result>:<addCount>` 字段语义与别族**不一样**（`result` = 有没有把阶段推上下一层，
	#   后面那个是**加的熟练度**、不是"用没用神符"），一旦让它落进下面那条别族支，
	#   玩家每跳一次自动提升就会被弹一句「很抱歉，进阶失败！」——原版结印**一句提示都不弹**
	#   （`Client.onJieYin_eatUpResult:8285-8291` 只转给提升弹窗驱动循环）。
	var kind: String = {1290: "八门", 1817: "手里剑", 1821: "写轮眼", 2307: "柔拳", 2313: "轮回六道"}.get(opcode, "")
	var action := int(fields[1])
	var state: Dictionary = authoritative_cultivation.get(kind, {}).duplicate(true)
	## 八门倒计时帧的秒数：本函数**末尾**（状态已落库）才发信号，见动作 1 那段。
	var 待发倒计时 := -1
	if action == 0:
		match kind:
			"手里剑":
				if fields.size() >= 6:
					state.merge({"stage": int(fields[2]), "level": int(fields[3]), "master": int(fields[4]), "open": fields[5] == "true" or int(fields[5]) != 0}, true)
			"结印", "柔拳", "写轮眼", "轮回六道":
				if fields.size() >= 4:
					state.merge({"stage": int(fields[2]), "count": int(fields[3])}, true)
	elif kind == "八门":
		# ⚠️ 八门的回包**动作号跟别族不一样**，照原版 `MaiProcessor.handleMaiStatePacket`：
		#   1 = 开通倒计时帧 · **2 = 一门已开数更新** · **3 = 统计帧** · 4/5 = 突破信息。
		#   （⚠️ 服务端发统计帧时借的是请求枚举 `MaiAction.LEVEL_UP` = 3 那个值，别被名字带跑；
		#    八门**没有**祝福值那一支 —— `_send_cultivation_blessing` 只给手里剑/柔拳/写轮眼那几族发。）
		if action == 3 and fields.size() >= 4:
			# `1290 : 3 : list_id : exploded : 属性列 : 总穴位数 : 已开穴位数 : 共享经验 : 共享次数`
			# `exploded` = 每门 `mai_id&已开穴位数`，用 `@` 连（`-` = 空）。
			# 数据面 2026-10-14 才通：此前这一支落进通用分支、把 list_id 当 blessing 存，
			# 而真正要用的 list_id / 每门已开数 / 总进度全丢了 ⇒ 八门页永远点不亮穴位。
			state.merge({
				"list_id": int(fields[2]),
				"exploded": _parse_八门已开(String(fields[3])),
				# fields[4] = `totalAttrGain`（原版 `MaiStatistic.decode:30` 里那个 SubAttribute，
				# 就是突破弹窗 块1 那两行「已为你提升属性」的唯一来源 ⇒ 不解析就只能显示
				# 设计师烘的假数（2026-10-17 巡检 #8）。
				"attrs": _parse_八门属性列(String(fields[4])),
				"total_points": int(fields[5]) if fields.size() > 5 else 0,
				"exploded_total": int(fields[6]) if fields.size() > 6 else 0,
				"shared_exp": int(fields[7]) if fields.size() > 7 else 0,
				"shared_exp_count": int(fields[8]) if fields.size() > 8 else 0,
			}, true)
		elif action == 2 and fields.size() >= 5:
			# 开通一次的结果帧（成功失败都发）：`2:list_id:mai_id:该门已开穴位数`
			# （服务端 `_send_mai_attempt_result` / `_resolve_pending_mai_explosion`）。
			# 成功要**当场点亮那一枚**，所以这门已开数要跟着更新。
			var 已开: Dictionary = (state.get("exploded", {}) as Dictionary).duplicate()
			已开[int(fields[3])] = int(fields[4])
			state.merge({"list_id": int(fields[2]), "exploded": 已开}, true)
		elif action == 1 and fields.size() >= 4:
			# ⚠️⚠️ 八门**动作 1 = 延迟引爆（倒计时）帧**，字段序照原版
			#    `MaiProcessor.actionMaiDelayExplode`：`playerId(int) / delaySeconds(int) / lastPt(bool)`
			#    ⇒ `1290:1:<角色号>:<剩余秒>:<true|false>`。
			#    **原来这一支被当成"祝福值"吞了**（而且代码写在 `elif kind == "八门"` 块**外面**，
			#    八门的帧压根走不到它）⇒ 原版那套「关掉人物窗 → 等 N 秒 → 再开回来」
			#    （`Client.as:11464-11485`）一步都没发生 ⇒ 玩家点完开通只看到一句
			#    "请求已发送，等待服务端"、**画面一动不动**（用户 2026-10-16 报的就是这个）。
			#    八门**没有**祝福值那一支（`_send_cultivation_blessing` 只给别族发）。
			state.merge({
				"countdown_seconds": int(fields[3]),
				# 字段名照原版：`lastPt` = 这一枚是不是该门最后一个穴位 ⇒ 归零爆点的大小。
				# （旧名 `countdown_point_ok` 是误读 —— 它跟"成功"无关，成功才发这一帧。）
				"countdown_last_point": String(fields[4]).to_lower() == "true" if fields.size() > 4 else false,
			}, true)
			# 只有"我自己点的"才关窗（原版 `:11473` `playerId == API.dataCenter.stats.id`）。
			# ⚠ 信号必须**等状态落库之后**再发：地图人物那边要靠
			#   `authoritative_cultivation["八门"]["countdown_last_point"]` 决定爆点大小，
			#   发早了拿到的是上一帧的旧状态（2026-10-20 踩过：最后一枚也炸成小爆）。
			if int(fields[2]) == character_id:
				待发倒计时 = int(fields[3])
		elif action == 4 and fields.size() >= 5:
			# `1290:4:<角色号>:<脉>:<该脉已开通的门数>` —— 原版 `MaiProcessor.actionUpdateMaiExplodedCount`
			#   （`chrId=int / maiListId=byte / maiExplodedCount=int`）→ `CharacterHandler.as:962`
			#   → `Character.setMaiExploedCount(脉, 数)`：**只改地图人物身上的光环外观**
			#   （0..8 一档，`listId==0` 直接用、其余按档位 +8/+16 偏移），**不进人物窗**。
			#   服务端 `_send_mai_character_progress` 在「穴位引爆结算」与「突破成功」后各发一发。
			#   ⚠️ 别拿它当八门页的数据源：页上那些已开穴位数只认统计帧（动作 3）。
			state.merge({"look_list_id": int(fields[3]), "look_exploded_gates": int(fields[4])}, true)
		elif action == 5 and fields.size() >= 8:
			# `1290:5:<脉>:<属性列>:<下一脉>:<道具号>:<道具数>:<精华>` ——
			#   原版 `MaiProcessor.actionShowLevelupInfo` → `MaiLevelupInfo.decode`
			#   （`lastListId / lastAttrGain / nextListId / itemId / itemCount / zhenqi`；
			#   `nextAttrGain` 原版**只 new、不解码** ⇒ 线上没有那一段，是 6 个字段不是 7 个）。
			#   ⚠️⚠️ **原版 `Client.onMaiLevelupInfo` 是空函数**，而 `requestMaiLevelUpInfo`
			#   全工程也没有一处调用 ⇒ 这一帧在原版根本没人用：突破弹窗的道具/精华/几率
			#   全部来自**客户端配置表**（`JingMaiSource.getTroughConfig()` =
			#   `Mai/info/levelup[<脉+1>]`，本工程已导出到 `数据/经脉.json`）。
			#   这里照样解析存下（服务端主动发时不静默丢），但**界面以配置表为准**才与原版一致；
			#   两边对不上就是服务端那份表导错了，按 §0 第 1 条回头修服务端。
			state.merge({"levelup_info": {
				"list_id": int(fields[2]),
				"attrs": _parse_八门属性列(String(fields[3])),
				"next_list_id": int(fields[4]),
				"item_id": int(fields[5]),
				"item_count": int(fields[6]),
				"zq": int(fields[7]),
			}}, true)
	elif kind != "八门" and action == 2 and fields.size() >= 4:
		# 升阶结果帧（服务端 `_advance_stage_cultivation` 发 `<opcode>:2:<0|1>:<true|false>`
		#   = 成功与否、是否用神符）。**修前这一支整条被丢** ⇒ 点「开始提升」成功/失败玩家零反馈
		#   （2026-10-17 巡检）。提示文案逐族照原版：`RouQuanManager.as:36-50`、
		#   `TongshuSource.as:61-87`、`LunHuiYanManager.as:52-56`（轮回六道原版就复用的是
		#   **柔拳**那两句话，照抄不"纠正"）。原版写轮眼成功还关提升面板（`onCloseBtnClick`）——
		#   本工程结果帧后必跟 blessing+状态帧 ⇒ 整页重建、弹窗回到隐藏，效果等价。
		var 成功 := int(fields[2]) != 0
		var 用神符 := String(fields[3]).to_lower() == "true"
		state["last_success"] = 成功
		state["last_used_fake"] = 用神符
		if kind == "写轮眼":
			_通知("恭喜你，使用写轮眼神符提升成功。" if 成功 and 用神符
				else "恭喜你进阶成功！" if 成功
				else "提升失败，写轮眼神符-1" if 用神符
				else "很抱歉，进阶失败！")
		else:
			_通知("恭喜你，使用柔拳神符进阶成功" if 成功 and 用神符
				else "恭喜你进阶成功！" if 成功
				else "进阶失败，柔拳神符-1" if 用神符
				else "很抱歉，进阶失败！")
		# 提示发完再把这一跳的结果交给界面 —— 原版也是"管理器先 addNotice、弹窗后驱动循环"
		# （`TongshuSource.onXieLunYan_stageupResult:61-86` 就是先 `API.ui.addNotice` 再 `setTimeout`）。
		修炼结果帧.emit(kind, 成功, 用神符)
	# 别的族的祝福值（`_send_cultivation_blessing` 只给手里剑/柔拳/写轮眼那几族发）。
	# ⚠️ 必须排除八门：八门的动作 1 是**倒计时帧**，上面那支已经处理掉了。
	if kind != "八门" and action == 1 and fields.size() >= 3:
		state["blessing"] = int(fields[2])
	authoritative_cultivation[kind] = state
	cultivation_received.emit(kind, state.duplicate(true))
	# 状态落库之后再喊倒计时（地图人物与人物窗都在这条线上取 `countdown_last_point`）。
	if 待发倒计时 >= 0:
		八门倒计时.emit(待发倒计时)

## 给玩家一句话（等价原版 `API.ui.addNotice(...)`：走会话的通知口子，落到界面那条提示行）。
func _通知(文本: String) -> void:
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null and 会话.has_signal("notification_requested"):
		会话.emit_signal("notification_requested", 文本)


## 八门统计帧里那段 `exploded`（`mai_id&已开穴位数` 用 `@` 连，`-` = 一门都没开）。
## ⇒ `{门序号: 已开穴位数}`。门序号就是 `mai_id`（0 基）。
func _parse_八门已开(编码: String) -> Dictionary:
	var 出: Dictionary = {}
	if 编码.is_empty() or 编码 == "-":
		return 出
	for 条 in 编码.split("@", false):
		var 对 := String(条).split("&")
		if 对.size() < 2:
			continue
		出[int(对[0])] = int(对[1])
	return 出


## 八门属性列（统计帧 fields[4] / 突破信息帧 fields[3]）：`属性号&值` 用 `@` 连，`-` = 全零。
## 属性号就是原版 `SubAttrType`（`com/mxw/data/attribute/SubAttrType.as`）：
## 1=MAXHP 2=MAXMP 4=ATK 5=DEF 6=BSK 7=AVD（服务端 `_mai_sub_attribute_rows` 同一套号）。
## ⇒ `{maxhp/maxmp/atk/def/bsk/avd: 值}`；认不出的号**丢掉**（宁可少显示一项，不猜）。
func _parse_八门属性列(编码: String) -> Dictionary:
	var 出: Dictionary = {}
	if 编码.is_empty() or 编码 == "-":
		return 出
	var 名字 := {1: "maxhp", 2: "maxmp", 4: "atk", 5: "def", 6: "bsk", 7: "avd"}
	for 条 in 编码.split("@", false):
		var 对 := String(条).split("&")
		if 对.size() < 2 or not 名字.has(int(对[0])):
			continue
		出[String(名字[int(对[0])])] = int(对[1])
	return 出


## 给玩家一句话（等价原版 `API.ui.addNotice(...)`：走会话的通知口子，落到界面那条提示行）。


func _handle_copy_action_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	match action:
		0:
			var history := {}
			if fields.size() >= 3 and fields[2] != "-":
				for entry in fields[2].split("@", false):
					var pair := entry.split("&", false)
					if pair.size() >= 2:
						history[int(pair[0])] = int(pair[1])
			state["history"] = history
			state["total_count"] = int(fields[3]) if fields.size() >= 4 else 1
		1:
			state["pending_copy_id"] = int(fields[2]) if fields.size() >= 3 else -1
			state["countdown"] = int(fields[3]) if fields.size() >= 4 else 0
		2, 6, 10:
			state["copy_id"] = int(fields[2]) if fields.size() >= 3 else -1
		5:
			state.merge({
				"copy_id": int(fields[2]) if fields.size() >= 3 else -1,
				"copy_type": int(fields[3]) if fields.size() >= 4 else 0,
				"pass_time": int(fields[4]) if fields.size() >= 5 else 0,
				"character_id": int(fields[5]) if fields.size() >= 6 else 0,
				"min_cost_time": int(fields[6]) if fields.size() >= 7 else 0,
			}, true)
		8:
			state["copy_id"] = int(fields[2]) if fields.size() >= 3 else -1
			var rewards: Array[Dictionary] = []
			if fields.size() >= 4 and fields[3] != "-":
				for entry in fields[3].split("@", false):
					var pair := entry.split("&", false)
					if pair.size() >= 2:
						rewards.append({"item_id": int(pair[0]), "quantity": int(pair[1])})
			state["rewards"] = rewards
		9:
			state["copy_id"] = int(fields[2]) if fields.size() >= 3 else -1
			state["success"] = fields.size() >= 4 and int(fields[3]) == 1
	copy_state_received.emit(state)

## 1283 回帧（服务端 `_send_char_config` 的文本分支，`fake_flash_server.py:17885-17895`）：
## `1283:` + 45 个 `CHAR_CONFIG_FIELDS` 的值 + 1 段 keyData + 13 个扩展值 = **60 段**。
## 段里**没有键名**，全靠位置 ⇒ 键表顺序必须与服务端那两条元组逐字一致（含 `auot*` 的错拼）。
## keyData 用 `&`/`@` 拼（空时是 `-`），属于快捷键页的数据，这里按段跳过、不塞进配置表。
func _handle_char_config_text(fields: PackedStringArray) -> void:
	var 值们: PackedStringArray = fields.slice(1)
	if 值们.size() < 挂机配置字段.size():
		push_warning("1283 回帧只有 %d 段，少于 %d 个配置字段" % [
			值们.size(), 挂机配置字段.size()])
	var 配 := {}
	for i in mini(挂机配置字段.size(), 值们.size()):
		配[String(挂机配置字段[i])] = _解配置段(值们[i])
	var 扩起: int = 挂机配置字段.size() + 1
	for i in 挂机扩展字段.size():
		var 序: int = 扩起 + i
		if 序 < 值们.size():
			配[String(挂机扩展字段[i])] = _解配置段(值们[序])
	char_config_received.emit(配)


static func _解配置段(原文: String) -> Variant:
	# 服务端 `_format_config_value`：bool → "true"/"false"，None → "0"，其余 str(值)。
	if 原文 == "true":
		return true
	if 原文 == "false":
		return false
	if 原文.is_valid_int():
		return int(原文)
	if 原文.is_valid_float():
		return float(原文)
	return 原文


func _handle_hang_action_text(fields: PackedStringArray) -> void:
	if fields.size() < 3:
		return
	hang_state_received.emit({
		"action": int(fields[1]),
		"active": int(fields[2]) == 1,
		"started_at": int(fields[3]) if fields.size() >= 4 else 0,
		"map_id": int(fields[4]) if fields.size() >= 5 else 0,
		"elapsed_seconds": int(fields[5]) if fields.size() >= 6 else 0,
	})

func _handle_cash_shop_list_text(fields: PackedStringArray, source: String) -> void:
	if fields.size() < 4:
		return
	var items: Array[Dictionary] = []
	if fields[3] != "-":
		for encoded in fields[3].split("@", false):
			var decoded := _decode_cash_item_fields(encoded.split("&", true))
			if not decoded.is_empty():
				items.append(decoded)
	authoritative_cash_shop.assign(items)
	authoritative_cash_shop_total = maxi(0, int(fields[1]))
	cash_shop_received.emit(authoritative_cash_shop.duplicate(true), authoritative_cash_shop_total, source)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("apply_backend_cash_shop"):
		session.apply_backend_cash_shop(authoritative_cash_shop, authoritative_cash_shop_total, source)

func _handle_cash_item_info_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var encoded_fields: PackedStringArray
	if fields.size() == 2:
		encoded_fields = fields[1].split("&", true)
	else:
		encoded_fields = fields.slice(1)
	var decoded := _decode_cash_item_fields(encoded_fields)
	if decoded.is_empty():
		return
	for index in authoritative_cash_shop.size():
		if int(authoritative_cash_shop[index].get("sn", 0)) == int(decoded.get("sn", 0)):
			authoritative_cash_shop[index] = decoded
			break
	cash_item_info_received.emit(decoded.duplicate(true))

## `1282:<search_id>:<行…>`，行 = `线&角色id&等级&职业&名字&家族id&家族名&-`
## （服务端 `handle_char_search` 的 `rows`）。离线时线 = -1。
func _handle_char_search_text(fields: PackedStringArray) -> void:
	authoritative_char_search_类型 = int(fields[1]) if fields.size() > 1 else 0
	var 结果: Array[Dictionary] = []
	if fields.size() > 2 and String(fields[2]) != "-":
		for entry in String(fields[2]).split("@", false):
			var parts := entry.split("&", true)
			if parts.size() >= 7:
				结果.append({
					"line": int(parts[0]), "character_id": int(parts[1]), "level": int(parts[2]),
					"job": int(parts[3]), "name": String(parts[4]),
					"family_id": int(parts[5]), "family": String(parts[6]),
					"online": int(parts[0]) >= 0,
				})
	authoritative_char_search.assign(结果)
	char_search_received.emit(authoritative_char_search.duplicate(true))

## 地图族旗列表（`1815:0:<行@行>`，行 = `&` 拼的 12 个字段）。
## 字段序**逐条取 `MapFlagInfo.decode`**，与服务端 `_encode_local_flag_info` 的写者一致：
##   map_id / x / y / channel / bang_id / bangName / flag_hp / flag_maxhp /
##   flag_level / flag_style / flag_color / flag_name
## 族旗的**一行 12 字段**（`MapFlagInfo.decode`，`data/flag/MapFlagInfo.as`）：
##   map_id / x / y / channel / bang_id / bangName / flag_hp / flag_maxhp /
##   flag_level / flag_style / flag_color / flag_name
## ⚠️ 动作 0（全表）里每行是 `&` 连接的这 12 个字段；动作 1（生成）里服务端直接把同样格式
##    的一串放在 `fields[2]` —— 两处**共用这一份解析**，别再抄第二遍（抄反过一次的就是它）。
static func _解族旗行(parts: PackedStringArray) -> Dictionary:
	if parts.size() < 12:
		return {}
	return {
		"map_id": int(parts[0]), "x": int(parts[1]), "y": int(parts[2]),
		"channel": int(parts[3]), "bang_id": int(parts[4]),
		"bang_name": String(parts[5]),
		"flag_hp": int(parts[6]), "flag_maxhp": int(parts[7]),
		"flag_level": int(parts[8]), "flag_style": int(parts[9]),
		"flag_color": int(parts[10]), "flag_name": String(parts[11]),
	}


func _handle_flag_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	match int(fields[1]):
		0:
			var 结果: Array[Dictionary] = []
			if fields.size() > 2 and fields[2] != "-":
				for entry in fields[2].split("@", false):
					var 行 := _解族旗行(entry.split("&", true))
					if not 行.is_empty():
						结果.append(行)
			authoritative_flag_list.assign(结果)
			flag_list_received.emit(authoritative_flag_list.duplicate(true))
		1:
			# 原版动作 1 = `actionSpawnMapFlag`：`flagOid:int` + `MapFlagInfo`。
			# 本机服务端（`_local_flag_spawn_payload`）把 **flagOid 直接用了地图号** ——
			# 一面图一面旗，取哪个都行，这里按"地图号即 oid"收。
			if fields.size() < 3 or fields[2] == "-":
				return
			var 旗 := _解族旗行(String(fields[2]).split("&", true))
			if 旗.is_empty():
				return
			authoritative_map_flag = 旗
			map_flag_changed.emit(旗.duplicate(true))
		2:
			authoritative_map_flag = {}
			map_flag_changed.emit({})
		4:
			# `actionChangeMapFlagHp`：`map_id, flagOid, hp`（`MapFlagProcessor.as:68-87`）。
			if fields.size() < 5:
				return
			if int(fields[2]) != int(authoritative_map_flag.get("map_id", -1)):
				return
			authoritative_map_flag["flag_hp"] = int(fields[4])
			map_flag_changed.emit(authoritative_map_flag.duplicate(true))


func _handle_guild_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	match action:
		1:
			if fields.size() < 14:
				return
			var guild_id := int(fields[2])
			var members: Array[Dictionary] = []
			if fields[13] != "-":
				for entry in fields[13].split("@", false):
					var parts := entry.split("&", true)
					if parts.size() >= 5:
						members.append({"name": String(parts[0]), "level": int(parts[1]), "rank": int(parts[2]), "contribution": int(parts[3]), "weekly_contribution": int(parts[4])})
			# ⚠️ `leader_id`（族长**角色 id**）**不在这份 14 字段布局里** —— 逐条对过服务端
			#    写者（`fake_flash_server` 的 `1552:1` 那一句）：[6] 是**族长名**、[7] 是
			#    **等级总和**，全篇没有族长 id。所以整体覆盖时**必须把旧值带过来**，
			#    否则它会被抹成"没有" ⇒ 原版那句 `stats.id == myFamillyInfo.leaderId`（`FM.as:455-462`）
			#    当场判成"不是管理"、安插/修复钮一起变灰（2026-10-08 排查安插不了的最后一环）。
			var 旧族长id := int(authoritative_guild.get("leader_id", 0))
			authoritative_guild = {
				"joined": guild_id > 0, "id": guild_id, "name": String(fields[3]) if guild_id > 0 else "",
				"notice": String(fields[4]) if guild_id > 0 else "", "members": int(fields[5]),
				"leader": String(fields[6]) if guild_id > 0 else "", "created_at": int(fields[9]),
				"level": int(fields[10]), "flag_name": String(fields[11]) if guild_id > 0 else "",
				"flag_style": int(fields[12]), "member_list": members,
			}
			if 旧族长id > 0 and guild_id > 0:
				authoritative_guild["leader_id"] = 旧族长id
			state["guild"] = authoritative_guild.duplicate(true)
		2:
			state.merge({"success": fields.size() >= 3 and int(fields[2]) == 1, "guild_id": int(fields[3]) if fields.size() >= 4 else 0}, true)
		19:
			# 家族重名检测结果（`1552:19:<0|1>`）。服务端 `_handle_multiplayer_family`
			# 的 `action == 21` 写的就是这一个字段，1 = 没人用。
			var 可用 := fields.size() > 2 and int(fields[2]) == 1
			state["name_available"] = 可用
			guild_name_checked.emit(可用)
		15:
			# 服务端 _send_family_info 的家族摘要：1552:15:id:名:公告:创建时间:族长角色id:族长名
			# （fake_flash_server.py 的 _send_family_info）。本机服务端用它代替摘要帧，
			# 客户端原先只认 action 1 的 14 字段布局，所以 authoritative_guild 一直为空。
			var family_id := int(fields[2]) if fields.size() > 2 else 0
			authoritative_guild.merge({
				"joined": family_id > 0, "id": family_id,
				"name": String(fields[3]) if fields.size() > 3 else "",
				"notice": String(fields[4]) if fields.size() > 4 else "-",
				"created_at": int(fields[5]) if fields.size() > 5 else 0,
				# ⚠️ 族长**角色 id**（fields[6]）必须留下来：原版判"是不是管理"用的是
				#    `API.dataCenter.stats.id == myFamillyInfo.leaderId`（`FM.as:455-462`），
				#    比的是**角色 id**，不是名字、更不是 rank。少了它就只能退化成比名字，
				#    名字一改/一空就会把"族长"判成"不是管理"，安插钮恒灰。
				"leader_id": int(fields[6]) if fields.size() > 6 else 0,
				"leader": String(fields[7]) if fields.size() > 7 else "",
				# 第 8 字段 = 自动同意（本轮服务端追加；老服务端没有 ⇒ 保持"关"）。
				"auto_accept": fields.size() > 8 and int(fields[8]) == 1,
			}, true)
			state["guild"] = authoritative_guild.duplicate(true)
		3:
			var guilds: Array[Dictionary] = []
			if fields.size() >= 6 and fields[5] != "-":
				for entry in fields[5].split("@", false):
					var parts := entry.split("&", true)
					if parts.size() >= 12:
						# 12 字段的口径以**服务端自己的写者**为准（`fake_flash_server.handle_banghui`
						# 的 action 101，与 `FamillyListItemRenderer.as:69-95` 逐个对得上）：
						#   id / 线 / 家族名 / 族长名 / 族长角色id / 家徽等级 / 族中人数 / 人数上限 /
						#   等级总和 / 本周击杀BOSS数 / 家徽样式 / 家徽名
						# ⚠️ 原来只取了 9 项，把 **线(parts[1])、等级总和(parts[8])、本周击杀(parts[9])**
						#    丢了 —— 表现在列表窗那两列只能空着，而服务端其实一直有发。
						# ⚠️ 也别再把 parts[5] 叫 `level`：它是**家徽等级**，不是家族等级。
						guilds.append({
							"id": int(parts[0]), "channel_id": int(parts[1]),
							"name": String(parts[2]), "leader": String(parts[3]),
							"leader_id": int(parts[4]), "flag_level": int(parts[5]),
							"members": int(parts[6]), "capacity": int(parts[7]),
							"level_sum": int(parts[8]), "boss_sum": int(parts[9]),
							"flag_style": int(parts[10]), "flag_name": String(parts[11]),
						})
			# ── 累计拉取（原版 `FamillyManager.onBanghuiList`，`FM.as:385-396`）──────────
			# 原版取数只有一句 `requestBanghuiQueryBanghuiList(100, page)`（`FM.as:1268`）：
			# 一页 **100** 条，`famillyList.length != total` 就再要下一页，**拉齐了才整份交给
			# 列表窗**（`setFamillyes`）—— 筛选/排序/**显示分页**全在列表窗里本地做（`FL.as:73-133`）。
			# 服务端这三个字段（total/page_size/page）只是**取数分页**，不是"显示分页"。
			# ⚠️ 我们原来是"一页 10 条、只发一次、列表窗也不分页" ⇒ 家族一超过 10 个，后面的
			#    永远看不到；而用户要的正是"看到所有游戏中已经创建的家族"。
			var 总数 := int(fields[2]) if fields.size() >= 3 else 0
			var 页码 := int(fields[4]) if fields.size() >= 5 else 1
			if _族列表拉取中:
				_族列表累计.append_array(guilds)
			else:
				_族列表累计.assign(guilds)
				_族列表拉取中 = true
			# 继续拉下一页的**唯一条件** = 本页确实有行、且还没拉够。
			# ⚠️ 只看 `累计 < 总数` 会死循环：页码越界时服务端回**空页**，累计永远追不上总数
			#    （`测试/后端协议回归测试` 那条 `request_guild_list(2, 10)` 正是这种情况）。
			if not guilds.is_empty() and _族列表累计.size() < 总数 and 页码 < 200:
				request_guild(101, [100, 页码 + 1])
				return
			_族列表拉取中 = false
			guilds = _族列表累计.duplicate()
			_族列表累计.clear()
			authoritative_guild_list.assign(guilds)
			state.merge({"total": 总数, "page_size": int(fields[3]) if fields.size() >= 4 else 100, "page": 页码, "guilds": guilds}, true)
		4:
			# 服务端 _refresh_family_identity 的家徽标识：1552:4:家徽名:等级:样式。
			# 原先只合进事件状态，没有写回 authoritative_guild——于是家徽升级成功后
			# 客户端读到的 level 仍是旧值（表现为"服务端没有持久化家徽升级"）。
			var flag_state := {
				"flag_name": String(fields[2]) if fields.size() >= 3 else "",
				"level": int(fields[3]) if fields.size() >= 4 else 0,
				"flag_style": int(fields[4]) if fields.size() >= 5 else 0,
			}
			state.merge(flag_state, true)
			authoritative_guild.merge(flag_state, true)
		5:
			# 服务端 action 5 = "5:<家族资金>:<材料库存>:<贡献行>"（`_send_family_contribution`）。
			# 资金与库存原先没解析，家族经济对客户端不可见——而家徽升级扣的正是
			# 家族资金(666)+四种家族材料，不是玩家金币。
			authoritative_guild["fund"] = int(fields[2]) if fields.size() > 2 else 0
			var stock: Dictionary = {}
			if fields.size() > 3 and fields[3] != "-":
				for entry in String(fields[3]).split(",", false):
					var pair := String(entry).split("&", true)
					if pair.size() >= 2:
						stock[int(pair[0])] = int(pair[1])
			authoritative_guild["materials"] = stock
			# ⚠️ **这一帧不是成员表**：同族还有另一套 11 字段的**贡献行**
			#    （id/名/级/职务/书籍/金币/周书籍/周金币/**线**/总贡献/周贡献，
			#    见 `_send_family_contribution`）。原来是两条都往 `state["members"]` 里塞，
			#    后到的那条把先到的整份顶掉 ⇒ 成员窗与贡献窗只能活一个。
			#    ⇒ 现在分开放：5 → `contributions`（贡献窗）、6 → `members`（成员窗）。
			var contributions: Array[Dictionary] = []
			if fields.size() > 4 and fields[4] != "-":
				for entry in fields[4].split("@", false):
					var parts := entry.split("&", true)
					if parts.size() >= 11:
						contributions.append({
							"character_id": int(parts[0]), "name": String(parts[1]),
							"level": int(parts[2]), "rank": int(parts[3]),
							"books": int(parts[4]), "gold": int(parts[5]),
							"week_books": int(parts[6]), "week_gold": int(parts[7]),
							"line": int(parts[8]), "channel_id": int(parts[8]),
							"contribution": int(parts[9]), "contriValue": int(parts[9]),
							"weekly_contribution": int(parts[10]),
							"online": int(parts[8]) >= 0,
						})
			state["contributions"] = contributions
		6:
			# 服务端 action 6 = `6:<17 字段行@…>`（`_handle_multiplayer_family` 的 action 105）。
			# 行序逐条对服务端写者（`fake_flash_server.py:34607-34642`）：
			#   id/名/级/职务/职业/脸/性别/0(占位)/总贡献/周贡献/**线**/族内昵称/
			#   忍术层数/八门进度/成就进度/战场声望/本周BOSS
			# ⚠️ 原来走的是 `parts.size() >= 7` 那条通用兜底：总贡献读成 parts[9]（错位成周贡献后面的线）、
			#    `online` 读成 parts[10]>0（线 -1 → false 还行，线 0 → false 全灭），
			#    职业/脸/性别/昵称/五项统计**整段丢掉** ⇒ 成员窗右半边五列只能写死 "-"。
			# ⚠️ 键名同时给两套：本工程自用的一套 + 原版 `FamillyMembersWindow.applySort`
			#    用的那套（`contriValue`/`skillValue`/`maiValue`/`chengjiuValue`/`shengwangValue`/`bossValue`）。
			var members: Array[Dictionary] = []
			if fields.size() > 2 and fields[2] != "-":
				for entry in fields[2].split("@", false):
					var parts := entry.split("&", true)
					if parts.size() >= 17:
						var 线 := int(parts[10])
						members.append({
							"character_id": int(parts[0]), "name": String(parts[1]),
							"level": int(parts[2]), "rank": int(parts[3]),
							"job": int(parts[4]), "face": int(parts[5]), "gender": int(parts[6]),
							"contribution": int(parts[8]), "contriValue": int(parts[8]),
							"weekly_contribution": int(parts[9]),
							"line": 线, "channel_id": 线, "online": 线 >= 0,
							"nick": String(parts[11]),
							"skill_value": int(parts[12]), "skillValue": int(parts[12]),
							"mai_value": int(parts[13]), "maiValue": int(parts[13]),
							"achievement_value": int(parts[14]), "chengjiuValue": int(parts[14]),
							"shengwang_value": int(parts[15]), "shengwangValue": int(parts[15]),
							"boss_value": int(parts[16]), "bossValue": int(parts[16]),
						})
					elif parts.size() >= 12:
						# 单机（无多人族）时的伪行：`_handle_single_player_multiplayer` 的
						# 12 字段版（id/名/级/1/0×5/总贡献/1/0）——自己一个人，恒在线。
						members.append({
							"character_id": int(parts[0]), "name": String(parts[1]),
							"level": int(parts[2]), "rank": int(parts[3]),
							"job": 0, "face": 0, "gender": 0,
							"contribution": int(parts[9]), "contriValue": int(parts[9]),
							"weekly_contribution": int(parts[9]),
							"line": 0, "channel_id": 0, "online": true, "nick": "",
							"skill_value": 0, "skillValue": 0,
							"mai_value": 0, "maiValue": 0,
							"achievement_value": 0, "chengjiuValue": 0,
							"shengwang_value": 0, "shengwangValue": 0,
							"boss_value": 0, "bossValue": 0,
						})
			state["members"] = members
		7:
			# `1552:7:<角色号>`：有人加入家族（原版 `joinFamillyResult:1040-1047`）。
			# 这是一帧**只带角色号**的广播：不带新成员的名/级/职 ⇒ 收到就重拉一次 105
			# （原版 `getMemberList()` 也是无条件重拉）。
			# 自己被批准时原版弹「加入家族成功！」（且排除族长自己）。
			var 新成员号 := int(fields[2]) if fields.size() > 2 else 0
			if 新成员号 == character_id and 新成员号 != int(authoritative_guild.get("leader_id", 0)):
				_通知("加入家族成功！")
			if bool(authoritative_guild.get("joined", false)):
				request_guild_members(0, true)
		8:
			# `1552:8:<名>:<角色号>:<脸>:<等级>`：入族申请，**只推给族长**
			# （服务端 action 2 的 pending 分支）。原版 `onFamillyApply:148-160`
			# 把 `name/id/face/level` 原样塞进托盘格，并补 `playerName` / `famillyName`("无") / `charId`。
			if fields.size() < 6:
				return
			family_apply_received.emit({
				"name": String(fields[2]), "playerName": String(fields[2]),
				"id": int(fields[3]), "charId": int(fields[3]),
				"face": int(fields[4]), "level": int(fields[5]),
				"famillyName": "无",
			})
		9:
			# `<名>拒绝了你的入族邀请！`（`onRejectFamillyAplly:120-122` 原文，一个字都没改）。
			# 同一帧两种来源：① 族长邀请被别人拒（服务端 action 3 推给族长）；
			# ② 入族申请被族长拒（action 13 推给申请人）。原版两种都只有这一句。
			if fields.size() > 2:
				_通知(String(fields[2]) + "拒绝了你的入族邀请！")
		12:
			# `1552:12:<角色号>:<名>`：开除广播（服务端 action 4 推给全族在线）。
			# 原版 `fireMemberResult:1022-1037`：族长看到「X已被你开除出家族！」，
			# 其他人看到「X已被族长开除出家族！」；被开除的人自己**不弹提示**，
			# 只是窗口全收、guildId 清零（这里同步成 joined=false）。
			var 被开号 := int(fields[2]) if fields.size() > 2 else 0
			var 被开名 := String(fields[3]) if fields.size() > 3 else ""
			if 被开号 == character_id:
				authoritative_guild = {"joined": false, "id": 0, "name": "", "notice": "", "members": 0, "leader": "", "level": 0, "flag_name": "", "flag_style": 0, "member_list": []}
				state["guild"] = authoritative_guild.duplicate(true)
			else:
				if bool(authoritative_guild.get("joined", false)):
					if int(authoritative_guild.get("leader_id", 0)) == character_id and not 被开名.is_empty():
						_通知(被开名 + "已被你开除出家族！")
					elif not 被开名.is_empty():
						_通知(被开名 + "已被族长开除出家族！")
					request_guild_members(0, true)
		13, 14:
			# `13:<族id>` = 解散（推给每个在线族员）；`14:<角色号>:<名>` = 退族广播。
			# 原版两个结果处理器（`disbandFamillyResult` / `exitFamillyResult`）的文案：
			#   解散 → **只有族长**看「你已成功解散家族！」；
			#   退族 → 本人看「你已成功退出家族！」，非本人只有族长看「X已经退出家族！」。
			var 是我 := action == 13 or (fields.size() > 2 and int(fields[2]) == character_id)
			var 是族长 := int(authoritative_guild.get("leader_id", 0)) == character_id
			if action == 13:
				if 是族长:
					_通知("你已成功解散家族！")
			elif 是我:
				_通知("你已成功退出家族！")
			elif 是族长 and fields.size() > 3:
				_通知(String(fields[3]) + "已经退出家族！")
			authoritative_guild = {"joined": false, "id": 0, "name": "", "notice": "", "members": 0, "leader": "", "level": 0, "flag_name": "", "flag_style": 0, "member_list": []}
			state["guild"] = authoritative_guild.duplicate(true)
			if not 是我 and action == 14:
				request_guild_members(0, true)
		17:
			# 捐献结果：`1552:17:<是否捐了金币 0/1>:<成功 0/1>`（服务端
			# `_handle_family_contribution` 的三个出口：没东西可捐 / 不够 / 成功）。
			# 原来**没接** ⇒ 捐失败时界面一声不响，玩家以为捐上去了。
			var 成功 := fields.size() >= 4 and int(fields[3]) == 1
			state.merge({"donation_money": fields.size() >= 3 and int(fields[2]) == 1,
				"donation_ok": 成功}, true)
		20:
			# 自己的族贡值：既用于捐献刷新，也用于商城购买后的权威余额。
			if fields.size() >= 3 and not String(fields[2]).is_empty():
				authoritative_guild["contribution"] = int(fields[2])
				state["contribution"] = int(fields[2])
				guild_shop_received.emit(authoritative_guild_shop.duplicate(true), int(fields[2]))
		23:
			var items: Array[Dictionary] = []
			if fields.size() >= 3 and fields[2] != "-":
				for entry in fields[2].split("@", false):
					var parts := entry.split("&", true)
					if parts.size() >= 3 and int(parts[0]) > 0:
						items.append({"item_id": int(parts[0]), "count": maxi(1, int(parts[1])), "price": maxi(0, int(parts[2]))})
			authoritative_guild_shop.assign(items)
			guild_shop_received.emit(authoritative_guild_shop.duplicate(true), int(authoritative_guild.get("contribution", 0)))
		21:
			# 家徽标识的**清除**帧：`1552:21:<角色id>:0:-`（退族/被踢时发）。
			state["flag_cleared"] = true
		19:
			state["name_available"] = fields.size() >= 3 and int(fields[2]) == 1
		16:
			## 族长邀我入族：`_send_family_invitation:22296-22313` 的形状是
			## `1552:16:<族长名>:<等级>:<职业>:<脸>:<族名>:<族长id>:<族id>`（七段）。
			## 键名照原版 `onAcceptFamillyInvite:333-338` 的六行赋值 ——
			## ⚠ 两个 id 别混：`charId` = **族长角色号**（托盘去重比它），`id` = **家族 id**
			## （同意/拒绝那两发带它，服务端按 `familyInviteId` 校验）。
			if fields.size() < 9:
				return
			family_invite_received.emit({
				"name": String(fields[2]), "playerName": String(fields[2]),
				"level": int(fields[3]), "job": int(fields[4]), "face": int(fields[5]),
				"famillyName": String(fields[6]),
				"charId": int(fields[7]), "id": int(fields[8]),
			})
	_同步家族到人物属性()
	guild_state_received.emit(state)


## 自族身份落到人物属性：原版 `Client.as:2470-2481 onBanghuiInfo` 收到 `1552` 时写
## `API.dataCenter.guildName = param1.name`（`DataCenter.as:176`），人物面板那一格读的就是它
## （`DataCenter.as:1455` → `CharPane.as:228`「家族：X」，没族 `-`）。本工程面板读
## `player_stats.family`，所以自族帧（`1` 详情 / `15` 摘要）与退族帧（`13` / `14`）都往这儿同步 ——
## 不同步的话「已经有家族」也一直显示 `-`（2026-11-01 用户报修）。名字没变就不 emit，免得白重建面板。
func _同步家族到人物属性() -> void:
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 == null:
		return
	var 名 := String(authoritative_guild.get("name", "")) if bool(authoritative_guild.get("joined", false)) else ""
	if str(会话.player_stats.get("family", "")) == 名:
		return
	会话.player_stats["family"] = 名
	会话.player_stats_changed.emit(会话.player_stats.duplicate(true))

func _handle_guild_boss_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	match action:
		0:
			state.merge({"day": int(fields[2]) if fields.size() >= 3 else 0, "seconds": int(fields[3]) if fields.size() >= 4 else 0, "set_count": int(fields[4]) if fields.size() >= 5 else 0, "indexes": String(fields[5]) if fields.size() >= 6 else "-"}, true)
		1:
			state.merge({"active": true, "remaining_seconds": int(fields[2]) if fields.size() >= 3 else 0}, true)
		2:
			state.merge({"claimed": true, "shengwang": int(fields[2]) if fields.size() >= 3 else 0, "zq": int(fields[3]) if fields.size() >= 4 else 0, "exp": int(fields[4]) if fields.size() >= 5 else 0}, true)
		3:
			state.merge({"active": false, "completed": true}, true)
	authoritative_guild_boss.merge(state, true)
	guild_state_received.emit({"action": 200 + action, "boss": authoritative_guild_boss.duplicate(true)})

func _parse_social_contacts(encoded: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for entry in encoded.split("@", false):
		var parts := String(entry).split("&", true)
		if parts.size() < 11:
			continue
		result.append({
			"character_id": int(parts[0]), "degree": int(parts[1]), "face": int(parts[2]),
			"gender": int(parts[3]), "job": int(parts[4]), "level": int(parts[5]),
			"name": String(parts[6]), "couple": int(parts[7]) != 0, "intimacy": int(parts[8]),
			"contact_time": int(parts[9]), "channel_id": int(parts[10]), "online": int(parts[10]) > 0,
		})
	return result

func _handle_friend_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	match action:
		1, 3:
			if fields.size() >= 3:
				state["contact"] = _parse_social_contacts(String(fields[2])).front() if not _parse_social_contacts(String(fields[2])).is_empty() else {}
		2:
			# 段序 = 服务端 `_send_friend_list` 的 `2:<好友>:<仇人>:<黑名单>:<最近>:<申请>`。
			# ⚠️ 以前黑名单取 [5]、最近也取 [5] —— 是照旧服务端
			# `2:<好友>:-:<好友>:<黑名单>:-` 那种重复好友行的写法抄的；
			# 服务端已按原版五段改齐，这里别再保留"能解出条目的那个位次"的猜测：
			# 猜位次会让"最近"永远拿到黑名单那一列，而且反向对照抓不出来。
			authoritative_friends = _parse_social_contacts(String(fields[2]) if fields.size() > 2 else "-")
			authoritative_enemies = _parse_social_contacts(String(fields[3]) if fields.size() > 3 else "-")
			authoritative_blocked = _parse_social_contacts(String(fields[4]) if fields.size() > 4 else "-")
			authoritative_recent_contacts = _parse_social_contacts(String(fields[5]) if fields.size() > 5 else "-")
			authoritative_friend_requests = _parse_social_contacts(String(fields[6]) if fields.size() > 6 else "-")
			state.merge({
				"friends": authoritative_friends.duplicate(true), "enemies": authoritative_enemies.duplicate(true),
				"blocked": authoritative_blocked.duplicate(true), "recent": authoritative_recent_contacts.duplicate(true),
				"requests": authoritative_friend_requests.duplicate(true),
			}, true)
		4:
			state["removed_character_id"] = int(fields[2]) if fields.size() > 2 else 0
		5:
			# 两种形态都要认：
			#  - 列表形态：fields[2] 是编码过的联系人列表（离线示例与 action 2 同源）；
			#  - 单条通知形态：服务端 _handle_multiplayer_friend 收到加好友申请时推给目标的
			#    `61:5:<申请人角色编号>:<申请人名字>`（fake_flash_server.py:22972）。
			# 原先只按列表形态解析，单条通知会被解析成空、申请列表永不更新。
			var requests := _parse_social_contacts(String(fields[2]) if fields.size() > 2 else "-")
			if not requests.is_empty():
				state["request"] = requests[0]
			elif fields.size() > 3:
				var incoming := {"character_id": int(fields[2]), "name": String(fields[3])}
				var known := false
				for existing in authoritative_friend_requests:
					if int(existing.get("character_id", 0)) == int(incoming["character_id"]):
						known = true
						break
				if not known:
					authoritative_friend_requests.append(incoming)
				state["request"] = incoming
		8:
			## 打探结算（`127:10` 的回包）。原版 `FriendProcessor.as` case 8 →
			## `onFriend_findEnemyResult` → `FriendWindow2.daTanResult:230`。
			## 本工程服务端把它压成文本：`61:8:<errorCode>[:<线>:<图>:<x>:<y>]`；
			## 非 0 档不带明细，文案归窗（`MPromptWindow.updateDaTanView:313-347`）。
			if fields.size() < 3:
				return
			var 探: Dictionary = {"errorCode": int(fields[2])}
			if int(探["errorCode"]) == 0 and fields.size() >= 7:
				探.merge({"channel": int(fields[3]), "map": int(fields[4]),
						"x": int(fields[5]), "y": int(fields[6])}, true)
			find_enemy_result_received.emit(探)
		13:
			## 登录时服务端补发的"我已经有羁绊对象了"（`fake_flash_server.py:22277-22291`）：
			## `61:13:<对端角色号>:<名>:<职>:<对戒id>`。只有 `bondItem` 非 0 才发 ⇒ 没结过的人收不到这一条。
			if fields.size() < 6:
				return
			authoritative_spouse = {"charId": int(fields[2]), "name": String(fields[3]),
					"job": int(fields[4]), "hunjieId": int(fields[5]), "face": 0}
		14:
			## 我点「羁绊」之后服务端把**对面那份资料**回给我 ⇒ 开「发起羁绊」那一扇。
			## 段序 = 服务端 `:23236-23241`；第四段是**家族名**，而 `CharInfoPane.setData:77` 读的键叫 `banghui`
			## ⇒ 这里就按原版键名给，别让控制器再去猜第二套名字。
			if fields.size() < 8:
				return
			bond_preview_received.emit({
				"name": String(fields[2]), "level": int(fields[3]), "job": int(fields[4]),
				"banghui": String(fields[5]), "face": int(fields[6]), "charId": int(fields[7]),
			})
		17:
			## 别人向我求羁绊 ⇒ **只塞托盘那一格**，不自动开窗（`Client.as:7883` → `receiveTaRequest:70-73`）。
			## 比 14 多末段那个**对戒物品号**（被求那侧的窗要把它画进第一格）。
			if fields.size() < 9:
				return
			bond_invite_received.emit({
				"name": String(fields[2]), "level": int(fields[3]), "job": int(fields[4]),
				"banghui": String(fields[5]), "face": int(fields[6]), "charId": int(fields[7]),
				"item": int(fields[8]),
			})
		18:
			## 对方拒绝 ⇒ 原版 `onFriend_refuseTa:10242-10245` 就一句 addNotice（文案有真值，见 `真值/窗口/求婚窗.md` §④）。
			if fields.size() < 3:
				return
			bond_refused_received.emit({"name": String(fields[2])})
		19, 20:
			## 结成：同意方收 `19`（带**求方**号）、求方收 `20`（带**同意方**号），两边同形。
			## 段序 = 服务端 `:23346-23355`。原版两支都只写 `spouseId` + 学 couple 技能 + 灌 `WeddingWindow`
			## （`Client.as:4878/6795`）⇒ 那一扇本工程还没做，先把权威状态落下、帧量得到。
			if fields.size() < 7:
				return
			authoritative_spouse = {"charId": int(fields[2]), "name": String(fields[4]),
					"face": int(fields[5]), "job": int(fields[6]),
					"hunjieId": int(fields[3])}
			bond_established_received.emit(authoritative_spouse.duplicate(true))
		7:
			## 私信（原版 `FriendProcessor.as:179-185` case 7 → `Client.onFriend_chatWithFriend`）。
			## 服务端两处会发：① 上线时**补投离线期间收到的私信**
			##   （`_send_pending_social:22229-22241`，一条 `61:7:<发件人角色号>:<正文>:<发件人名>`）；
			## ② 在线转发（`:23235-23241`）。以前这一支**没人认** ⇒ 我下线时别人发的信，上线一个字都看不到。
			## 显示复用聊天那一族同一个出口（`chat_received`）：`type=4` 才是聊天面板认的「私聊」档
			## （`聊天面板.gd:140` 那张表），`level` 这一帧没有 ⇒ 给 0，不猜。
			if fields.size() < 5:
				return
			chat_received.emit({
				"type": 4, "positions": 0, "message": String(fields[3]),
				"name": String(fields[4]), "character_id": int(fields[2]), "level": 0,
				"target_name": "",
			})
		23:
			## 解除羁绊成功（原版 `:227-229` → `onFriend_divorceSuccess`）。服务端在
			## `handle_friend:23395-23404` 清完账给**两边各发一条** `61:23`（无参数）⇒ 这边只清权威配偶
			## + 发信号，关窗/撤托盘交给消费者（状态只有一处，不在解码器里顺手关窗）。
			authoritative_spouse = {"charId": 0, "name": "", "face": 0, "job": 0, "hunjieId": 0}
			bond_dissolved_received.emit()
		44:
			## 送花结算：`61:44:<发号>:<收号>:<发名>:<朵>:<花号>`（段序 = 服务端
			## `_send_flower_gift` 末尾那个 `payload`，
			## 收端解码 = `FriendProcessor.as:391-393` → `onFriend_receiveFlower`）。
			## ⚠ **发送方自己也收这一条**（服务端给两边各发一份），所以这里只解、不判"是不是发给我的"——
			## 那一判在消费者那边（原版同样放在 `MarryTableManager.receiveFlower:206-214`，不在解码器里）。
			## 键名照原版那几个对象字段（`senderId/receiverId/senderName/count/flowerid`），不另造。
			if fields.size() < 7:
				return
			收花帧收到.emit({"senderId": int(fields[2]), "receiverId": int(fields[3]),
					"senderName": String(fields[4]), "count": int(fields[5]), "flowerid": int(fields[6])})
	friend_state_received.emit(state)

func _parse_party_members(encoded: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for entry in encoded.split("@", false):
		# 服务端 _party_member_row 只给 **8** 个字段：
		#   character_id & name & job & level & "-" & (line_id-1) & map_id & face
		# （fake_flash_server.py:23457）。原先要求 >= 9 且把 [2]/[3] 当等级/职业，
		# 于是每一行都被跳过、队伍成员永远为空（表现为"接受邀请后双方没有两人快照"）。
		# leader 不在这行里，由队伍状态的 leader_id 另行标注（见 _handle_party_text 的 15/27）。
		var parts := String(entry).split("&", true)
		if parts.size() < 8:
			continue
		result.append({
			"character_id": int(parts[0]), "name": String(parts[1]), "job": int(parts[2]),
			"level": int(parts[3]), "face": int(parts[7]), "map_id": int(parts[6]),
			"channel_id": int(parts[5]) + 1, "online": true, "leader": false,
		})
	return result

func _parse_party_invites(encoded: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for entry in encoded.split("@", false):
		var parts := String(entry).split("&", true)
		if parts.size() >= 5:
			result.append({"party_id": int(parts[0]), "inviter_id": int(parts[1]), "inviter_name": String(parts[2]), "party_name": String(parts[3]), "created_at": int(parts[4])})
	return result

func _handle_party_text(opcode: int, fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"opcode": opcode, "action": action}
	match action:
		4:
			## ⚠ **段序照原版，不是照本机服务端多发几位**：
			##   `PartyProcessor` 的邀请 handler（`:52-66`）只有两次读 ——
			##   `partyId = bytes.readInt()` 然后 `fromCharName = bytes.readUTF()`
			##   ⇒ 下行就是 `59:4:<队伍号>:<邀请人名字>`，**没有"邀请人角色编号"那一段**。
			##   上一版按 `2=队号 3=邀请人号 4=邀请人名 5=队名` 读 ⇒ 名字被当成整数读成 0、
			##   真正在 fields[3] 的名字没人读 ⇒ `inviter_name` 恒为空串，
			##   于是 `游戏会话.gd:2019` 那条邀请通知与 `社交窗口.gd:221` 那行"××邀请你加入小队"
			##   都显示成空名字（用户 10-17 点名的「邀请组队按钮」症状）。
			var invite := {
				"party_id": int(fields[2]) if fields.size() > 2 else 0,
				"inviter_name": String(fields[3]) if fields.size() > 3 else "",
				"inviter_id": 0,		# 原版这条帧里**没有**，不许拿名字硬凑一个号
				"party_name": "",		# 同上：队名不在这一帧里
			}
			state["invite"] = invite
			# `RelationShipHandler.onPartyInvite(partyId, fromCharName)` 的两个实参。
			# ⚠ 消费方（`队伍窗._队伍邀请`）读的是 state 顶层 ⇒ 必须并出来。
			#   只塞进 `state["invite"]` 时实机症状：托盘格队号 0、弹窗名字空、
			#   确定发 `120:3:0` ⇒ 服务端不收，玩家看着就是"点了没进队"。
			state.merge({"party_id": invite["party_id"], "inviter_name": invite["inviter_name"]}, true)
			var pending: Array = authoritative_party.get("invites", [])
			var already := false
			for existing in pending:
				if int((existing as Dictionary).get("party_id", 0)) == int(invite["party_id"]):
					already = true
					break
			if not already:
				pending.append(invite)
			authoritative_party["invites"] = pending
			state["party"] = authoritative_party.duplicate(true)
		8:
			state.merge({"party_id": int(fields[2]) if fields.size() > 2 else 0, "party_name": String(fields[3]) if fields.size() > 3 else ""}, true)
		23:
			# `handleAction_DENY_REQUEST:393-410` = UTF 名字 ⇒ `onDenyRequest`
			# （`Client.as:9549` 硬编码「X 拒绝了你的组队邀请！」）
			state["char_name"] = String(fields[2]) if fields.size() > 2 else ""
		26:
			# `handleAction_UPDATE_PARTY_CHANGE_LEADER:487-506` = partyId:int + targetId:int
			# ⇒ `onPartyChangeLeader(partyId, targetId)`。服务端文本把它压成了 `26:<新队长号>`。
			var 新队长 := int(fields[-1]) if fields.size() > 2 else 0
			authoritative_party["leader_id"] = 新队长
			state.merge({"target_id": 新队长, "party": _party_with_characters(authoritative_party).duplicate(true)}, true)
		37:
			# `handleAction_DENY_APPLICATION:28-46` = 一个 PartyCharacter ⇒ `onDenyPartyApplication`
			state["applicant_name"] = String(fields[2]) if fields.size() > 2 else ""
		38:
			# `handleAction_PARTY_APPLICATION:69-87` = 一个 PartyCharacter ⇒ `onPartyApplication`
			state.merge({"applicant_id": int(fields[2]) if fields.size() > 2 else 0,
				"applicant_name": String(fields[3]) if fields.size() > 3 else ""}, true)
		12:
			authoritative_party = {"joined": false, "id": 0, "name": "", "leader_id": 0, "members": [], "invites": []}
			state["party"] = authoritative_party.duplicate(true)
		13:
			# **被踢出队伍**（原版 `PartyProcessor.as:165` `UPDATE_PARTY_EXPEL` → `handleAction_UPDATE_PARTY_EXPEL:508`
			# → `onPartyExpel(targetId, name, partyStatus)`）。服务端文本
			# （`fake_flash_server` 踢人那一支）是 `13:<被踢角色id>:<名字>:<队伍id>:<队长id>:<队伍名>:-`，
			# 而且**只发给被踢者**（其余成员走广播的队伍状态）⇒ 这边就按"我被移出队伍"处理：
			# 清掉 `authoritative_party`（会话侧 `team_members` 跟着 `party_state_received` 一起清）。
			# ⚠️ 2026-10-14 之前这一支**没人认**：被队长踢了，队伍界面还挂着原队伍、人数不变。
			var 被踢者 := int(fields[2]) if fields.size() > 2 else 0
			authoritative_party = {"joined": false, "id": 0, "name": "", "leader_id": 0, "members": [], "invites": []}
			state.merge({"expelled": 被踢者, "target_id": 被踢者,
				"expelled_name": String(fields[3]) if fields.size() > 3 else "",
				"target_name": String(fields[3]) if fields.size() > 3 else ""}, true)
			state["party"] = authoritative_party.duplicate(true)
		14:
			# **队员离队**（`UPDATE_PARTY_LEAVE:14` → `handleAction_UPDATE_PARTY_LEAVE` → `onPartyLeave`）。
			# 服务端文本 `14:<队伍id>:<队长id>:<队名>:-:<离队角色id>` —— ⚠️ 成员段是**写死的 `-`**
			# （`fake_flash_server` 离队那一支），所以**只能按"这个 id 走了"处理**，
			# 千万别拿那个 `-` 去清成员表（那是"没有成员信息"，不是"没有成员"）。
			var 离队者 := int(fields[6]) if fields.size() > 6 else 0
			if 离队者 != 0 and 离队者 != character_id:
				var 剩下: Array = (authoritative_party.get("members", []) as Array).duplicate()
				for index in range(剩下.size() - 1, -1, -1):
					if int((剩下[index] as Dictionary).get("character_id", 0)) == 离队者:
						剩下.remove_at(index)
				authoritative_party["members"] = 剩下
				# 原版 `handleAction_UPDATE_PARTY_LEAVE:305-327` 第三段是**整个 PartyStatus**
				# （新队长/队名都在里面）。文本协议把它压成 `14:<队号>:<队长号>:<队名>:-:<离队者号>`
				# ⇒ 走的是**离队以后**的队长号，必须写回去，否则队长自己退队时剩下的人还挂着旧队长。
				if fields.size() > 3 and int(fields[3]) > 0:
					authoritative_party["leader_id"] = int(fields[3])
				if fields.size() > 4:
					authoritative_party["name"] = String(fields[4])
			else:
				authoritative_party = {"joined": false, "id": 0, "name": "", "leader_id": 0, "members": [], "invites": []}
			# 原版第三段是**整个 PartyStatus**；服务端那一支只给 `-` ⇒ 用"删掉这个人之后"的
			# 当前状态补一个形状相同的包给消费方（`RelatingshipHandler.onPartyLeave` 就是拿它重绘）。
			state.merge({"left_id": 离队者, "target_id": 离队者,
				"target_name": String(fields[3]) if fields.size() > 3 else ""}, true)
			state["party"] = _party_with_characters(authoritative_party).duplicate(true)
		17:
			# 邀请失败：**队伍已满**（`handleAction_PARTY_FULL:100` → `onPartyFull`）。
			# 原版那句话是硬写的中文字面量（`Client.as:8669` `API.ui.addNotice("队伍已满")`）。
			_通知("队伍已满")
			state["party_full"] = true
		18:
			# 邀请失败：**没找到该玩家**（`handleAction_NOT_FIND_CHAR:277` → `onNotFindChar`
			# → `Client.as:9621` `API.ui.addNotice("没找到该玩家")`）。
			_通知("没找到该玩家")
			state["not_found_char"] = true
		39:
			# 接受邀请时"队伍已不存在"（`handleAction_NO_SUCH_PARTY:114` → `onPartyNotExist`）——
			# ⚠️ 原版这个回调是**空实现**（`Client.as:7094-7096` 花括号里什么都没有）⇒ **本就不该有反应**，
			# 这里只记状态、不提示（探针会把它报成"没认"，那一条是假红）。
			state["party_gone"] = true
		19:
			# **队长改了队名**（`UPDATE_PARTY_NAME:19` → `handleAction_UPDATE_PARTY_NAME:329`：
			# `partyId + partyName`）。服务端文本简化为 `19:<队伍名>`。
			var 新队名 := String(fields[2]) if fields.size() > 2 else ""
			authoritative_party["name"] = 新队名
			state["party_name"] = 新队名
			state["party"] = authoritative_party.duplicate(true)
		7, 15, 27:
			# 服务端 _party_status_payload 的字段序是
			#   `<mode>:<party_id>:<leader_id>:<队伍名>:<成员>[:<后缀>]`
			# （fake_flash_server.py:23650 附近的 `_party_status_payload`）。
			# * 7 = `UPDATE_PARTY_SILENT_UPDATE_LOG_ONOFF`（`PartyProcessor.as:370-390` →
			#   `onPartySilentUpdateLogOnOff` = updatePartyStatus + updataTroopStatus，**不弹流水字**）
			#   ⇒ 建队后、踢人后的状态刷新都走这一档；
			# * 15 = `UPDATE_PARTY_JOIN`，后缀是加入者名字（`onPartyJoin:238-246` 要弹「X 加入队伍」）；
			# * 27 = `SHOW_PARTY_INFO`，原版 `Client.onShowPartyInfo:4215` **是空函数**，
			#   这里只为兼容而解包，消费方 `服务端队伍帧` 那侧同样不动作。
			# 原先只认 27 且把 [3]/[4] 当成「队伍名/队长」——顺序相反，
			# 于是建队成功后 joined 一直为假。
			var party_id := int(fields[2]) if fields.size() > 2 else 0
			var members := _parse_party_members(String(fields[5]) if fields.size() > 5 else "-")
			var invites := _parse_party_invites(String(fields[6]) if fields.size() > 6 else "-")
			var leader_id := int(fields[3]) if fields.size() > 3 else 0
			# 成员行里不带队长标记，这里按队伍状态的 leader_id 标注。
			for member in members:
				member["leader"] = int(member.get("character_id", 0)) == leader_id
			authoritative_party = {
				"joined": party_id > 0, "id": party_id,
				"name": String(fields[4]) if party_id > 0 and fields.size() > 4 else "",
				"leader_id": leader_id,
				"members": members, "invites": invites,
			}
			state["party"] = _party_with_characters(authoritative_party).duplicate(true)
			state["target_name"] = String(fields[6]) if fields.size() > 6 else ""
		36:
			# 服务端 `_handle_multiplayer_party` action 10 那一支发的是
			#   `36:<队号>&<队长号>&<队名>&<成员行…>`，成员行之间用 `!`、行内 `&` 换成 `+`。
			# 原版下行这一段是 `ArrayCodec(PartyStatus)` ⇒ 消费方要的是**每条一个 PartyStatus**
			# （party_id / leader_id / party_name / characters），这里按那个形状拼出来。
			var parties: Array[Dictionary] = []
			if fields.size() > 2 and fields[2] != "-":
				for entry in fields[2].split("@", false):
					var 段 := String(entry).split("&", true)
					if 段.size() < 3:
						continue
					var 员行: Array = []
					if 段.size() > 3 and 段[3] != "-":
						for 行 in 段[3].split("!", false):
							员行.append(String(行).replace("+", "&"))
					parties.append(_party_status_from_rows(int(段[0]), int(段[1]), String(段[2]), 员行))
			authoritative_nearby_parties.assign(parties)
			state["nearby_parties"] = parties
			state["parties"] = parties.duplicate(true)
	party_state_received.emit(state)

## `PartyCharacter.as:35-45` 的字段名与顺序。服务端成员行给的是
## `character_id & name & job & level & familly & channelIndex & mapId & face`（8 段）。
func _party_member_as_character(行: Dictionary) -> Dictionary:
	return {
		"partyCharId": int(行.get("character_id", 0)),
		"partyCharName": String(行.get("name", "")),
		"jobId": int(行.get("job", 0)),
		"level": int(行.get("level", 0)),
		"familly": String(行.get("family", "")),
		"channelIndex": int(行.get("channel_id", 1)) - 1,
		"mapId": int(行.get("map_id", 0)),
		"face": int(行.get("face", 0)),
	}


## `PartyStatus.decode:52-60` 的形状：partyId / leaderId / partyName / characters。
func _party_with_characters(队伍: Dictionary) -> Dictionary:
	var 员: Array = []
	for 行 in (队伍.get("members", []) as Array):
		员.append(_party_member_as_character(行))
	var 队号 := int(队伍.get("id", 0))
	return {
		# AS3 `PartyStatus` 形状：队伍窗 `_换算队伍` 读 party_id / characters。
		"party_id": 队号,
		"leader_id": int(队伍.get("leader_id", 0)),
		"party_name": String(队伍.get("name", "")),
		"characters": 员,
		# 会话侧权威形状：`测试/后端协议回归测试.gd` 与别处消费读 joined / members。
		# ⚠ 两种键名都要留 —— 只留 AS3 形状时老门会在 `party.joined` 上中途报错，
		#   后面整套断言全不执行（10-25 全量里就红在这一条）。
		"joined": 队号 > 0,
		"id": 队号,
		"name": String(队伍.get("name", "")),
		"members": (队伍.get("members", []) as Array).duplicate(true),
		"invites": (队伍.get("invites", []) as Array).duplicate(true),
	}


## 36 那一帧里每队是 8 段文本行（行内 `&` 已换成 `+`）。
func _party_status_from_rows(队号: int, 队长号: int, 队名: String, 员行: Array) -> Dictionary:
	var 员: Array = []
	for 行 in 员行:
		var 段 := String(行).split("&", true)
		if 段.size() < 8:
			continue
		员.append({
			"partyCharId": int(段[0]), "partyCharName": String(段[1]), "jobId": int(段[2]),
			"level": int(段[3]), "familly": String(段[4]), "channelIndex": int(段[5]),
			"mapId": int(段[6]), "face": int(段[7]),
		})
	return {"party_id": 队号, "leader_id": 队长号, "party_name": 队名, "characters": 员}


func _parse_reward_items(encoded: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if encoded.is_empty() or encoded == "-":
		return result
	for entry in encoded.split("!", false):
		var parts := String(entry).split("%", true)
		if parts.size() < 2:
			continue
		var item_id := int(parts[0])
		var definition := GAME_DATA.item(item_id)
		result.append({
			"item_id": item_id, "id": String(definition.get("id", str(item_id).pad_zeros(8))),
			"name": String(definition.get("name", str(item_id))), "quantity": int(parts[1]),
			"bind_state": int(parts[2]) if parts.size() > 2 else 1,
			"icon": String(definition.get("icon", GAME_DATA.item_icon_path(item_id))),
		})
	return result

## 福利/礼包回包（`1344`）。**形状逐条取自服务端的发送点**（不是猜的）：
##   `1344:1:<礼包下标>:<剩余秒>:<总秒>`            `:26601 _send_first_login_gift_status`
##   `1344:2:7:<天&状态@…>:<已登录天数>`            `:26742 _send_weekly_login_gift_status`
##                                                 （状态 1=可领 2=已领 0=不可领）
##   `1344:3:<最后可领等级>`                        `:26867` 等级礼包
##   `1344:4:<上周分钟>:<上周奖励>:<本周分钟>:<bool>` `:26639 _send_monthly_online_reward`
##                                                 （即「线上有礼」页要的四项）
##   `1344:5:<今日已领 0/1>:<累计天数 0..7>`         `:26674 _send_everyday_gift_status`
##   `1344:6:<兑换码结果或 ->`                       `:26889` 兑换码 / `:26897` 五七礼包失败
##   `1344:7`                                        `:26707` 每日礼包领取成功（无载荷，纯信号）
##   `1344:62:<0/1>`                                 `:26897` 五七礼包
##
## ⚠️ 2026-09-27 之前这里解的是 `90`/`91` —— 那是**我们自造的编号**，服务端从不发，
##    于是"礼包状态永远是空的"（`奖励在线查询回归测试` 一直卡在 gift 这一格）。
func _handle_gift_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	match action:
		1:
			if fields.size() < 5:
				return
			authoritative_gifts["first"] = {
				"index": int(fields[2]), "remaining": int(fields[3]), "total": int(fields[4]),
			}
		2:
			if fields.size() < 5:
				return
			var 行: Array[Dictionary] = []
			if fields[3] != "-":
				for 段 in fields[3].split("@", false):
					var 片 := String(段).split("&", true)
					if 片.size() >= 2:
						行.append({"day": int(片[0]), "state": int(片[1])})
			authoritative_gifts["weekly"] = {"days": int(fields[4]), "states": 行}
		3:
			authoritative_gifts["level"] = int(fields[2]) if fields.size() > 2 else 0
		4:
			if fields.size() < 6:
				return
			authoritative_gifts["monthly"] = {
				"last_week_minutes": int(fields[2]),
				"last_week_reward": int(fields[3]),
				"week_minutes": int(fields[4]),
				"gainable": String(fields[5]).to_lower() == "true",
			}
		5:
			if fields.size() < 4:
				return
			authoritative_gifts["everyday"] = {
				"claimed": int(fields[2]) != 0, "accumulated": int(fields[3]),
			}
		6:
			authoritative_gifts["code"] = String(fields[2]) if fields.size() > 2 else ""
		7:
			authoritative_gifts["claim"] = {"kind": "everyday", "success": true}
		62:
			authoritative_gifts["claim"] = {
				"kind": "may7", "success": int(fields[2]) != 0 if fields.size() > 2 else false,
			}
		_:
			return
	state["gift"] = authoritative_gifts.duplicate(true)
	gift_state_received.emit(state)

## 充值活动回包（`1814`）。服务端 `_send_czhuodong_command` 在 AMF3 通道下发的就是
## `{"jylx":1814,"command":N,…}`，四种命令对应四个面板（见 `_send_czhuodong_bootstrap:28003`）：
##   cmd 2 → 配置 `{fc,_xinfu,…}`（首杀礼包 / 新服有礼的资源表）
##   cmd 1 → 限时大奖 status（`bossKills` + `statusTotal/statusEach/detailTotal/detailEach` + 活动起止）
##   cmd 3 → 新服有礼 status（`detailEach/detailRank`）
##   cmd 4 → 首杀礼包 status（`active`=领过没 / `bossKills`=当前击杀数）
## `activities` 那一项由服务端在 cmd 1 里补发，喂「活动奖励」页。
func _handle_czhuodong_dictionary(data: Dictionary) -> void:
	var command := int(data.get("command", -1))
	var 载荷 := data.duplicate(true)
	载荷.erase("jylx")
	载荷.erase("command")
	match command:
		2:
			authoritative_czhuodong["config"] = 载荷
		1:
			authoritative_czhuodong["limit"] = 载荷
		3:
			authoritative_czhuodong["xinfu"] = 载荷
		4:
			authoritative_czhuodong["first_kill"] = 载荷
		_:
			return
	czhuodong_state_received.emit({"command": command, "czhuodong": authoritative_czhuodong.duplicate(true)})

func _handle_exchange_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	if action == 0:
		var offers: Array[Dictionary] = []
		if fields.size() > 2 and fields[2] != "-":
			for encoded in fields[2].split("@", false):
				var parts := String(encoded).split("&", true)
				if parts.size() < 14:
					continue
				var item_id := int(parts[7])
				var definition := GAME_DATA.item(item_id)
				offers.append({
					"sn": int(parts[0]), "time_limited": int(parts[1]) != 0, "rest_time": int(parts[2]),
					"total_limit": int(parts[3]), "character_limit": int(parts[4]), "exchange_count": int(parts[5]),
					"single_exchanged": int(parts[6]), "item_id": item_id, "quantity": int(parts[8]),
					"bind_state": int(parts[9]), "need_gold": int(parts[10]), "need_cash": int(parts[11]),
					"need_yuanbao": int(parts[12]), "need_items": _parse_reward_items(String(parts[13])),
					"name": String(definition.get("name", str(item_id))), "icon": String(definition.get("icon", GAME_DATA.item_icon_path(item_id))),
				})
		authoritative_exchange.assign(offers)
		state["offers"] = authoritative_exchange.duplicate(true)
	elif action == 2:
		state.merge({
			"sn": int(fields[2]) if fields.size() > 2 else 0, "total_exchanged": int(fields[3]) if fields.size() > 3 else 0,
			"single_exchanged": int(fields[4]) if fields.size() > 4 else 0, "success": int(fields[5]) != 0 if fields.size() > 5 else true,
			"code": String(fields[6]) if fields.size() > 6 else "ok",
		}, true)
	exchange_state_received.emit(state)

func _handle_fudai_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	## 亲热天堂两帧（原版 `FudaiProcessor.actionShowBaoxiangInfo/GainInfo`）：
	##   `1289:17:<state>:<gained 条目|->:<候选用 @ 连接>:<类型>`
	##   `1289:18:<state>:<index>`
	var action := int(fields[1])
	if action == 17 or action == 18:
		_handle_treasure_text(fields, action)
		return
	## 成就福袋两支（原版 `handleFudaiActions:72-92` 的 case 1 / case 2），解码顺序与宝箱
	## 那两支**逐字节相同**，只是 action 号不同：
	##   `1289:1:<state>:<gained 条目|->:<候选用 @ 连接>:<类型>`（`actionShowFudaiInfo:153-178`）
	##   `1289:2:<state>:<index>`（`actionShowFudaiGainItemInfo:102-121`）
	## ⚠️ 上一版这里挂的是 `if fields.size() < 9: return` + 一套十段假格式（`round_id`、
	##    `selected_slot`、`claimed` 这些字段**原版协议里一个都没有**），真帧只有 6 段和 4 段
	##    ⇒ 每一条福袋回包都被那道闸静默丢掉，在线永远开不了窗（#74）。
	##    `3` 是**客户端发**的领取动作，回包走通用物品/背包帧，不在这条路上；
	##    `33/34` 两支原版 listener 是空函数（`Client.onShowFudaiWindow:8752-8754`）⇒ 没有要移植的行为。
	if action == 1:
		authoritative_fudai = _parse_fudai_state_frame(fields, 1)
		fudai_state_received.emit(authoritative_fudai.duplicate(true))
	elif action == 2:
		authoritative_fudai = _parse_fudai_index_frame(fields, 2)
		fudai_state_received.emit(authoritative_fudai.duplicate(true))

## 「状态 + 已得 + 候选 + 类型」那一帧（fudai 的 1 / 宝箱的 17 —— 两支解码顺序一样，
## 差别只是 `readByte / ItemNode.decode / ArrayCodec(ItemNode).decode / readByte` 前的号）。
func _parse_fudai_state_frame(字段: PackedStringArray, action: int) -> Dictionary:
	var 条目 := {}
	if 字段.size() > 3 and String(字段[3]) != "" and String(字段[3]) != "-":
		条目 = _parse_item_entry(String(字段[3]))
	var 候选: Array = []
	if 字段.size() > 4 and String(字段[4]) != "" and String(字段[4]) != "-":
		候选 = _parse_item_list(String(字段[4]))
	return {
		"action": action,
		"state": maxi(0, int(字段[2])) if 字段.size() > 2 else 0,
		"gained": 条目,
		"candidates": 候选,
		"type": int(字段[5]) if 字段.size() > 5 else -1,
	}

## 「状态 + 落点」那一帧（fudai 的 2 / 宝箱的 18）：`state = readByte(); index = readInt()`。
## 缺段按原版"读不出来就报错返回"处理不了，这里保守取 0/-1。
func _parse_fudai_index_frame(字段: PackedStringArray, action: int) -> Dictionary:
	return {
		"action": action,
		"state": 2 if 字段.size() < 3 else maxi(0, int(字段[2])),
		"index": int(字段[3]) if 字段.size() > 3 else -1,
	}

## 解析亲热天堂的两帧（见 `_handle_fudai_text` 里的格式注释）。
## `authoritative_treasure` 的形状：
##   {"action": 17|18, "state": 0|1|2, "gained": 条目, "candidates": [条目…], "type": 2..4, "index": int}
## 状态语义（原版 `FudaiState`）：0 待显示 / 1 已开出（可开始）/ 2 待停止（动画中）。
func _handle_treasure_text(fields: PackedStringArray, action: int) -> void:
	authoritative_treasure = _parse_fudai_index_frame(fields, action) \
			if action == 18 else _parse_fudai_state_frame(fields, action)
	treasure_state_received.emit(authoritative_treasure.duplicate(true))

func _handle_achievement_text(fields: PackedStringArray) -> void:
	if fields.size() < 2:
		return
	var action := int(fields[1])
	var state := {"action": action}
	if action == 0 and fields.size() >= 6:
		var tab := int(fields[2])
		for index in range(authoritative_achievements.size() - 1, -1, -1):
			if int(authoritative_achievements[index].get("tab", 0)) == tab:
				authoritative_achievements.remove_at(index)
		if fields[5] != "-":
			for encoded in fields[5].split("@", false):
				var parts := String(encoded).split("&", true)
				if parts.size() >= 4:
					authoritative_achievements.append({"tab": tab, "index": int(parts[0]), "value": int(parts[1]), "target": int(parts[2]), "gained": int(parts[3]) != 0})
		state.merge({"tab": tab, "total": int(fields[3]), "begin": int(fields[4]), "achievements": authoritative_achievements.duplicate(true)}, true)
	elif action == 2:
		state.merge({"tab": int(fields[2]) if fields.size() > 2 else 0, "index": int(fields[3]) if fields.size() > 3 else 0, "success": int(fields[4]) != 0 if fields.size() > 4 else false, "value": int(fields[5]) if fields.size() > 5 else 0, "code": String(fields[6]) if fields.size() > 6 else ""}, true)
	achievement_state_received.emit(state)

func _decode_cash_item_fields(parts: PackedStringArray) -> Dictionary:
	if parts.size() < 16:
		return {}
	var item_id := int(parts[13])
	if item_id <= 0:
		return {}
	var definition := GAME_DATA.item(item_id)
	var normalized_id := String(definition.get("id", str(item_id).pad_zeros(8)))
	return {
		"id": normalized_id,
		"sn": int(parts[0]),
		"item_id": item_id,
		"name": String(definition.get("name", normalized_id)),
		"description": String(definition.get("description", "")),
		"category": String(definition.get("category", "商城")),
		"icon": String(definition.get("icon", GAME_DATA.item_icon_path(item_id))),
		"currency": "cash",
		"original_price": int(parts[1]),
		"price": int(parts[2]),
		"is_discount": int(parts[3]) != 0,
		"is_time_limited": int(parts[4]) != 0,
		"time_begin": int(parts[5]),
		"time_end": int(parts[6]),
		"is_count_limited": int(parts[7]) != 0,
		"total_count": int(parts[8]),
		"sell_count": int(parts[9]),
		"is_new": int(parts[10]) != 0,
		"is_hot": int(parts[11]) != 0,
		# ⚠️ 第 13 个字段（下标 12）在 AS3 里叫 **`isLiJin`**（礼金），
		# `CashItemInfo.as:69` `this.isLiJin = param1.readByte();`，
		# 商城商品行据此显示券/礼金角标（`CashItemCell.as:197`）。
		# 2026-09-26 之前这里叫 `is_gift_money`（位置对、名字错），改名对齐真值。
		"is_li_jin": int(parts[12]) != 0,
		"expire_days": int(parts[14]),
		"is_package": int(parts[15]) != 0,
	}

# 原版线格式（见 测试/原版协议抓包.json 实测）：readStr = "<载荷>:<毫秒时间戳>"，
# AMF3 对象只带 opCode 与 readStr 两个字段。
# 一键端（C# NewLoginServer）用的是 pageLength/sid/ifsjc 的 bridge 信封，
# 而两份本地 Python 服务端（2.2.3 / Nya-2.1.5）只认原版两字段形式，故在此切换。
const 原版两字段信封 := true

func _send_bridge_request(opcode: int, content: String) -> bool:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var timestamp := int(Time.get_unix_time_from_system() * 1000.0)
	var request := {}
	if 原版两字段信封:
		# content 自身已按原版约定携带前缀（如 "11:8"），此处只补时间戳，勿再加 opcode。
		request = {"opCode": opcode, "readStr": "%s:%d" % [content, timestamp]}
	else:
		request = {
			"pageLength": content.to_utf8_buffer().size(),
			"opCode": opcode,
			"sid": _send_sid,
			"ifsjc": 0,
			"readStr": "%s:%d" % [content, timestamp],
		}
	_send_sid = (_send_sid + 1) & 0xffff
	if _send_sid == 0:
		_send_sid = 1
	return _tcp.put_data(_amf3_encode_object(request)) == OK

func _amf3_encode_object(value: Dictionary) -> PackedByteArray:
	var result := PackedByteArray([0x0a])
	_amf3_append_u29(result, 0x0b)
	_amf3_append_utf8_vr(result, "")
	for key in value:
		_amf3_append_utf8_vr(result, String(key))
		if String(key) == "readStr":
			result.append(0x06)
			_amf3_append_encrypted_utf8_vr(result, String(value[key]))
		else:
			_amf3_append_value(result, value[key])
	_amf3_append_utf8_vr(result, "")
	return result

func _amf3_append_value(data: PackedByteArray, value: Variant) -> void:
	match typeof(value):
		TYPE_BOOL:
			data.append(0x03 if value else 0x02)
		TYPE_INT:
			data.append(0x04)
			_amf3_append_u29(data, int(value) & 0x1fffffff)
		_:
			data.append(0x06)
			_amf3_append_utf8_vr(data, String(value))

func _amf3_append_utf8_vr(data: PackedByteArray, value: String) -> void:
	var bytes := value.to_utf8_buffer()
	_amf3_append_u29(data, (bytes.size() << 1) | 1)
	data.append_array(bytes)

func _amf3_append_encrypted_utf8_vr(data: PackedByteArray, value: String) -> void:
	var bytes := PackedByteArray()
	for index in value.length():
		_append_utf8_codepoint(bytes, value.unicode_at(index) ^ XOR_KEY.unicode_at(index % XOR_KEY.length()))
	_amf3_append_u29(data, (bytes.size() << 1) | 1)
	data.append_array(bytes)

func _amf3_append_u29(data: PackedByteArray, value: int) -> void:
	value &= 0x1fffffff
	if value < 0x80:
		data.append(value)
	elif value < 0x4000:
		data.append(((value >> 7) & 0x7f) | 0x80)
		data.append(value & 0x7f)
	elif value < 0x200000:
		data.append(((value >> 14) & 0x7f) | 0x80)
		data.append(((value >> 7) & 0x7f) | 0x80)
		data.append(value & 0x7f)
	else:
		data.append(((value >> 22) & 0x7f) | 0x80)
		data.append(((value >> 15) & 0x7f) | 0x80)
		data.append(((value >> 8) & 0x7f) | 0x80)
		data.append(value & 0xff)

func _amf3_read_string(data: PackedByteArray) -> Dictionary:
	if data.size() < 2 or int(data[0]) != 0x06:
		return {}
	var header := _amf3_read_u29(data, 1)
	if header.is_empty() or (int(header.value) & 1) == 0:
		return {}
	var length := int(header.value) >> 1
	var offset := int(header.next)
	if offset + length > data.size():
		return {}
	return {"bytes": data.slice(offset, offset + length)}

func _amf3_read_u29(data: PackedByteArray, offset: int) -> Dictionary:
	var value := 0
	for index in 4:
		if offset >= data.size():
			return {}
		var byte := int(data[offset])
		offset += 1
		if index == 3:
			value = (value << 8) | byte
			return {"value": value, "next": offset}
		value = (value << 7) | (byte & 0x7f)
		if (byte & 0x80) == 0:
			return {"value": value, "next": offset}
	return {}

func _decrypt_amf_string(bytes: PackedByteArray) -> String:
	var codepoints := _decode_utf8_codepoints(bytes)
	var result := ""
	for index in codepoints.size():
		result += String.chr(int(codepoints[index]) ^ XOR_KEY.unicode_at(index % XOR_KEY.length()))
	return result

func _decode_utf8_codepoints(bytes: PackedByteArray) -> Array[int]:
	var result: Array[int] = []
	var offset := 0
	while offset < bytes.size():
		var first := int(bytes[offset])
		offset += 1
		if first < 0x80:
			result.append(first)
		elif (first & 0xe0) == 0xc0 and offset < bytes.size():
			result.append(((first & 0x1f) << 6) | (int(bytes[offset]) & 0x3f))
			offset += 1
		elif (first & 0xf0) == 0xe0 and offset + 1 < bytes.size():
			result.append(((first & 0x0f) << 12) | ((int(bytes[offset]) & 0x3f) << 6) | (int(bytes[offset + 1]) & 0x3f))
			offset += 2
		elif (first & 0xf8) == 0xf0 and offset + 2 < bytes.size():
			result.append(((first & 0x07) << 18) | ((int(bytes[offset]) & 0x3f) << 12) | ((int(bytes[offset + 1]) & 0x3f) << 6) | (int(bytes[offset + 2]) & 0x3f))
			offset += 3
		else:
			result.append(0xfffd)
	return result

func _append_utf8_codepoint(bytes: PackedByteArray, codepoint: int) -> void:
	if codepoint < 0x80:
		bytes.append(codepoint)
	elif codepoint < 0x800:
		bytes.append(0xc0 | (codepoint >> 6))
		bytes.append(0x80 | (codepoint & 0x3f))
	elif codepoint < 0x10000:
		bytes.append(0xe0 | (codepoint >> 12))
		bytes.append(0x80 | ((codepoint >> 6) & 0x3f))
		bytes.append(0x80 | (codepoint & 0x3f))
	else:
		bytes.append(0xf0 | (codepoint >> 18))
		bytes.append(0x80 | ((codepoint >> 12) & 0x3f))
		bytes.append(0x80 | ((codepoint >> 6) & 0x3f))
		bytes.append(0x80 | (codepoint & 0x3f))

func _get_settings() -> Dictionary:
	var session := get_node_or_null("/root/GameSession")
	return session.game_settings if session != null else {}

func _fail_connection(message: String) -> void:
	_set_status("离线", message)
	if _tcp.get_status() != StreamPeerTCP.STATUS_NONE:
		_tcp.disconnect_from_host()
	_connection_started = false
	authenticated = false
	in_game = false

func _set_status(next_status: String, next_detail: String) -> void:
	if status == next_status and detail == next_detail:
		return
	status = next_status
	detail = next_detail
	connection_status_changed.emit(status, detail)

func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 24) | (int(data[offset + 1]) << 16) | (int(data[offset + 2]) << 8) | int(data[offset + 3])

func _append_u16_be(data: PackedByteArray, value: int) -> void:
	data.append((value >> 8) & 0xff)
	data.append(value & 0xff)

func _append_u32_le(data: PackedByteArray, value: int) -> void:
	for shift in [0, 8, 16, 24]:
		data.append((value >> shift) & 0xff)


func _handle_original_frame(body: PackedByteArray) -> void:
	if body.size() < 7:
		push_warning("BackendConnection: 回帧既不是 AMF3 也不是原始帧（%d 字节）" % body.size())
		return
	var opcode := int(body.decode_u16(4))
	var payload := body.slice(6)
	if opcode == OP_EXCHANGE:
		_decode_exchange_binary(payload)
		return
	if opcode == OP_SKILL_CHANGE_TMP:
		_decode_skill_change_tmp(payload)
		return
	if opcode == OP_SECOND_PASSWORD:
		_decode_second_password(payload)
		return
	push_warning("BackendConnection: 收到**没接的**原始二进制回帧 opcode=%d（%d 字节）" % [opcode, payload.size()])


## `1820 EXCHANGE_ACTION` 的列表回帧解码。字段序**逐字照 AS3 `ExchangeItem.decode`**
## （`data/exchange/ExchangeItem.as:53-80`）：
##   `sn i32 · isTimeLimited u8 · restTime · totalCountLimit · singleCountLimit ·
##    exchangeCount · singleExchanged · targetItemid · targetQuantity · targetBind u8 ·
##    needJinBi · needLiJin · needYuanBao · needItems 条数 i32 ·（每条 itemid i32 + count i32）`
## 服务端 `_send_exchange_recipe_list`（`fake_flash_server.py:26291`）用的就是
## `struct.pack("<Bi", action, 条数)` + 每行 `"<iBi6iB4i"` + 需求 `"<2i"` ⇒ 与此处一字节不差。
## 产出的 dict **与 `_handle_exchange_text` 的 offers 同一个形状**（`authoritative_exchange`
## 是唯一的会话态兑换表，`系统窗口` 的「兑换」页与伊鲁卡的「兑换商店」都读它 ⇒ 不许有两份形状）。


func _decode_exchange_binary(payload: PackedByteArray) -> void:
	if payload.size() < 5:
		push_warning("BackendConnection: 1820 原始回帧太短（%d 字节）" % payload.size())
		return
	var action := int(payload[0])
	var 位 := 1
	var 条数 := int(payload.decode_s32(位))
	位 += 4
	if 条数 < 0 or 条数 > 4096:
		push_warning("BackendConnection: 1820 回帧条数异常（%d）⇒ 整帧丢弃" % 条数)
		return
	var offers: Array[Dictionary] = []
	for _第 in 条数:
		if 位 + 50 > payload.size():		# 一行标量 = 12×i32 + 2×u8 = 50 字节（`<iBi6iB4i`）
			push_warning("BackendConnection: 1820 回帧在第 %d 行截断 ⇒ 只收前 %d 行" % [_第, offers.size()])
			break
		var sn := int(payload.decode_s32(位)); 位 += 4
		var 限时 := int(payload.decode_u8(位)) != 0; 位 += 1
		var 剩余时间 := int(payload.decode_s32(位)); 位 += 4
		var 总限 := int(payload.decode_s32(位)); 位 += 4
		var 每人限 := int(payload.decode_s32(位)); 位 += 4
		var 已兑总 := int(payload.decode_s32(位)); 位 += 4
		var 已兑我 := int(payload.decode_s32(位)); 位 += 4
		var 目标号 := int(payload.decode_s32(位)); 位 += 4
		var 目标数 := int(payload.decode_s32(位)); 位 += 4
		var 绑定 := int(payload.decode_u8(位)); 位 += 1
		var 要金币 := int(payload.decode_s32(位)); 位 += 4
		var 要礼金 := int(payload.decode_s32(位)); 位 += 4
		var 要元宝 := int(payload.decode_s32(位)); 位 += 4
		var 料数 := int(payload.decode_s32(位)); 位 += 4
		if 料数 < 0 or 位 + 料数 * 8 > payload.size():
			push_warning("BackendConnection: 1820 回帧第 %d 行的材料数越界（%d）⇒ 整帧丢弃" % [sn, 料数])
			return
		var 料: Array[Dictionary] = []
		for _j in 料数:
			var 料号 := int(payload.decode_s32(位)); 位 += 4
			var 料量 := int(payload.decode_s32(位)); 位 += 4
			var 料定 := GAME_DATA.item(料号)
			料.append({
				"item_id": 料号, "id": String(料定.get("id", str(料号).pad_zeros(8))),
				"name": String(料定.get("name", str(料号))), "quantity": 料量,
				"icon": String(料定.get("icon", GAME_DATA.item_icon_path(料号))),
			})
		var 定 := GAME_DATA.item(目标号)
		offers.append({
			"sn": sn, "time_limited": 限时, "rest_time": 剩余时间,
			"total_limit": 总限, "character_limit": 每人限, "exchange_count": 已兑总,
			"single_exchanged": 已兑我, "item_id": 目标号, "quantity": 目标数,
			"bind_state": 绑定, "need_gold": 要金币, "need_cash": 要礼金,
			"need_yuanbao": 要元宝, "need_items": 料,
			"name": String(定.get("name", str(目标号))),
			"icon": String(定.get("icon", GAME_DATA.item_icon_path(目标号))),
		})
	var 状态 := {"action": action}
	authoritative_exchange.assign(offers)
	状态["offers"] = authoritative_exchange.duplicate(true)
	exchange_state_received.emit(状态)


## `1813 SKILL_CHANGE_TMP` 原始帧解码：`<i 条数>` + 每行 `<ii 忍术号, 加成层>`（全帧小端）。
## 原版 `AllInOneProcessor.as:576-607` 每行只读 id 与 skillLevel 两段、第三段恒置 0——
## 服务端 `_send_skill_gem_bonuses:49669` 也正好是两段（`struct.pack("<ii", skill_id, bonus)`）。
## ⚠️ **整帧替换**：原版 `setAddedSkillLevelList:566-578` 先把旧表 `delete` 光再填，
##   所以"加成消失"（卸下勾玉）靠服务端发一张**空表**表达 —— 不能做成 merge。
func _decode_skill_change_tmp(payload: PackedByteArray) -> void:
	if payload.size() < 4:
		push_warning("BackendConnection: 1813 原始回帧太短（%d 字节）" % payload.size())
		return
	var 条数 := int(payload.decode_s32(0))
	if 条数 < 0 or payload.size() < 4 + 条数 * 8:
		push_warning("BackendConnection: 1813 回帧条数异常（%d，帧 %d 字节）⇒ 整帧丢弃" % [条数, payload.size()])
		return
	var 表 := {}
	var 位 := 4
	for _i in 条数:
		var 号 := int(payload.decode_s32(位))
		var 层 := int(payload.decode_s32(位 + 4))
		位 += 8
		表[str(号).pad_zeros(7)] = 层
	_apply_skill_added_levels(表)


## 二进制帧与文本帧共用的落表：**整份赋值**（原版 `setAddedSkillLevelList:566-578`
## 先 delete 光旧表再填），再转进 `GameSession` 让忍术页重画。
func _apply_skill_added_levels(表: Dictionary) -> void:
	authoritative_skill_added_levels = 表
	skill_added_levels_received.emit(表.duplicate())
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.apply_added_skill_levels(表)


## `1813 SKILL_CHANGE_TMP` 的 **AMF3 文本帧**：`1813:<条数>[:<忍术号>:<加成层>…]`。
## 本客户端恒走 AMF3（`:1-26`），服务端二进制 1813 只在 `wire_mode == "original"` 发 ⇒
## 修前这条链在实机上**永远是空的**（忍术页只印基础层，门里靠合成二进制帧自证）。
## 空表 = `1813:0`，同样走**整表替换**（卸下玉链/勾玉要把旧加成清掉）。
func _handle_skill_change_tmp_text(fields: PackedStringArray) -> void:
	if fields.size() < 2 or not String(fields[1]).is_valid_int():
		push_warning("BackendConnection: 1813 文本帧缺条数（%s）⇒ 丢弃" % ":".join(fields))
		return
	var 条数 := int(fields[1])
	if 条数 < 0 or fields.size() < 2 + 条数 * 2:
		push_warning("BackendConnection: 1813 文本帧条数异常（%d，字段 %d 个）⇒ 整帧丢弃"
				% [条数, fields.size()])
		return
	var 表 := {}
	var 位 := 2
	for _i in 条数:
		var 号 := int(fields[位])
		var 层 := int(fields[位 + 1])
		位 += 2
		表[str(号).pad_zeros(7)] = 层
	_apply_skill_added_levels(表)


## 2309 下行解码。形状 = `SecondLevelPasswordProcessor.handleAction:310-358` 那 11 个 `case`
## （每条后面标的是 AS3 里那几行读取）：
##   0 passwordResultFirstTime → int              （`:96-113`）
##   1 QAResult               → int               （`:202-219`）
##   2 isFirstTimeResult      → int               （`:360-377`）
##   3 contactResult          → int               （`:176-193`）
##   4 QAConformResult        → int               （`:77-94`）
##   5 Questions              → utf, utf, int     （`:287-308`）
##   6 modifyPasswordResult   → int, int          （`:259-278`）
##   7 requestPassword        → 无载荷            （`:60-75`，服务端催你解锁）
##   8 releaseLockResult      → int               （`:240-257`）
##   9 QAConformResultForDelete → int, int        （`:147-166`）
##   10 requestModifyPasswordResult → int         （`:221-238`）
## ⚠️ **全帧小端**：int 用 `decode_s32`、utf 的长度前缀用 `decode_u16`。
##   原版 Flash 的 `writeInt/writeUTF` 是**大端**，而烘这一帧的是本工程服务端
##   `_send_second_level_password_response`（`fake_flash_server.py:21940-21967`，
##   `struct.pack("<B"/"<i")` + `_original_utf` = `struct.pack("<H", 长)` + UTF-8，`:13263-13268`）。
##   这是**有意偏离 AS3 的第二处**（第一处是上行改裸 JSON），两条都记在
##   `真值/窗口/二级密码.md` §① —— 照 AS3 改成大端就连不上服务端了。
const 二级密码下行形状 := {
	0: [0, 1], 1: [0, 1], 2: [0, 1], 3: [0, 1], 4: [0, 1],
	5: [2, 1], 6: [0, 2], 7: [0, 0], 8: [0, 1], 9: [0, 2], 10: [0, 1],
}


func _decode_second_password(payload: PackedByteArray) -> void:
	if payload.is_empty():
		push_warning("BackendConnection: 2309 回帧是空的 ⇒ 丢弃")
		return
	var 动作 := int(payload[0])
	var 形: Variant = 二级密码下行形状.get(动作)
	if 形 == null:
		push_warning("BackendConnection: 2309 回帧动作号不认识（%d）⇒ 整帧丢弃" % 动作)
		return
	var 串数 := int((形 as Array)[0])
	var 整数数 := int((形 as Array)[1])
	var 位 := 1
	var 值: Array = []
	for _i in 串数:
		if 位 + 2 > payload.size():
			push_warning("BackendConnection: 2309 回帧第 %d 根 utf 连长度都读不完（剩 %d 字节）⇒ 丢弃" % [_i, payload.size() - 位])
			return
		var 长 := int(payload.decode_u16(位))
		位 += 2
		if 长 < 0 or 位 + 长 > payload.size():
			push_warning("BackendConnection: 2309 回帧 utf 长度越界（%d，帧共 %d 字节）⇒ 丢弃" % [长, payload.size()])
			return
		值.append(payload.slice(位, 位 + 长).get_string_from_utf8())
		位 += 长
	for _i in 整数数:
		if 位 + 4 > payload.size():
			push_warning("BackendConnection: 2309 回帧第 %d 根 int 读不完（剩 %d 字节）⇒ 丢弃" % [_i, payload.size() - 位])
			return
		值.append(int(payload.decode_s32(位)))
		位 += 4
	## 会话态里那三个数**在这一处更新**（不在窗口里各存一份）：六扇窗共用同一份，
	## 而 `类型` / `已解锁` 决定的是「说明窗」那三颗钮的使能与文字（`TwoPasswordSayWindow.updateView:37-42`）。
	match 动作:
		2:
			authoritative_second_password["类型"] = int(值[0])
		5:
			authoritative_second_password["删除次数"] = int(值[2])
		6:
			authoritative_second_password["修改次数"] = int(值[1])
		8:
			authoritative_second_password["已解锁"] = int(值[0]) == 1
		9:
			authoritative_second_password["删除次数"] = int(值[1])
		10:
			authoritative_second_password["修改次数"] = int(值[0])
	二级密码帧.emit(动作, 值)
