# 容器与 UI 设计四方对比：官方 cookbook / 我们 hslot / 简存 / 翻页 MOD

> 调研日期：2026-11-21
> 基于官方源码版本 `0000373632313732`（见 `参考代码/官方源码/.source_manifest.json`）
> 所有行号对应 `参考代码/官方源码/` 与下列参考 MOD 的磁盘实读。

## 0. 一句话结论

| 方案 | 本质 | 突破 20 格的方式 | 适用场景 |
|------|------|------------------|----------|
| 官方 cookbook | **数据展示 UI，不是容器** | 不涉及格子 | 食谱/图鉴等纯展示 |
| 我们 hslot | 官方真容器 + 换显示层 | 静态抬 `MAXITEMSLOTS=160` | 需要原版交互正确性的大容量容器 |
| 简存 | 假容器 + 假物品 | 假数据不占 netvar | 跨箱聚合、种类压缩、超大规模 |
| 翻页 MOD | 官方真容器 + 数据层翻页 | 动态扩池 + 轮转 slots | 保留官方网格但要多页（不推荐） |

---

## 1. 官方 cookbook：它根本不是容器

最容易踩的认知坑。cookbook 打开的页面与箱子/背包的 `container` 组件**完全无关**。

### 1.1 打开链路

```
prefabs/cookbook.lua:6-8   simplebook.onreadfn = OnReadBook → doer:ShowPopUp(POPUPS.COOKBOOK, true)
  └─ screens/cookbookpopupscreen.lua:7   CookbookPopupScreen = Class(Screen, ...)  ← 前端 Screen，非 container screen
       ├─ :11-19   全屏黑色遮罩 ImageButton，点击 PopScreen
       ├─ :21-25   root(SetScaleMode PROPORTIONAL, 锚点 MIDDLE)
       ├─ :27      root:AddChild(CookbookWidget(owner))
       └─ :31      SetAutopaused(true)
            └─ widgets/redux/cookbookwidget.lua:18-97
                 ├─ :36-42  tab 数据：cookpot / portablecookpot / 可选 mod
                 ├─ :57-73  切 tab = Unselect 旧 → Kill 旧 panel → AddChild 新 page
                 └─ :94     初始 page = CrockpotPage
```

`containers.lua` 中 grep `cookbook` **零匹配**——没有 `params.cookbook`，从不 `AddComponent("container")`。

### 1.2 页面 UI（CrockpotPage，`widgets/redux/cookbookpage_crockpot.lua`）

它**不做翻页**，而是三层叠加：tab 分类 + 虚拟滚动网格 + filter/sort spinner。

- 数据准备 `:490-538`：`TheCookbook.preparedfoods` + `cooking.cookbook_recipes[category]` → `all_recipes`（unlocked/has_eaten/recipes/food_tex），排序后写 `data.index`
- 单元格 `ScrollWidgetsCtor :407-454`：ImageButton + `ongainfocusfn → OnWidgetFocus`，点击更新右侧详情面板
- 绑定 `ScrollWidgetSetData :456-488`：unlocked 决定 known/unknown 纹理
- **滚动核心** `:540-553`：

```lua
grid = TEMPLATES.ScrollingGrid({}, {
    widget_width = row_w + row_spacing,   -- 73+5
    widget_height = row_h + row_spacing,
    force_peek = true, num_visible_rows = 5, num_columns = 5,
    item_ctor_fn = ScrollWidgetsCtor, apply_fn = ScrollWidgetSetData,
    scrollbar_offset = 20, scrollbar_height_offset = -60,
})
```

`TEMPLATES.ScrollingGrid`（`widgets/redux/templates.lua:1968`）：`ScrollWidgetsCtor` 建 `num_visible_rows+2` 行格子，`Grid:FillGrid` 摆位，`TrueScrollList` 裁剪滚动。**这是全游戏 UI 的滚动基座。**

- 筛选 `ApplyFilters :611-631`（foodtype）+ 排序 `ApplySort :596-609` → `SetItemsData(filtered)` `:607`
- 状态外置：filter/tab/selected/newfoods 全存全局 `TheCookbook`，Screen 销毁时 `Save()`（`cookbookpopupscreen.lua:34-43`）

**关键**：全程无 netvar、无 dirty、无 RPC，纯本地数据展示。

