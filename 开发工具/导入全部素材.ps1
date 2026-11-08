$ErrorActionPreference = "Stop"
$clientRoot = Split-Path -Parent $PSScriptRoot

node (Join-Path $PSScriptRoot "导入物品图标.mjs")
node (Join-Path $PSScriptRoot "导入角色动画.mjs")
node (Join-Path $PSScriptRoot "导入怪物动画.mjs")
node (Join-Path $PSScriptRoot "导入技能资源.mjs")
node (Join-Path $PSScriptRoot "导入NPC宠物动画.mjs")

Write-Host "全部素材索引已更新：$clientRoot"
