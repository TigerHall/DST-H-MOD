# DST-H-MOD 项目记忆

## 项目约定

### 版本管理

- 每次对 `modinfo.lua` 做任何配置修改后，必须同时更新 `version` 字段（如 `"3.3"` → `"3.4"`），否则已安装 MOD 的玩家不会自动同步更改
- 版本号格式：主版本.次版本（如 `"3.4"`）

### 目录联接 (Junction)

- GitHub 项目与 DST 游戏 `mods/` 目录通过 `mklink /J`（或 `New-Item -ItemType Junction`）建立联接，实现修改即同步

### 模块映射（用户报错前缀 → GitHub 目录名，硬链接对应）

- `hcane` = "行走手杖优化"
- `hslot` = "格子优化"
- `hfood` = "零食优化"
- `htree` = "水中木优化"
- `htable` = "茶几优化"
- `hpack` = "背包优化"
- `hh` = "实验代码"

### 各 MOD 功能触发方式（无键盘快捷键）

- `hcane` 行走手杖优化：**右键使用**手杖切换总开关（`useableitem` 组件 `SetOnUseFn`）
- `hslot` 格子优化：**右键检查**物品（劫持 `inspectable.GetDescription`）触发格子开关/月眼传送
- `hpack` 背包优化：**装备/卸下**事件监听，自动触发防御、保鲜、自动采集
- `hfood` 零食优化：纯数值修改（`edible` 组件属性翻倍），无玩家交互
- `htree` 水中木优化：纯属性修改 + 事件监听，无玩家交互
- `htable` 茶几优化：纯属性修改，无玩家交互
- 6 个 MOD 均无 `TheInput`/`AddKeyUpHandler`/`KEY_` 等键盘快捷键代码

### 代码风格

- 使用 `AddPrefabPostInit` + 闭包结构
- 用 `local config = { ... }` 统一读取配置
- 中文注释标注每个功能块
- 所有定时任务在 `onremove` 事件中清理

### 配置项规范

- 所有 MOD 的配置项有且仅有两种类型：
  1. **是否选项（Boolean）**：使用 `addConfig()` 辅助函数，生成 On/Off 两个选项
  2. **多选项（Multi-option）**：在 `configuration_options` 中直接写 `options = { ... }` 数组，自行指定 `default`
- 任何配置修改后必须更新 `version`
