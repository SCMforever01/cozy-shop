# 交接文档（HANDOFF）

> 供其他 agent / 开发者接手本项目。最后更新：2026-10-15。

## 1. 仓库与路径

- **GitHub 仓库**：https://github.com/SCMforever01/cozy-shop
- **本地项目路径**：`/home/mi/workstation/game/cozy-shop/`
- **分支**：`main`（所有改动已推送）
- **服务器**：`10.224.120.101`，用户 `mi`，游戏服务跑在 **8090** 端口（`python3 serve.py 8090`，PID 2128513）

## 2. 如何运行 / 玩

服务器无显示器，用 SSH 隧道从本地浏览器玩：

```bash
# 本地电脑执行（保持终端别关）
ssh -N -L 8081:localhost:8090 mi@10.224.120.101
# 浏览器打开
http://localhost:8081/
```

## 3. 技术栈

- **引擎**：Godot 4.7.2（`~/.local/bin/godot`）
- **语言**：GDScript
- **导出**：网页版（`build/web/`），PC/手机可原生导出
- **网页导出命令**：
```bash
cd /home/mi/workstation/game/cozy-shop
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
python3 serve.py 8090
```

## 4. 架构（事件驱动 + 数据驱动）

**核心原则：加机制 = 加一个 System + 订阅事件；加内容 = 加数据，不动逻辑。**