---

## 2. 官方真容器：服务端权威 + 客户端镜像

### 2.1 三层结构

| 层 | 文件 | 职责 |
|----|------|------|
| 服务端 Component | `components/container.lua` | `slots` 持有真 item 实体；`GiveItem :447` / `RemoveItemBySlot :569`；`openlist/opencount` |
| 客户端 Replica | `components/container_replica.lua` | 统一门面，不存真物品；`GetItems :442` 按权威/镜像分流 |
| netvar 载体 | `prefabs/container_classified.lua` | `_itemspool` 池（net_entity）+ `_items`；`InitializeSlots` 从池分配 |

### 2.2 net_entity 池——所有扩格方案的共同约束

`container_classified.lua:1050-1059`：

```lua
inst._items = {}; inst._itemspool = {}
for i = 1, containers.MAXITEMSLOTS do
    table.insert(inst._itemspool, net_entity(inst.GUID,
        "container._items["..tostring(i).."]", "items["..tostring(i).."]dirty"))
end
```

- `containers.MAXITEMSLOTS` 官方默认 **20**，在 `containers.lua` 末尾计算
- 池在 `entity:SetPristine()` **之前**一次性预建；事后 `AddPrefabPostInit` 补池**无效**（客户端不建对应 netvar）
- 不扩池就 `InitializeSlots(160)` → 取到第 21 格时池空 → `table.remove(空表,1)` 返回 0 个值 → `wrong number of arguments to 'insert'`（报错文本极具误导性）

### 2.3 打开链路（真容器）

1. 服务端 `Container:Open(doer)` `container.lua:617-666` → `replica.container:AddOpener(doer)` :634 → `doer.HUD:OpenContainer` :637
2. `container_replica.lua:191-206 AddOpener` → `SetClassifiedTarget(opener)` + spawn `container_opener` —— 把 classified 网络归属重定向给打开者
3. 客户端 `AttachOpener :168-179` → `OpenContainer :137-151` → HUD 建 `ContainerWidget:Open`
4. `widgets/containerwidget.lua:25-191`：读 `GetWidget()` 配置 → 按 `slotpos` 逐格 `InvSlot(i, atlas, image, owner, replica.container)` :137-142 → `self.inv[i] = AddChild(slot)` :156 → `SetPosition(v)` :158
5. `Refresh :206-237`：仅当 item 实体变化才新建 `ItemTile`，否则 `tile:Refresh()`（tile 复用）

### 2.4 一个致命坑：不能隐藏 ContainerWidget

`components/inventory_replica.lua:349 GetOpenContainers()` 靠 `widget.inst.entity:IsVisible()` 判断容器是否打开。若 `self:Hide()` 官方 ContainerWidget：

- Shift+左键快速转移（`widgets/invslot.lua:301 InvSlot:TradeItem`）拿不到目标容器
- 制作时 `inventory:Has(prefab,n,true)` 不算容器里的材料 → 材料不识别

正解：**widget 保持可见，只藏内容**（bgimage/bganim/button/inv），见我们 `modmain.lua:1686-1706`。

---

## 3. 我们 hslot：官方真容器 + 滚动列表换皮

### 3.1 容器侧（`scripts/prefabs/hslot_container.lua`）

- `MakePocketContainer` 工厂造真容器，`WidgetSetup(widget_name)`，容量 160 格
- `:39` `containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, 160)` —— 启动时静态抬池（两端都执行）
- 四色月眼共用 `HSLOT_TYPE` → 借官方 `Container:Open` 里"同 type 自动关闭"实现互斥
- `skipautoclose=true` + `onanyopenfn/onanyclosefn` 管理 `SetClassifiedTarget`

### 3.2 UI 侧（`scripts/widgets/hslot_vault_list.lua`，1215 行）

- 劫持 `AddClassPostConstruct("widgets/containerwidget")` 的 `Open`（`modmain.lua:1661`），藏官方内容、挂 `HslotVaultList`
- `:528` `TEMPLATES.ScrollingGrid` —— 与官方 cookbook 完全同源的滚动基座
- **格子用官方 `InvSlot` 而非 ItemTile**（`:308`）：官方 ItemTile 在 `itemtile.lua:94` 会索引 nil 崩；InvSlot 的 `SetTile(nil)` 安全，点击/右键/拖入全走原版逻辑，**零 RPC**

