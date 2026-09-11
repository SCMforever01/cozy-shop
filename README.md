# Cozy Shop · 休闲烹饪游戏

一款 2D 休闲烹饪经营模拟游戏原型：经营小店、做菜服务客人、叠加「熟客 / 卫生 / 环境 / 天气」机制。

- 引擎：Godot 4（4.7.2）
- 平台：PC / 手机 / 网页（Godot 单代码库导出）
- 当前状态：第一波可玩原型已完成（核心循环 + 熟客 + 卫生 + 天气）

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

- 点「开门营业」开始一天。
- 客人进店后，点他们那一行的「接单」→ 连续点「切菜 (1/3)」等步骤按钮 → 点「上菜」。
- 耐心条空了客人会生气走人（口碑 -1）。
- 卫生值下降时点「拖地 (+30)」；卫生差会让客人更不耐烦。
- 一天约 1 分钟，结束自动结算，第二天重新开门。

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
```

## 项目结构

```
autoload/           # 全局单例（地基）
  event_bus.gd      # ① 事件总线
  game_clock.gd     # ③ 游戏时钟
  game_state.gd     # ② 单一数据源
  system_manager.gd # ④ 系统管理器
scripts/systems/    # 机制系统（每个机制一个 System）
  system.gd         # 系统基类
  shop_system.gd    # 营业状态机 + 营收
  weather_system.gd # 天气（晴/雨）
  hygiene_system.gd # 卫生（脏污 + 拖地）
  customer_system.gd# 顾客（生成/耐心/满意度/熟客）
data/catalog.gd     # ⑤ 内容数据（菜谱/天气）
resources/          # 数据 schema（Recipe/WeatherType/CustomerType）
scenes/main.gd      # 纯代码构建的 UI + 输入
```

## 如何扩展（加内容不改逻辑）

- **加新菜**：在 `data/catalog.gd` 的 `get_recipes()` 里加一行。
- **加新天气**：在 `get_weather()` 里加一条（配客流/卫生/环境系数）。
- **加新机制**：写一个 `extends System` 的类，在 `setup()` 里订阅事件，再在 `main.gd` 的 `_ready()` 里 `SystemManager.register(...)`。
