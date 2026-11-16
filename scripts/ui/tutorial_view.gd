class_name TutorialView
extends UIView
## 新手引导遮罩：分步提示卡片。step = -1 表示不显示。


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
	draw_rect(Rect2(0, 0, GameLayout.W, GameLayout.H), Color(0, 0, 0, 0.6))
	draw_rect(GameLayout.TUTORIAL_RECT, Color(0.16, 0.16, 0.22))
	draw_rect(GameLayout.TUTORIAL_RECT, Color(0.8, 0.8, 0.9), false, 2.0)
	draw_string(font, GameLayout.TUTORIAL_RECT.position + Vector2(30, 42), tr("新手引导 (%d/%d)") % [step + 1, STEPS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.9, 0.4))
	draw_string(font, GameLayout.TUTORIAL_RECT.position + Vector2(30, 96), tr(STEPS[step]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	_draw_button(GameLayout.TUTORIAL_NEXT_RECT, tr("下一步"), true)
	_draw_button(GameLayout.TUTORIAL_SKIP_RECT, tr("跳过"), true)