```lua
local slot = InvSlot(1, "images/hud.xml", "inv_slot.tex", context.owner, context.container)
cell.slot.num = data.slot   -- 空格也留槽位号，才能往里拖
cell.slot:SetTile(ItemTile(item))
```

- 尺寸完全照搬简存 terminalwidget（panel 680×420、gridroot scale 0.6、15 列×6 行）
- "冻结布局"：`_view_slots` 只在打开/切筛选/整理时重排，中途取物不跳动
- `OnUpdate :926` 用 `ContainerSignature()` 0.3s 轮询兜底合并堆叠（官方合并堆叠不推 itemget）
- `OnDestroy :1189` 清理全部事件/定时器/相机 hook

### 3.3 取舍总结

- ✅ 交互正确性最稳：Shift 转移、制作材料识别、武器耐久同步全部免费
- ⚠️ 容量写死 160，改大需同步 `MAXITEMSLOTS` 与 `HSLOT_VAULT_SLOTS` 两处
- ⚠️ 自研交互兼容层约 1200 行（但已落地稳定）

---

## 4. 简存：假容器 + 假物品

MOD `简易存储 3383078008`，源码在 `C:/Users/hehu/Documents/GitHub/DST-learn/示例/简易存储 3383078008`。

### 4.1 "无限"的真相

**不是单容器无限格**：终端把附近多个真实箱子（`CanTerminalConnect` 只接 `type=="chest"`，`hook.lua:16-26`）聚合成一个大视图，按 `prefab+skin` 分组压缩。容量随箱子数线性增长。

### 4.2 假容器 / 假物品

- `fakecontainer.lua:27 FakeContainer`：构造 `replica.container = {numslots, slots}`，slots 里放 FakeItem；用 `setmetatable` 伪装官方 replica 接口
  - slots 用字符串 `"nil"` 占位（json 数组里 nil 会截断），客户端换回真 nil
  - `IsFake = true` 全局标记 + `container_meta`/`inst_meta` 桩方法
- `fakeitem.lua:7 FakeItem`：把渲染所需字段（GUID/prefab/atlas/image/stacksize/耐久%/tags/皮肤）拍平成表
  - `maxsize==math.huge` 序列化成字符串 `"inf"`，客户端还原（json 无法表达 inf）—— 无限堆叠关键技巧
  - `tags` 来自 `tags_backup`（hook `AddTag/RemoveTag` 备份）
- 客户端 `ModifyFakeItem :238` 用 metatable 补齐官方 ItemTile/Tooltip 会调用的方法

### 4.3 数据同步

- 服务端 `hook.lua:572 RemoteOpen`：`FakeContainer` → `json.encode` → `TheSim:ZipAndEncodeString` → `SendModRPCToClient(OpenFakeContainer)`
- **从不调用官方 `container:Open()`**，只登记 `fake_openlist` + 改写 `IsOpenedBy`（"假打开"）
- 13 个 ModRPC（`main/rpc.lua`）：客户端只传数字 GUID，服务端 `Ents[GUID]` 还原真实体后翻译成官方方法调用
- 制作系统兼容要额外 hook `inventory_replica:Has`、`builder:EvaluateTechTrees`、`opencontainers` 系列（`hook.lua:342-460`）

### 4.4 UI 双压缩

- 数据层：`terminalwidget.lua:568-595` 同 prefab+skin 合成一个 tile，`overridequantity=总数`
- 控件层：`terminalscrolllist.lua:10` **直接拷官方 TrueScrollList 源码**（构造签名一字不差），固定 `(6+2)×15=120` 个 widget 复用，只刷新窗口内数据
- 所以上千物品也只占 120 控件

### 4.5 代价

13+ RPC 胶水层、全量快照重序列化、单包大小上限（有解析失败弹窗 `ui.lua:198-229`）、皮肤/耐久字段手工镜像（游戏新增字段可能漏同步）。

---

## 5. 翻页 MOD（workshop-936440913）——"在官方容器上加翻页"的实测

### 5.1 和我们同源的扩池

