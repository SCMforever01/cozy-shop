# 交接文档（HANDOFF）

> 供其他 agent / 开发者接手本项目。最后更新：2026-09-11。

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
| 美术（部分） | 10 道菜接入真实像素食物贴图 + 「像素/代码」风格切换 |

### 🚧 进行中：美术

- **当前状态**：食物图标已接真实像素图（Kenney CC0），顾客角色/店铺背景仍是代码图形。
- **卡点**：**模型读不了图**（deepseek 和 MiMo-v2.6-pro-ultraspeed 都不支持图像输入），没法确认食物 tile 对应哪道菜（现在是按颜色猜的，可能错位）。
- **素材来源**：`/tmp/opencode/assets/`（已下载 Kenney 食物/角色/UI + Roguelike 厨房包）。
- **下一步**：要么换带视觉的模型精确对接，要么人工告知「哪块 tile 是哪道菜」。

### ⬜ 待做

- 美术完善（顾客角色 sprite、店铺背景 tilemap）
- 数值平衡（需实测反馈）
- 音效/音乐（需素材）
- 更多内容（菜/客人/事件，数据驱动很快）

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
# 冒烟测试（自动演示跑 N 帧）
godot --headless --quit-after 20000 -- --autoplay
```

## 9. Git 提交规范

Conventional Commit：`feat(scope): 描述`。已完成 22+ commit，见 `git log --oneline`。
