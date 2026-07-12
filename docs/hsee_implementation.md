# HSee 便携物品查看器 — 实现文档

> 版本：0.4 | MOD：`H-测试`（实验代码）
> 实现方案：方案 A（直接容器）

---

## HSee 是什么

HSee 是一个便携式物品查看/交换器（类似背包探查器）。它是一个可制作的装备物品，使用时创建一个临时容器格子界面，将玩家的所有物品（装备 + 物品栏）搬入，让玩家可以自由整理、交换物品，关闭后自动归还。

---

## 核心文件结构

```
实验代码/
├── modmain.lua              # 入口：配方 + 容器参数 + 语言
├── modinfo.lua              # 配置项（hsee_enable）
├── anim/
│   └── medal_skin_staff.zip # 动画素材（临时复用，后续替换）
├── images/
│   └── inventoryimages/
│       ├── medal_skin_staff.tex  # 图标（临时复用，后续替换）
│       └── medal_skin_staff.xml  # 图标图集
└── scripts/
    └── prefabs/
        └── hsee.lua         # 物品预制体 + 池容器预制体（一个文件两个 Prefab）
```

### hsee.lua 包含两个 Prefab

| Prefab 名 | 类型 | 用途 |
|-----------|------|------|
| `hsee` | 物品 | 玩家的装备物品，使用 `spellcaster` 触发容器打开 |
| `hsee_pool` | 容器实体 | 不可见的临时容器，承载玩家的物品，关闭后自动归还 |

---

## 实现逻辑（方案 A）

### 使用流程

1. **制作 HSee**：在科学二本制作，材料：金块×4 + 树枝×6 + 草×6
2. **使用 HSee**：右键 HSee（装备栏中或拿在手上均可）
3. **搬入物品**：自动将玩家的装备 + 物品栏物品搬入临时容器
4. **整理交换**：玩家在容器界面中自由拖拽物品
5. **关闭归还**：关闭容器后，物品自动归还到玩家装备栏/物品栏

### 关键技术细节

| 步骤 | 实现 |
|------|------|
| 物品预制体 | `medal_skin_staff` 模式：`CreateEntity` → Transform/AnimState/Network → `SetPristine` → 服务端组件（weapon, inspectable, inventoryitem, equippable, spellcaster） |
| 施法触发 | `spellcaster:SetSpellFn(spellfn)` + `canuseontargets=true` + `canusefrominventory=true` |
| 容器动态布局 | 每次创建 pool 时，根据 `EQUIPSLOTS` 的键数量动态计算第 1 行装备槽位的位置 |
| 装备映射 | 使用 `equip_map` 表记录每个 slot 对应的装备槽类型，确保归还时装备回到正确的位置 |
| 自动归还 | `container.onclosefn` 触发 `DoTaskInTime(0)` → `returnitems` 事件 → 遍历所有 slot 归还 |
| 防丢失 | 如果 HSee 在容器打开期间被移除（`onremove` 事件），立即触发归还逻辑 |

### 动态装备行

```lua
-- 第 1 行（y=112.5）：根据 EQUIPSLOTS 数量居中排列
-- 示例：3 个装备槽 → -75, 0, 75
-- 示例：5 个装备槽 → -150, -75, 0, 75, 150

-- 第 2~4 行（y=37.5, -37.5, -112.5）：5 列物品栏格子
```

**支持的装备槽**（来自 `EQUIPSLOTS`）：
- `HANDS`, `HEAD`, `BODY`, `BEARD`（标准 DST）
- 如果勾选了增加装备栏的其他 MOD，会自动扩充第 1 行

---

## 容器 UI

- **贴图**：`ui_fish_box_5x4`（官方鱼箱 5×4 格子布局）
- **位置**：屏幕居中偏上（`pos = Vector3(0, 220, 0)`）
- **背景**：鱼箱自带水波纹背景
- **所有物品均可放入**：`itemtestfn` 返回 `true`

---

## 配置项

| 配置名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `hsee_enable` | Boolean | true | 控制 HSee 物品是否可用（关闭后配方隐藏） |

---

## 素材依赖（临时）

| 素材 | 来源 | 用途 | 路径 |
|------|------|------|------|
| `medal_skin_staff.tex` / `.xml` | 勋章 MOD → 复制到本地 | 物品图标 + 工具栏图标 | `images/inventoryimages/medal_skin_staff.*` |
| `medal_skin_staff.zip` | 勋章 MOD → 复制到本地 | 物品 3D 动画（手持/掉落/漂浮） | `anim/medal_skin_staff.zip` |
| `ui_fish_box_5x4.zip` | DST 官方 | 容器格子界面贴图 | DST 内置资源 |

> 前两项素材已从勋章 MOD 复制到本地，**直接替换对应路径下的文件即可更新素材**。
> 不再依赖勋章 MOD 必须安装。

---

## 调试命令

```lua
-- 给予 HSee
c_give("hsee", 1)

-- 打开 HSee（服务端）
c_select()  -- 选中自己
-- 然后右键 HSee

-- 查看容器 slot
c_sel().components.container:GetNumSlots()

-- 强制归还（如果卡住了）
-- 需要替换 <你的HSee> 为实际实体 ID
c_select().components.container:Close()
```

---

## 已知踩坑 & 注意事项

| 坑 | 说明 |
|----|------|
| `finiteuses.Use` 无耐久检查 | 本 MOD 未使用 `finiteuses`，无此坑 |
| UI 图标不能用 `SetMultColour` | 本 MOD 无自定义 UI 着色，无此坑 |
| 容器动态参数全局污染 | 使用 `containers.widgetsetup(container, nil, custom_params)` 传 `data` 参数，不修改全局 `params` 表 |
| 关闭时物品丢失 | `onclosefn` 使用 `DoTaskInTime(0)` 而不是直接在回调中处理，确保 DST 容器关闭流程安全 |
| 装备槽被占用 | 归还装备时检查目标槽是否已被占用，被占用则放入物品栏 |
| 物品栏满 | `GiveItem` 会自动掉落容不下的物品，不会丢失 |

---

## 后续可扩展

- [ ] 自定义素材替换（图标、动画、手持模型）
- [ ] 方案 A2：搬入搬出模式（支持 `skipautoclose`，离开一定距离自动关闭）
- [ ] 方案 B：自定义 UI + RPC（完全可控的 UI 面板）
- [ ] 皮肤系统支持（参考 `medal_skinable` 组件）
- [ ] NPC/动物背包查看（原设计文档的右键目标功能）
