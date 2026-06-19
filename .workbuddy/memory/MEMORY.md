# DST-H-MOD 项目记忆

## 项目约定

### 版本管理
- 每次对 `modinfo.lua` 做任何配置修改后，必须同时更新 `version` 字段（如 `"3.3"` → `"3.4"`），否则已安装 MOD 的玩家不会自动同步更改
- 版本号格式：主版本.次版本（如 `"3.4"`）

### 目录联接 (Junction)
- GitHub 项目与 DST 游戏 `mods/` 目录通过 `mklink /J`（或 `New-Item -ItemType Junction`）建立联接，实现修改即同步
- 行走手杖优化 → hcane

### 代码风格
- 使用 `AddPrefabPostInit` + 闭包结构
- 用 `local config = { ... }` 统一读取配置
- 中文注释标注每个功能块
- 所有定时任务在 `onremove` 事件中清理
