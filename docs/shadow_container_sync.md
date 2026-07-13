# 暗影空间容器同步方案

## 核心思路

用官方 `PocketDimensionContainer` + `ContainerProxy` 机制，取代当前的副本 + 事件同步方案。

## 架构

```
TheWorld
  └── hidden_container（口袋维度容器，挂载在 TheWorld 上）
         ├── container 组件 ← 所有 NPC 的装备/物品存这里
         ├── widget = "hsee"
         └── 对所有客户端可见（opencount > 1 时 SetClassifiedTarget(nil)）

hsee 实体
  └── 原本的 container 组件 → 改为 container_proxy 组件
         └── SetMaster(TheWorld:GetPocketDimensionContainer("hsee_view"))

玩家打开 hsee → 实际打开 TheWorld 上的隐藏容器
玩家关闭 hsee → 关闭隐藏容器

多玩家同时打开 → 看到同一个容器 → 天然实时同步
```

## 完整流程

### 服务端启动时

```lua
-- modmain.lua
AddPrefabPostInit("world", function(inst)
    -- 创建隐藏容器实体
    local hidden = SpawnPrefab("hsee_hidden_container")
    hidden.entity:Hide()
    TheWorld:SetPocketDimensionContainer("hsee_view", hidden)
end)
```

### 打开容器时

```lua
-- hsee 施法：
-- 1. 从目标读取装备/物品 → 填充到隐藏容器
-- 2. 玩家通过 hsee 的 container_proxy 打开隐藏容器

-- 填充（替代 SnapshotTargetItems）：
for eslot, item in pairs(target.equipslots or {}) do
    hidden_container:GiveItem(item)   -- 直接放入原物品！
end
for _, item in pairs(target.inventory.itemslots or {}) do
    hidden_container:GiveItem(item)   -- 直接放入原物品！
end
```

### 玩家操作

```
放东西进容器 → 自动给目标  → 目标收到 real 物品
取出容器里的东西 → 自动从目标拿走  → 目标失去 real 物品

因为是 real 物品，GiveItem/RemoveItem 直接操作目标 inventory
不需要副本、不需要同步、不需要刷新
```

### 关闭容器时

```lua
-- 把隐藏容器里的物品还回目标
for i = hidden.numslots, 1, -1 do
    local item = hidden:RemoveItemBySlot(i)
    target.components.inventory:GiveItem(item)
end
```

## 相比当前方案的优势

| 对比项 | 当前方案（副本） | 暗影空间方案 |
|-------|----------------|-------------|
| 同步方式 | 副本 + 事件 + _syncing 防循环 | **无副本，天然同步** |
| 堆叠处理 | 复杂（按 prefab 扣减） | GiveItem 原生支持堆叠 |
| 多玩家同时打开 | 两个玩家各看各的 | **看同一个容器** |
| 物品安全 | 副本销毁不影响目标 | 操作 real 物品，需小心 |
| 代码量 | ~300 行同步逻辑 | ~50 行 + 官方组件 |

## 关键要解决的坑

### 1. 每个目标独立容器

不能所有 NPC 共享一个容器，需要为每个目标分配独立容器 ID：

```lua
local container_id = "hsee_" .. target.GUID
TheWorld:SetPocketDimensionContainer(container_id, hidden)
```

### 2. 物品所有权

当玩家从容器拿走一个 real 物品，该物品的 `inventoryitem.owner` 会变成玩家。
当关闭容器时，如果玩家没还回去，NPC 永久丢失该物品。

**解决**：关闭时强行回收所有剩余物品还给目标。

### 3. 目标死亡/消失

目标死亡时，要决定：容器里的物品是还给目标尸体，还是让玩家保留。

**解决**：目标死亡时 onremove，把容器物品 Drop 到地上。

### 4. 隐藏容器持久化

`TheWorld:SetPocketDimensionContainer()` 不会自动保存。需要手动管理持久化。

**解决**：在 hsee 施法时重新创建/初始化。