- **autoload/**：`event_bus.gd`（事件总线）、`game_clock.gd`（游戏时钟）、`game_state.gd`（单一数据源）、`system_manager.gd`（系统注册）
- **scripts/systems/**：每个机制一个 System（shop/weather/hygiene/customer/event/season/save/language）
- **data/catalog.gd**：菜谱/天气/升级数据（加菜/天气只改这里）
- **data/translations.gd**：中英翻译表
- **resources/**：Recipe/WeatherType/CustomerType 的 schema
- **scenes/main.gd**：纯代码构建 UI + 渲染 + 交互（Node2D + `_draw()`）

## 5. 关键坑（必读）

1. **字体**：Godot 网页端**不支持 CFF（.otf）和变量字体**，必须用**静态 TrueType（.ttf）**。用 `assets/fonts/NotoSansSC-Static.ttf`。用 fontTools 从 NotoSansSC[wght].ttf 转的静态版。
2. **i18n 兜底**：Godot 翻译有「en」兜底 locale，中文会回退成英文。解法：加一个**中文恒等翻译**（中文→中文），见 `language_system.gd`。
3. **GDScript lambda 按值捕获**：计数用 Array/Dictionary（引用类型），别用 int 变量。
4. **`:=` 类型推断**：从 Dictionary/Array 取值无法推断类型，用显式 `var x: Type =`。
5. **pkill 自匹配**：`pkill -f "serve.py 8090"` 会匹配当前 shell 自己。用 `pkill -f "serve[.]py"`。
6. **字体诊断方法**：加 ASCII-only 的 `print` 或 Label，绕过中文字体问题。
7. **Kenney 图集裁格**：图块 16px、**间隔 1px（pitch=17）**，按 `crop(c*17, r*17, c*17+16, r*17+16)` 取，别按 16 的倍数切（第一版贴图错位就是这个原因）。
8. **顾客排版**：顾客行距 82px，精灵图只能按 **3 倍（48px）** 画（整数倍缩放才清晰），名牌/耐心条的位置随 `sprite_mode` 变化（贴图模式在头顶空隙内，代码模式在圆上方），改行距或精灵尺寸时两处 offset 要一起调。
9. **多 tile 家具**：Roguelike 系列家具是跨格大件（床/桌 2x2 起），单格切出来是碎片；背景里别硬拼，用单格装饰（窗/盆栽/相框）最稳。
10. **wasm 模零陷阱**：`randi() % arr.size()` 在空数组时 x86 上炸/网页版直接 RuntimeError 崩游戏——`get_unlocked_recipes` 在口碑为负时会返回空（v1 就有此雷，v2 已在 `_random_recipe` 加兜底），任何 `%` 变量除数都要防 0。

## 6. 当前状态

### ✅ 已完成（游戏功能完整，可玩）

| 功能 | 说明 |
|---|---|
| 核心循环 | 客人进店→点单→烹饪（锅里变熟冒蒸汽）→上菜→结账 |
| 熟客系统 | 老张/小王/李姐，关系等级、生日、带朋友、送礼、流失可挽回 |
| 卫生/环境 | 脏污累积+拖地，环境影响满意度 |
| 天气 | 晴/阴/雨/暴雨/台风 + 天气预报 + 台风决策 |
| 随机事件 | 美食评论家/客流高峰/卫生检查/设备故障/节日促销 |
| 难度曲线 | 口碑解锁 10 道菜、客流随天数递增 |
| 经济 | 设备升级（拖把/食材/装修）、食材采购（保质期） |
| 季节 | 四季轮替，应季菜品加价+点单翻倍 |
| 存档 | 自动存档/读档/重置（web 走 IndexedDB） |
| 新手引导 | 首次游戏 6 步引导卡片 |
| i18n | 中英双语切换（右下角按钮） |
| 美术 | 食物贴图（10 道菜逐一视觉核对）+ 顾客像素角色 + 店铺背景 + 「像素/代码」风格切换 |

### 🚧 进行中：美术完善

- **当前状态**（2026-10-15 更新）：食物贴图已全部重新精确裁剪并视觉核对（旧版 18×18 贴图全是错位碎片，已全部替换）；顾客角色（3 熟客 + 评论家 + 6 路人）已接像素头像；店铺背景（墙/窗/地板/厨房区/盆栽）已接入。全部改动经网页导出 + 浏览器截图验证（排队/接单/做菜全流程）。
- **剩余**：更多路人 sprite 变体、天气主题背景（雨天/台风氛围）、厨房灶台等大件家具（多 tile 拼接，见坑 9）。
- **素材来源**（Kenney CC0，重新下载，原 `/tmp/opencode/assets/` 已被 /tmp 清理丢失）：
  - 食物：[pixel-platformer-food-expansion](https://kenney.nl/assets/pixel-platformer-food-expansion) + [roguelike-rpg-pack](https://kenney.nl/assets/roguelike-rpg-pack)
  - 角色：[roguelike-characters](https://kenney.nl/assets/roguelike-characters)
  - 背景：[roguelike-rpg-pack](https://kenney.nl/assets/roguelike-rpg-pack)（砖墙/石地/窗）+ [roguelike-indoors](https://kenney.nl/assets/roguelike-indoors)（盆栽/相框）
- **贴图映射**（图集内坐标，`(列,行)`，16px 图块 + 1px 间隔）：

| 菜品 | 来源 | 坐标 | 备注 |
|---|---|---|---|
| burger | pixel-food | tile_0090 | |
| sandwich | pixel-food | tile_0093 | 长三明治的左段（0093-0095 是一整条） |
| pizza | pixel-food | tile_0106 | 带料披萨角 |
| cake | pixel-food | tile_0038 | 千层蛋糕切块 |
| ice_cream | pixel-food | tile_0108 | 撒糖针旋风甜筒 |
| coffee | pixel-food | tile_0089 | 白色马克杯 |
| milk_tea | pixel-food | tile_0083 | 杯装，蓝色液体已重着色为奶茶色 |
| juice | pixel-food | tile_0082 | 高脚杯，蓝色液体已重着色为橙色 |
| salad | roguelike-rpg | (55,17) | 碗装沙拉，裁透明边后放大到 16×16 |
| soup | roguelike-rpg | (56,16) | 汤碗，同上 |

| 角色 | 来源 | 坐标 |
|---|---|---|
| 老张 laozhang | roguelike-characters | (1,6) 戴帽络腮胡 |
| 小王 xiaowang | roguelike-characters | (1,9) 黑发青年 |
| 李姐 lijie | roguelike-characters | (1,7) 长发橙裙 |
| 评论家 critic | roguelike-characters | (1,11) 白袍 |
| 路人 g0~g5 | roguelike-characters | (0,5) (0,7) (0,8) (0,9) (0,10) (1,10) |

背景 `shop_bg.png`（1280×720）构成：墙 (9,2)/(9,3)、地板 (7,2)/(7,3)、厨房区 (6,2)/(6,3)、窗 (40,4)、盆栽/相框来自 roguelike-indoors (16,0)/(17,0)/(18,0)。

### 🚧 进行中：v2 玩法改造（压力 → 真实 → 决策）

> 用户实测反馈 v1「点点点、机械、不真实」，判决与改造方案见飞书 **04.5 · v2 交互设计**。验收标准从此是「好玩」，用户实玩打回则不进下一阶段。

- **P1 压力感 ✅ 已完成**：做菜改为工位流水线（备菜台/灶台×2/装盘台自动计时，点菜推进一步）；灶台做好不及时取走糊锅（食材报废+客人气走+台面清理 3 秒）；拖地改为 3 秒占用动作（期间做不了菜）；地面污渍随卫生可见。经两轮难度调参（营业日 60 秒→2 分钟、客流 0.22→0.14/分、糊锅宽限 10 秒）。
- **P2 真实感 ✅ 已完成**：3 张餐桌落座（满座门口排队，10 秒没座走人小扣口碑）；上菜后坐下用餐 5~8 秒；吃完留脏盘（点桌收盘才能接待下一位，脏桌加速脏污）；装修每级看得见（Lv1 桌布+绿植、Lv2 挂画、Lv3 灯光氛围）。测试 `test_seats.gd` 9 例。
- **P3 决策感 ✅ 已完成**：升级扩到 5 选（拖把/快灶台/座位扩建/优质食材/装修，钱只够买一部分）；食材跨天保存 + 每天结束 20% 过期 + 大份囤货更划算（囤多浪费、囤少断货）；天气溢价进 HUD（雨+20%/暴雨+35%/台风+50%）；台风天二选一「开门搏一把 vs 台风歇业保库存」（歇业不过期），台风权重提到 10% 让玩家真能遇到。测试 `test_shop.gd` 10 例。
- **音效 + 手机适配 ✅ 已完成**：BGM/雨声/煎炒声循环（自合成 wav）+ 12 个事件音效（Kenney CC0：interface-sounds / digital-audio / music-jingles）+ 声音开关按钮；手机端靠 `stretch/mode=canvas_items + aspect=keep` 等比缩放（刘海安全），小字号上调、点击区 ≥44px。测试 `test_audio.gd` 4 例。合成脚本 `make_audio.py`（会话工具目录，BGM 为 Cmaj7-Am7-Fmaj7-G6 80BPM 24 秒循环）。

### ⬜ 待做

- 美术完善（更多路人 sprite、天气氛围背景、厨房大件家具）
- 数值平衡（需实测反馈）
- 更多内容（菜/客人/熟客剧情，数据驱动很快）

## 7. 文档链接

### 飞书设计文档（根：🍳 休闲烹饪游戏 · 设计文档）
- 根目录：https://www.feishu.cn/wiki/V6CPwtMZEigilOkBx4fcOWZCnNd
- 01 项目愿景与乐趣论
- 02 技术选型与工具链
- 03 系统架构设计
- 04 核心玩法设计（含 04.1 核心循环 / 04.2 模拟模型 / 04.3 熟客系统 / 04.4 天气与随机事件）
- 05 原型范围与路线图
- 实现计划 · 第一波可玩原型：https://www.feishu.cn/wiki/FfatwsokaiHuXdkoTXTceMsCntB
- 后续开发规划（Roadmap）：https://www.feishu.cn/wiki/XEAUwujlCiTYXqkbwJgcbzHfnfd
- **04.5 · v2 交互设计（压力·真实·决策）**：https://www.feishu.cn/wiki/O2VEwKMuriVrMlkIoMRchYLrnyd

### 本地文档
- `README.md`：使用说明、项目结构、如何扩展
- `docs/IMPLEMENTATION_PLAN.md`：实现计划
- `docs/ROADMAP.md`：后续开发规划
- `docs/HANDOFF.md`：本文档

## 8. 测试

```bash
cd /home/mi/workstation/game/cozy-shop
# 单元测试（headless，无需图形界面）
godot --headless --script res://tests/test_event_bus.gd
godot --headless --script res://tests/test_satisfaction.gd
godot --headless --script res://tests/test_font.gd
godot --headless --script res://tests/test_kitchen.gd   # v2 工位/糊锅/拖地
godot --headless --script res://tests/test_seats.gd    # v2 落座/用餐/留盘
godot --headless --script res://tests/test_shop.gd     # v2 采购/过期/升级
godot --headless --script res://tests/test_audio.gd    # v2 音频加载/循环/开关
# 冒烟测试（自动演示跑 N 帧）
godot --headless --quit-after 20000 -- --autoplay
```

改渲染/贴图后建议做**网页视觉验证**：导出 Web 构建 → `python3 serve.py <端口>` → 用 Playwright（channel: chrome）截图走一遍「跳过引导 → 采购 → 开门 → 接单 → 做菜」，坐标参考：跳过 (459,469)、采购 (155,546)、开门 (115,676)、第一位客人 (250,140)、第一口锅 (1070,160)。

> 测试坑：`--script` 模式里 `quit()` 写在 `_initialize` 时，`add_child` 入树节点的 `_ready` 不会触发（首帧没跑就退出了），测试里要**手动调 `_ready()`**。

## 9. Git 提交规范

Conventional Commit：`feat(scope): 描述`。已完成 22+ commit，见 `git log --oneline`。
