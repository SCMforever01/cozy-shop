# Cozy Shop · 休闲烹饪游戏

一款 2D 休闲烹饪经营模拟游戏：经营小店、做菜服务客人、叠加「熟客 / 卫生 / 环境 / 天气 / 季节 / 随机事件」机制。

- 引擎：Godot 4（4.7.2）
- 平台：PC / 手机 / 网页（Godot 单代码库导出）
- 当前状态：v2 玩法已完成（工位流水线做菜 + 落座用餐 + 采购囤货决策 + 音效）

## 如何运行（玩）

### 方式 A：网页版（远程/无显示器推荐）

先导出一次，再起本地服务器：

```bash
mkdir -p build/web
godot --headless --export-release "Web" build/web/index.html
python3 serve.py 8090   # 然后在浏览器打开 http://<服务器IP>:8090/
```

### 方式 B：桌面窗口版（需要有显示器）

```bash
./run.sh
# 或者直接
godot
```

- 点「开门营业」开始一天（一天约 2 分钟）。
- 客人进店落座（满座门口排队）→ 点客人「接单」→ 点厨房里的菜上工位，步骤自动计时。
- 灶台做好趁热取走，晚了糊锅（食材报废 + 客人气走）；做完变发光盘子，点它「上菜」收钱。
- 客人吃完留脏盘，点桌子收桌才能接待下一位。
- 地面变脏点「拖地」（3 秒动作，期间做不了菜）；脏店客人没耐心。
- 耐心条空了客人会生气走人（口碑 -1）；开店前记得采购食材、按需升级设备。

### 演示模式（自动玩）

```bash
./run.sh -- --autoplay
# 或
godot -- --autoplay
```

自动开门、自动做菜上菜，用于快速看效果 / 冒烟测试。

## 运行测试（headless，无需图形界面）

```bash
godot --headless --script res://tests/test_event_bus.gd       # 事件总线单测
godot --headless --script res://tests/test_satisfaction.gd    # 满意度单测
godot --headless --script res://tests/test_kitchen.gd         # 工位/糊锅/拖地单测
godot --headless --script res://tests/test_seats.gd           # 落座/用餐/留盘单测
godot --headless --script res://tests/test_shop.gd            # 采购/过期/升级单测
godot --headless --script res://tests/test_audio.gd           # 音频加载/循环/开关单测
godot --headless --script res://tests/test_catalog.gd         # 内容数据完整性单测
godot --headless --script res://tests/test_save.gd            # 存档序列化单测
```

## 项目结构

```
autoload/           # 全局单例（地基）
  event_bus.gd      # ① 事件总线
  game_clock.gd     # ③ 游戏时钟（speed_multiplier 同步缩放两类计时）
  game_state.gd     # ② 单一数据源（含状态查询辅助）
  system_manager.gd # ④ 系统管理器
scripts/systems/    # 机制系统（每个机制一个 System）
  system.gd         # 系统基类
  shop_system.gd    # 营业状态机 + 营收 + 升级/采购
  kitchen_system.gd # 厨房工位流水线 + 糊锅
  customer_system.gd# 顾客（生成/耐心/满意度/熟客/落座用餐）
  hygiene_system.gd # 卫生（脏污 + 拖地动作）
  weather_system.gd # 天气（晴/阴/雨/暴雨/台风 + 溢价）
  event_system.gd   # 随机事件调度
  season_system.gd  # 季节轮替
  save_system.gd    # 存档（纯序列化函数 + 接线）
  language_system.gd# 中英双语
scripts/ui/         # 渲染层（每层一个视图，纯绘制 + 动画）
  game_layout.gd    # 布局几何唯一来源（绘制与命中检测共用）
  ui_view.gd        # 视图基类（字体/按钮/条形/食物等共享绘制）
  shop_view.gd      # 地板/背景/污渍/装修/餐桌/顾客/气泡
  kitchen_view.gd   # 厨房工位卡片 + 待处理菜
  hud_view.gd       # 顶部 HUD
  controls_view.gd  # 底部按钮/升级/采购
  fx_view.gd        # 飘字/雨滴/事件提示（TOASTS 数据表）
  tutorial_view.gd  # 新手引导遮罩
  audio_controller.gd # 事件→音效映射（SFX_EVENTS 数据表）+ 氛围声
scripts/audio_manager.gd # 音频底层（SFX 池 + BGM/雨/煎炒循环）
scripts/auto_play.gd# 自动演示控制器（--autoplay）
tools/balance_sim.gd # 平衡模拟器（bot 手速档位跑 N 天，输出数值统计）
data/catalog.gd     # ⑤ 内容数据（菜谱/天气/升级，带缓存）
data/translations.gd# 中英翻译表
resources/          # 数据 schema（Recipe/WeatherType/CustomerType）
scenes/main.gd      # 装配层：注册系统 + 组装视图 + 路由输入
```

## 如何扩展（加内容不改逻辑）

- **加新菜**：在 `data/catalog.gd` 的 `get_recipes()` 里加一行（含工位步骤与兜底颜色）。
- **加新天气**：在 `get_weather()` 里加一条（配客流/卫生/环境/溢价系数）。
- **加新事件提示**：在 `scripts/ui/fx_view.gd` 的 `TOASTS` 表里加一行。
- **加新音效**：在 `scripts/ui/audio_controller.gd` 的 `SFX_EVENTS` 表里加一行。
- **加新机制**：写一个 `extends System` 的类，在 `setup()` 里订阅事件，再在 `main.gd` 的 `_register_systems()` 里注册。
- **改界面布局**：只改 `scripts/ui/game_layout.gd`（绘制和点击自动同步）。
