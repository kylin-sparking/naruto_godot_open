import fs from "node:fs";
import path from "node:path";

/**
 * A3 起，"素材从哪来"只有一个口径，六个导入器共用：
 *
 * 包①二手完整美术资源 PNG 包（用环境变量 `NARUTO_ART_ROOT` 或 `../完整美术资源` 指定）
 * 包②`素材/原版直解/<分类>` —— 由 `补齐原版素材.mjs` 从**原版客户端 swf** 现解出来的补充包，
 *     命名沿用包口径 `<库名>.swf_<chid>_<类名>.png`，所以扫法与包①完全一致。
 *
 * 顺序即优先级：包①先命中先用，包②只补包①缺的 —— 直解是原件的等价物，不必覆盖既有图。
 *
 * 数据表同理：老默认值指向已丢失的 `NarutoWorld_Server_.../data/GameData.dat.json`，
 * 现在由 `导出原版源.py` 从 2.2.3 的 .dat 现导到 `../原版源数据/`。
 */

const 包根候选 = (项目目录, 覆盖) => [
  覆盖,
  process.env.NARUTO_ART_ROOT,
  path.join(项目目录, "..", "完整美术资源"),
].filter(Boolean).map((根) => path.resolve(根));

/** 某个分类下所有存在的素材目录，按优先级排好；末尾恒挂直解包（不存在则剔除）。 */
export function 分类目录(项目目录, 分类, 覆盖) {
  const 根列表 = 包根候选(项目目录, 覆盖);
  if (!根列表.includes(path.join(项目目录, "素材", "原版直解"))) {
    根列表.push(path.join(项目目录, "素材", "原版直解"));
  }
  const 目录 = [...new Set(根列表)].map((根) => path.join(根, 分类));
  const 留着 = 目录.filter((目录) => fs.existsSync(目录));
  if (留着.length === 0) throw new Error(`分类「${分类}」在任何素材包里都没有目录：\n  ${目录.join("\n  ")}`);
  return 留着;
}

/** 逐类目录扫 PNG，文件名口径与包一致（跳过 `[1]` 那份重复图）。 */
export function 扫分类图(项目目录, 分类, 覆盖) {
  const 出 = [];
  for (const 目录 of 分类目录(项目目录, 分类, 覆盖)) {
    for (const 名 of fs.readdirSync(目录).sort()) {
      if (!名.toLowerCase().endsWith(".png") || 名.includes("[1]")) continue;
      出.push({ 文件名: 名, 路径: path.join(目录, 名) });
    }
  }
  return 出;
}

export function 源数据(项目目录, 覆盖) {
  const 候选 = [
    覆盖,
    process.env.NARUTO_DATA_JSON,
    path.join(项目目录, "..", "原版源数据", "GameData.dat.json"),
    path.join(项目目录, "..", "NarutoWorld_Server_202607222145-master",
      "NarutoWorld_Server_202607222145-master", "data", "GameData.dat.json"),
  ].filter(Boolean).map((文件) => path.resolve(文件));
  const 命中 = [...new Set(候选)].find((文件) => fs.existsSync(文件));
  if (!命中) throw new Error(`找不到 GameData.dat.json，试过：\n  ${[...new Set(候选)].join("\n  ")}`);
  return 命中;
}
