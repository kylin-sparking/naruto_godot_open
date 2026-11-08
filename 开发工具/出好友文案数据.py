# -*- coding: utf-8 -*-
"""抽好友页要用的语言表键 → `数据/界面/好友_文案.json`。

为什么要落一份 json：控制器里硬编码中文是这工程的既有欠账（装备打造那页就被点过），
按键取值才能和原版逐字一致、也才能被门核。源 = `真值文档/UI/texts/{core,ui,message}.json`。
缺键直接 raise（宁可生成失败，也不自造文案）。跑法：python 开发工具/出好友文案数据.py
"""
import io
import json
import os
import sys

# ⚠️ 两个路径原来是**作者机上的绝对路径**（源在他那台机器的 `真值文档/UI/texts`，
#    落盘更是写进他自己那份 naruto_godot 拷贝里）。改成跟着本仓库走：
#    源取本工程一直在用的 AS3 语言表（`开发工具/原版数据.py`，同一份文案），
#    落盘落回本工程的 `数据/界面/`。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as _语言源  # noqa: E402
落 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  "数据", "界面", "好友_文案.json")

# 全部出处写死在这里，便于逐条回查 AS3 行号
键 = {
    # 行菜单项（`FriendGird.as:129-196`）
    "FRIEND_QUERY": "FG:132 查看", "FRIEND_CHAT": "FG:132 对话", "FRIEND_PRIVATE": "FG:132 密语",
    "FRIEND_TEAM": "FG:132 组队", "FRIEND_SHOP": "FG:132 看摊", "FRIEND_DEL": "FG:132 删除",
    "FRIEND_BLACK": "FG:132 拉黑", "FRIEND_MOVE": "FG:172 移除", "FRIEND_DA_TAN": "FG:162 打探",
    "ZENGHUA": "FG:135 赠花", "TROOP_MENU_ADD_FRIEND": "FG:150 交友", "ZHUCHU_SHIMEN": "FG:190 逐出师门",
    # 确认弹正文（`FriendWindow2.as:380-418`，全部 showInputDialog）
    "FRIEND_SHANCHU_LIANXIREN": "FW2:391 删除联系人",
    "FRIEND_SHANCHU_ZUIJIN_LIANXIREN": "FW2:401 删除最近联系人",
    "FRIEND_CHOUHEN_QINGLING": "FW2:406 泯恩仇",
    "FRIEND_YIRU_BLACKLIST": "FW2:416 移入黑名单",
    "FRIEND_CONG_BLACKLIST_YICHU": "FW2:380 从黑名单移除",
    "FRIEND_DELETE_PEIOU": "FW2:198 羁绊不可删（showMessageDialog）",
    "FRIEND_TIP_INPUT_CHAR_NAME": "FW2:92 请输入角色名（showMessageDialog）",
    "ON_LINE_PLAYER": "FW2:355 该玩家不在线",
    # 窗标题与页签
    "FRIEND": "FW2:265", "FRIEND_TAB_LINKMAN": "FW2:266", "FRIEND_TAB_SHITU": "FW2:266",
    "FRIEND_TAB_CHOU_REN": "FW2:266", "FRIEND_TAB_BACKLIST": "FW2:266", "FRIEND_TAB_LAST": "FW2:266",
    "FRIENDCHAT_WINDOW_TITLE": "FCW:132 与%1对话中", "FRIENDCHAT_SEND": "FCW:274",
    "SELCET_PLAYER_WINDOW_TITLE": "SPW:123（原键拼错 SELCET）",
    # 选人窗静态文案（`SelectPlayerWindow.as:124-219`）
    "PLAYER_NAME": "SPW:124 角色名", "SEARCH_RESULTS": "SPW:146 搜索结果",
    "GAME_PLAYER_NAME": "SPW:148 表头：名字", "CHARACTOR_LEVEL": "SPW:151 表头：等级",
    "CHARACTOR_JOB": "SPW:154 表头：职业", "SEARCH_MOHU": "SPW:157 模糊查询提示",
    "TROOP_SEARCH_BTN": "SPW:213 搜索", "TROOP_SHOW_CHAR_INFO_BTN": "SPW:216 查看资料",
    "MULTIFUNCTIONAL": "SPW:219 多功能",
    # 行名前的羁绊前缀（`FriendItemRenderer.as:92`，黄色 #fff000 + 角色名）
    "FRIEND_FUQI": "FI:92",
    "DATAN_WINDOW_TITLE": "MPW:97", "DATAN_BUTTON_NAME": "MPW:98", "DATAN_PROMPT_3": "MPW:95",
    "SHOP_BUY": "ItemCaiLiaoBox.as 材料盒里的购买钮",
    # 打探结果四档（`MPromptWindow.as:327-343` updateDaTanView）
    "DATA_INFOSTR_1": "MPW:327 查到了（线/图/座标）",
    "DATA_INFOSTR_2": "MPW:332,337 图与座标未知",
    "DATA_INFOSTR_3": "MPW:343 图与座标空",
    "DATAN_PROMPT_1": "MPW:331 该玩家不在线",
    "DATAN_PROMPT_2": "MPW:336 背包没有乾坤密卷",
    # 选人窗多功能钮在加好友档的文案（`FriendTabLink.as:55,74`）
    "FRIEND_ADD": "FTL:55 添加好友",
    "COMMON_OK": "通用", "COMMON_CANCEL": "通用",
}

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    表 = {}
    for 档 in ("core", "ui", "message"):
        for k, v in _语言源.读语言表(档).items():
            if isinstance(v, str):
                表.setdefault(k, v)
    出 = {}
    for k, 处 in 键.items():
        if k not in 表:
            raise SystemExit("语言表缺键：" + k)
        出[k] = {"文": 表[k], "出处": 处}
    with io.open(落, "w", encoding="utf-8") as f:
        json.dump(出, f, ensure_ascii=False, indent=1)
    print("写 %d 条 → %s" % (len(出), 落))
