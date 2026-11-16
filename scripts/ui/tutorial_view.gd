class_name TutorialView
extends UIView
## 新手引导遮罩：居中米白圆角卡片 + 深棕标题条 + 主题按钮。step = -1 表示不显示。


const STEPS := [
	"欢迎开店！点下方「开门营业」开始营业",
	"客人进店点单，点客人「接单」",
	"点厨房里的菜上工位，步骤自动计时；灶台做好趁热取走，晚了糊锅",
	"做完变发光盘子，点它「上菜」收钱",
	"多线忙不过来时按顺序救火：收桌 → 上菜 → 取锅 → 接单 → 派工位",
	"地面变脏点「拖地」（要花 3 秒，期间做不了菜），脏店客人没耐心",
	"每天结束自动存档，开店前点绿色按钮升级设备",
]

var step: int = -1


func is_active() -> bool:
	return step >= 0


func advance() -> void:
	step += 1
	if step >= STEPS.size():
		step = -1


func skip() -> void:
	step = -1


func _draw() -> void:
	if step < 0:
		return
	# 遮罩
	draw_rect(Rect2(0, 0, GameLayout.W, GameLayout.H), Color(0.12, 0.08, 0.06, 0.62))
	var r := GameLayout.TUTORIAL_RECT
	# 卡片：米白圆角 + 大投影
	UITheme.panel(self, r.grow(14), Color(0, 0, 0, 0.30), 22)
	UITheme.panel(self, r, UITheme.CREAM, 20, Color(0.35, 0.25, 0.16, 0.45), 2)
	# 标题条
	var header := Rect2(r.position + Vector2(0, 0), Vector2(r.size.x, 58))
	UITheme.panel(self, Rect2(header.position + Vector2(0, 0), Vector2(header.size.x, 58)), UITheme.ESPRESSO, 20)
	draw_rect(Rect2(header.position + Vector2(0, 38), Vector2(header.size.x, 20)), UITheme.ESPRESSO)
	UITheme.label(self, font, r.position + Vector2(30, 39), tr("新手引导 (%d/%d)") % [step + 1, STEPS.size()], 20, UITheme.GOLD)
	# 正文
	UITheme.label(self, font, r.position + Vector2(30, 110), tr(STEPS[step]), 22, UITheme.INK)
	# 步骤点（进度小圆点）
	var n: int = STEPS.size()
	var dot_w := n * 18
	var dx: float = r.position.x + r.size.x / 2.0 - dot_w / 2.0
	for i in range(n):
		var active: bool = i == step
		draw_circle(Vector2(dx + i * 18 + 4, r.position.y + r.size.y - 26), 5 if active else 3.5, UITheme.ACCENT if active else Color(0.72, 0.66, 0.56))
	_draw_button(GameLayout.TUTORIAL_NEXT_RECT, tr("下一步"), true, "accent")
	_draw_button(GameLayout.TUTORIAL_SKIP_RECT, tr("跳过"), true, "grey")
