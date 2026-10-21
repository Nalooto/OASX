# OASX 资产图标来源与替换

资产页签的图标放在 `assets/images/asset_icons/<key>.png`，文件名与后端
`/stats/{script}/assets` 返回的 `key` 一一对应。缺失的 key 会自动回退到
Material 图标。

## 图标从哪来

按可靠性排序：

### 1. 游戏安装包（最权威）

MuMu 里游戏的 APK 内含：

```
assets/res/icon.idx
assets/res/icon0.wpk / icon1.wpk / icon2.wpk
```

`icon.idx` 是「哈希 → 偏移/大小」的索引，`.wpk` 是加密/压缩后的资源块，
里面没有明文字段名，直接用 md5/sha1 匹配 `icon_jinbi` 等名字都匹配不上。
要完整解包需要 NeoX 的 WPK 工具和对应版本的密钥，成本较高。

好在游戏配置里能拿到每个资产的图标名（`com.data.cdata.currency` 的 `icon` 字段），
例如：

| 资产 | 游戏图标名 |
|---|---|
| 金币 | `icon_jinbi` |
| 体力 | `icon_tili` |
| 勾玉 | `icon_gouyu` |
| 神秘的符咒 | `icon_choukaquan` |
| 御行达摩 | `damobudaoweng_hei` |
| 现世符咒 | `icon_choukaquan03` |
| 大蛇的逆鳞 | `icon_shelin_01` |
| 逢魔之魂 | `icon_shoulingsuipian` |
| 御灵境之钥 | `icon_yulingquan` |
| 百鬼夜行门票 | `icon_baiguiyexingmenpiao` |
| 荣誉 | `icon_rongyu` |
| 勋章 | `icon_doufajifen` |
| 功勋 | `icon_liaozha` |
| 绘卷碎片 | `pic_suipian` / `pic_suipian2` / `pic_suipian3` |

以后拿到 WPK 解包工具时，按这些名字导出即可。

### 2. 藏宝阁 H5「资产」页（当前采用）

参考页 <https://yys.cbg.163.com/cgi/mweb/equip/88/202610142101616-88-XVUHF3DUQYCUH>
的「资产」页签，每个条目的图标是 CSS `background-image`：

- 内联 `data:image/png;base64,...`
- 或外链 `dist/icon-asset-<id>-<hash>.png`

这些就是游戏原图标（80×80 PNG，带透明通道）。仓库内提供了抓取脚本：

```bash
python tools/fetch_cbg_icons.py \
  --url "https://yys.cbg.163.com/cgi/mweb/equip/88/202610142101616-88-XVUHF3DUQYCUH" \
  --out assets/images/asset_icons_raw
```

脚本用 Chrome DevTools Protocol 打开页面、点「资产」，把图标和同行文字配对后保存。
依赖 `pip install websockets` 和本机 Chrome。

### 3. 游戏内截图（补齐缺失项）

藏宝阁 H5 的资产页只展示部分货币，御行达摩/碎片、功勋、绘卷碎片不在这里。
这三种可以直接在游戏里截图（1280×720 或更高），裁成 80×80 透明/纯色背景 PNG：

- 御行达摩：式神 → 素材/达摩列表
- 功勋：阴阳寮商店 / 斗技商店
- 绘卷碎片：追忆绘卷活动界面

## 当前覆盖情况

已放入 `assets/images/asset_icons/`（来自藏宝阁 H5）：

`gold` `jade` `ap` `soul_jade` `mystery_amulet` `real_amulet` `oro_scale`
`demon_soul` `yuling_key` `honor` `medal` `hyakki_ticket`

仍回退 Material 图标：

`black_daruma` `black_daruma_shard` `contrib`
`scroll_shard_large` `scroll_shard_medium` `scroll_shard_small`

补图标只需把对应文件按 key 命名放进 `assets/images/asset_icons/`，无需改代码
（目录已在 `pubspec.yaml` 声明）。

## 注意

- 图标版权归网易所有，仅用于本地个人工具；不要再分发到公开仓库/安装包之外。
- 藏宝阁页面结构可能变化，`tools/fetch_cbg_icons.py` 里的选择器（按文字「资产」点击）
  和 `getComputedStyle(...).backgroundImage` 的取法需要随页面更新调整。