- `modmain.lua:1-2,34` + `config.lua`：`containers.MAXITEMSLOTS = CustomPageCount * MaxContainerSlotsCount`（默认 8×80=640，config 实际 100×24=2400）
- `container_classified_patch.lua:653-704 modContainerClassified`：hook `InitializeSlots`
  - `:665` `slots = numslots * parent.components.pageable.pagecount`
  - `:693` `table.insert(inst._items, table.remove(inst._itemspool, 1))` —— **和我们静态抬池是同一机制，只是运行时动态取**
  - 新建 `net_byte("pagecount")` + `net_bool("ispaging")` 同步页数/翻页锁

### 5.2 翻页 = 服务端真实搬物品

`pageable.lua:145-204 Move()`：循环移位 `thecontainer.slots` + 用 `v:set_local(itemvalues[k]); v:set(itemvalues[k])` 改写 netvar 值，0.15s ispaging 锁防连点。

UI：`modmain.lua:43-66 AddClassPostConstruct("widgets/containerwidget")` 挂 `PageWidget`（左右箭头，`pagewidget.lua:37-44`），**保留官方网格布局**。

### 5.3 为什么不建议采用

- 翻页搬运真实物品 + 自建同步层，多人操作易竞态
- 打了 700+ 行 classified 补丁（几乎整份复制官方函数），游戏升级极易失配
- 容量上限 = MAXITEMSLOTS（2400），每个 classified 实例背 2400 个 net_entity，内存/同步开销大
- 反观我们的 ScrollingGrid 滚动列表：只改显示窗口、**不动物品**、代码更少、无竞态

**结论**：官方容器加滚动/翻页技术可行，但我们的方案已是"真容器 + 官方同款滚动基座"的最优解，不需要换路线。

---

## 6. 官方源码更新（2026-11-21）

参照 `参考代码/参考代码说明.md`，本地「官方源码」原已过时（`container.lua` 本地 55920B vs zip 54269B）。已用 `参考代码/update_official_source.py` 更新并归入专家技能三副本。

### 6.1 容器/格子相关文件的实际变动（旧 → 新）

| 文件 | 旧行数 | 新行数 | 变动行 | 说明 |
|------|--------|--------|--------|------|
| `components/container.lua` | 1651 | 1651 | **0** | 无变动 |
| `components/container_replica.lua` | 647 | 647 | **0** | 无变动 |
| `prefabs/container_classified.lua` | — | — | **0** | 无变动 |
| `widgets/containerwidget.lua` | 344 | 344 | **0** | 无变动 |
| `widgets/itemtile.lua` | 976 | 976 | **0** | 无变动 |
| `widgets/invslot.lua` | 470 | 470 | **0** | 无变动 |
| `widgets/itemslot.lua` | 141 | 141 | **0** | 无变动 |
| `components/inventory.lua` | 2755 | 2755 | **0** | 无变动 |
| `components/inventory_replica.lua` | 610 | 610 | **0** | 无变动 |
| `widgets/inventorybar.lua` | 1578 | 1578 | **0** | 无变动 |
| `widgets/redux/templates.lua` | 2157 | 2164 | 17 | 仅 `GetBuildString()` 版本号缓存改写；**ScrollingGrid 未变** |
| `containers.lua` | 2504 | 2500 | 56 | 仅遗迹 keystone 建造容器相关；**params.hslot 等未受影响** |

### 6.2 结论

**容器与格子核心 API 全部零变动**——我们 hslot 依赖的 `MAXITEMSLOTS` 池机制、`InvSlot`、`ScrollingGrid`、`GetOpenContainers()` 判定逻辑在新版源码中完全一致。本次源码更新**不需要改任何 MOD 代码**。

变动的两处都不在我们依赖的路径上：
- `templates.lua`：只改 `TEMPLATES.GetBuildString()`（加 `VERSION_CACHE`），滚动网格 `ScrollingGrid`（现 `:1968`）逻辑未动
- `containers.lua`：只改 `socket_keystone_construction_container` 并新增 `socket_bothgatekeys_construction_container`，属于遗迹机关容器，与口袋空间无关

### 6.3 维护提示

Steam 更新游戏后重跑：

```bash
python 参考代码/update_official_source.py --update
```

脚本只覆盖变动的 `.lua`、保留本地 `fx/*.tex` 等非 lua 资源、自动备份到 `官方源码_backup_<时间戳>/`、写 `.source_manifest.json` 基线、失败回滚。
