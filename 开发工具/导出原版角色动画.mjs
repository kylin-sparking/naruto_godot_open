import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const 脚本目录 = path.dirname(fileURLToPath(import.meta.url));
const 项目目录 = path.resolve(脚本目录, "..");
const 参考目录 = path.resolve(项目目录, "..", "..", "code", "火影世界服务端");
const 数据源 = path.join(参考目录, "GameData.dat.json");
const 动画源 = path.join(参考目录, "swf-extracted-assets", "animations", "char");
const 元数据路径 = path.join(项目目录, "数据", "角色", "动画元数据.json");
const 输出目录 = path.join(项目目录, "素材", "角色动画", "玩家");

// 与服务端 AppearanceUtil.IsKnownFace 保持一致。
const 原版模型编号 = ["00000001", "00000002", "00000100", "00000103", "00000200", "00000203", "00000300", "00000303", "00000400", "00000403"];

for (const 文件 of [数据源, 元数据路径]) {
  if (!fs.existsSync(文件)) throw new Error(`缺少原版数据：${文件}`);
}

const 原版数据 = JSON.parse(fs.readFileSync(数据源, "utf8").replace(/^\uFEFF/, ""));
const 元数据 = JSON.parse(fs.readFileSync(元数据路径, "utf8").replace(/^\uFEFF/, ""));
元数据.character ||= {};

const 重复默认模型目录 = path.join(输出目录, "原版角色_00000001");
if (重复默认模型目录.startsWith(`${输出目录}${path.sep}`) && fs.existsSync(重复默认模型目录)) {
  fs.rmSync(重复默认模型目录, { recursive: true, force: true });
}

for (const 编号 of 原版模型编号) {
  const 定义 = 原版数据.M_Char?.[编号];
  const 源目录 = path.join(动画源, `Char_${编号}`);
  if (!定义 || !fs.existsSync(源目录)) throw new Error(`角色 ${编号} 的原版定义或序列帧缺失`);
  元数据.character[编号] = 定义;
  const 目标目录 = path.join(输出目录, 编号 === "00000001" ? "木叶忍者_00000001" : `原版角色_${编号}`);
  fs.mkdirSync(目标目录, { recursive: true });
  for (const 文件名 of fs.readdirSync(源目录)) {
    if (!文件名.toLowerCase().endsWith(".png")) continue;
    const 目标文件名 = `Char_${编号}.swf_${文件名}`;
    fs.copyFileSync(path.join(源目录, 文件名), path.join(目标目录, 目标文件名));
  }
}

fs.writeFileSync(元数据路径, JSON.stringify(元数据));
console.log(`原版角色动画导出完成：${原版模型编号.length} 套`);
