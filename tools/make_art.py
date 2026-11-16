#!/usr/bin/env python3
"""Cozy Shop 像素素材生成器：自己画全部图形（顾客/桌椅/背景/厨房设备/装饰/食物）。

用法：python3 tools/make_art.py          # 生成 assets/sprites_v2/
预览：同目录 preview.jpg 自动合成总览。
风格：32px 角色 / 2x 桌椅 / 2x 背景，统一暖棕描边 + 左上高光 + 右下暗部。
"""
from PIL import Image, ImageDraw

OUT = "assets/sprites_v2"

# ---------- 色板（暖色咖啡店） ----------
def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

INK      = hx("#3A2A1C")   # 描边（暖深棕）
WOOD_D   = hx("#7A4E2A")
WOOD_M   = hx("#9C6B3C")
WOOD_L   = hx("#C08D55")
WOOD_H   = hx("#E0B07A")
WALL     = hx("#F2E3C8")
WALL_D   = hx("#DCC7A2")
WAIN     = hx("#B98D5F")
FLOOR_A  = hx("#EAD9B8")
FLOOR_B  = hx("#E0CCA4")
FLOOR_D  = hx("#C9B184")
KITCH_D  = hx("#4A424E")
KITCH_M  = hx("#5C5260")
KITCH_L  = hx("#6E6272")
SKIN     = hx("#F6D2A6")
SKIN_D   = hx("#E3B482")
WHITE    = hx("#FDFBF6")
CREAM    = hx("#F5EEDC")
RED      = hx("#D8604C")
PINK     = hx("#E89A92")
GREEN    = hx("#7FB069")
GREEN_D  = hx("#5E8A4C")
TEAL     = hx("#4E8D8D")
BLUE     = hx("#5E86C4")
PURPLE   = hx("#7A5A96")
GOLD     = hx("#E8B84B")
COFFEE   = hx("#6B4226")
GREY     = hx("#9A9298")
GREY_D   = hx("#6E666E")


def canvas(w, h):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def save(im, name, scale=1):
    if scale > 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(f"{OUT}/{name}.png")


def shade(im, dy=2):
    """右下暗部：非透明像素右下 1px 深色叠加，制造体积感。"""
    px = im.load()
    for y in range(im.height - 1, -1, -1):
        for x in range(im.width - 1, -1, -1):
            r, g, b, a = px[x, y]
            if a > 0 and (x + 1 >= im.width or px[x + 1, y][3] == 0) and y + dy < im.height:
                pass
    return im


def outline_sprite(im, color=INK):
    """描边：图形外扩 1px 画 color，内部保持原色。"""
    a = im.split()[3]
    px = a.load()
    grown = a.copy()
    gp = grown.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and px[nx, ny] > 0:
                    gp[x, y] = 255
                    break
    base = Image.new("RGBA", im.size, color)      # 全描边色
    base.paste(im, (0, 0), grown)                 # 图形 + 外缘填充（外缘源像素透明，会被挖空）
    # 上面一行挖空的外缘重新填描边色：分两步才正确
    base = Image.new("RGBA", im.size, color)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(base, (0, 0), grown)                # 图形+外缘 1px = 描边色
    out.paste(im, (0, 0), im)                     # 图形内部恢复原色
    return out


# ============ 顾客小人（32x32） ============

def person(name, hair, shirt, apron=None, skin=SKIN, hair_style="short", accessory=None):
    im, d = canvas(32, 32)
    # 身体（圆角衣身）
    d.rounded_rectangle([8, 19, 23, 31], radius=5, fill=shirt)
    d.rectangle([9, 28, 22, 31], fill=shirt)
    # 手臂
    d.rounded_rectangle([5, 21, 9, 28], radius=2, fill=shirt)
    d.rounded_rectangle([22, 21, 26, 28], radius=2, fill=shirt)
    d.rectangle([6, 26, 8, 28], fill=skin)   # 手
    d.rectangle([23, 26, 25, 28], fill=skin)
    if apron:
        d.rounded_rectangle([11, 23, 20, 31], radius=3, fill=apron)
        d.rectangle([12, 22, 19, 23], fill=apron)
    # 头
    d.ellipse([7, 2, 24, 21], fill=skin, outline=SKIN_D)
    # 发型
    if hair_style == "short":
        d.pieslice([7, 1, 24, 17], 180, 360, fill=hair)
        d.rectangle([7, 8, 9, 13], fill=hair)
        d.rectangle([22, 8, 24, 13], fill=hair)
    elif hair_style == "long":
        d.pieslice([7, 1, 24, 17], 180, 360, fill=hair)
        d.rectangle([6, 8, 10, 24], fill=hair)
        d.rectangle([21, 8, 25, 24], fill=hair)
        d.rectangle([6, 22, 10, 24], fill=hair)
        d.rectangle([21, 22, 25, 24], fill=hair)
    elif hair_style == "bun":
        d.pieslice([7, 1, 24, 17], 180, 360, fill=hair)
        d.ellipse([13, -1, 18, 4], fill=hair)
    elif hair_style == "mop":
        d.pieslice([6, 0, 25, 18], 180, 360, fill=hair)
        d.rectangle([6, 9, 8, 15], fill=hair)
        d.rectangle([23, 9, 25, 15], fill=hair)
    # 耳朵
    d.ellipse([6, 11, 9, 15], fill=skin, outline=SKIN_D)
    d.ellipse([22, 11, 25, 15], fill=skin, outline=SKIN_D)
    # 眼睛（大眼睛可爱风）
    for ex in (11, 18):
        d.rectangle([ex, 11, ex + 2, 14], fill=INK)
        d.point((ex, 11), fill=WHITE)
    # 腮红 + 嘴
    d.rectangle([8, 15, 10, 16], fill=PINK)
    d.rectangle([21, 15, 23, 16], fill=PINK)
    d.rectangle([14, 17, 17, 18], fill=hx("#B06A50"))
    # 配饰
    if accessory == "hat":
        d.rectangle([8, 2, 23, 5], fill=PURPLE)
        d.rectangle([5, 5, 26, 7], fill=PURPLE)
        d.rectangle([8, 2, 23, 3], fill=hx("#8E6AAA"))
    if accessory == "monocle":
        d.ellipse([17, 10, 21, 14], outline=GOLD, width=1)
        d.line([20, 14, 21, 18], fill=GOLD)
    if accessory == "moustache":
        d.rectangle([12, 16, 19, 17], fill=GREY_D)
    save(outline_sprite(im), name)


# ============ 餐桌组合（120x50，含双椅） ============

def table_set():
    im, d = canvas(120, 50)
    # 地毯（桌椅下层，暖红棕花纹）
    d.ellipse([4, 20, 116, 50], fill=hx("#B5654A"))
    d.ellipse([7, 22, 113, 48], fill=hx("#C87A5C"))
    d.ellipse([13, 26, 107, 44], fill=hx("#B5654A"))
    # 椅子（左/右，侧视）：竖立靠背 + 坐垫 + 腿
    for cx in (2, 92):
        # 靠背（竖板，圆顶）
        d.rounded_rectangle([cx + 4, 2, cx + 20, 16], radius=5, fill=WOOD_D, outline=INK)
        d.rounded_rectangle([cx + 7, 5, cx + 17, 13], radius=3, fill=WOOD_M)
        # 坐垫
        d.rounded_rectangle([cx + 1, 16, cx + 23, 22], radius=3, fill=WOOD_M, outline=INK)
        d.rectangle([cx + 3, 17, cx + 21, 18], fill=WOOD_L)
        # 腿
        d.rectangle([cx + 3, 22, cx + 5, 33], fill=WOOD_D, outline=INK)
        d.rectangle([cx + 19, 22, cx + 21, 33], fill=WOOD_D, outline=INK)
    # 桌腿
    d.rectangle([36, 33, 42, 47], fill=WOOD_D, outline=INK)
    d.rectangle([78, 33, 84, 47], fill=WOOD_D, outline=INK)
    # 桌面（宽，三层：描边 -> 深 -> 主体 -> 高光 -> 桌沿）
    d.rounded_rectangle([24, 14, 96, 37], radius=9, fill=INK)
    d.rounded_rectangle([25, 15, 95, 36], radius=8, fill=WOOD_D)
    d.rounded_rectangle([27, 17, 93, 32], radius=6, fill=WOOD_M)
    d.rounded_rectangle([30, 19, 90, 24], radius=3, fill=WOOD_L)
    d.rectangle([27, 29, 93, 32], fill=WOOD_D)
    save(outline_sprite(im), "table_set", scale=2)


# ============ 厨房设备图标（24x24） ============

def icon_prep():
    im, d = canvas(24, 24)
    d.rounded_rectangle([2, 8, 21, 18], radius=3, fill=WOOD_L, outline=INK)  # 砧板
    d.rectangle([2, 12, 21, 13], fill=WOOD_M)
    d.rectangle([17, 4, 19, 12], fill=GREY_D, outline=INK)                   # 刀柄
    d.polygon([(16, 2), (21, 2), (19, 8), (16, 8)], fill=GREY, outline=INK)  # 刀身
    d.ellipse([5, 9, 9, 13], fill=RED, outline=INK)                          # 番茄
    save(outline_sprite(im), "icon_prep")


def icon_stove():
    im, d = canvas(24, 24)
    # 蒸汽
    d.ellipse([6, 1, 8, 3], fill=WHITE)
    d.ellipse([11, 0, 13, 3], fill=WHITE)
    d.ellipse([15, 2, 17, 4], fill=WHITE)
    # 锅耳
    d.rectangle([1, 11, 4, 14], fill=GREY_D, outline=INK)
    d.rectangle([19, 11, 22, 14], fill=GREY_D, outline=INK)
    # 锅体
    d.rounded_rectangle([3, 9, 20, 21], radius=4, fill=GREY_D, outline=INK)
    d.ellipse([3, 6, 20, 12], fill=GREY, outline=INK)      # 锅口
    d.ellipse([5, 7, 18, 11], fill=hx("#8A5A2E"))           # 汤
    d.rectangle([5, 14, 18, 15], fill=GREY)                 # 高光
    save(outline_sprite(im), "icon_stove")


def icon_plate():
    im, d = canvas(24, 24)
    d.ellipse([2, 6, 21, 21], fill=WHITE, outline=INK)      # 盘
    d.ellipse([5, 9, 18, 18], fill=CREAM, outline=GREY_D)
    d.rectangle([3, 2, 4, 10], fill=GREY, outline=INK)      # 叉
    for y in (2, 4, 6):
        d.rectangle([2, y, 3, y + 1], fill=GREY)
    save(outline_sprite(im), "icon_plate")


# ============ 装饰（32x32） ============

def plant(name, pot=hx("#C4724A"), leaf=GREEN):
    im, d = canvas(32, 32)
    d.polygon([(11, 20), (21, 20), (19, 30), (13, 30)], fill=pot, outline=INK)
    d.rectangle([10, 18, 22, 21], fill=hx("#D8845C"), outline=INK)
    for dx, dy in ((-7, -8), (0, -12), (7, -8), (-4, -3), (4, -3)):
        d.ellipse([16 + dx - 5, 14 + dy - 4, 16 + dx + 5, 14 + dy + 4], fill=leaf, outline=GREEN_D)
    d.ellipse([12, 4, 16, 8], fill=hx("#9CCB7A"))
    save(outline_sprite(im), name)


def picture():
    im, d = canvas(32, 32)
    d.rectangle([3, 5, 28, 27], fill=WOOD_D, outline=INK)
    d.rectangle([5, 7, 26, 25], fill=CREAM)
    d.polygon([(8, 22), (14, 12), (19, 22)], fill=GREEN_D)     # 小山
    d.ellipse([19, 9, 24, 14], fill=GOLD)                       # 太阳
    save(outline_sprite(im), "picture")


# ============ 背景（640x360 -> 2x = 1280x720） ============

def background():
    im, d = canvas(640, 360)
    W, H = 640, 360
    kh = 64  # 厨房区起点
    # 地板（16px 瓷砖，隔行深浅 + 缝隙）
    for ty in range(64, H, 16):
        for tx in range(0, 460, 16):
            c = FLOOR_A if ((tx // 16) + (ty // 16)) % 2 == 0 else FLOOR_B
            d.rectangle([tx, ty, tx + 15, ty + 15], fill=c)
            d.line([tx, ty, tx + 15, ty], fill=FLOOR_D)
            d.line([tx, ty, tx, ty + 15], fill=FLOOR_D)
    # 墙面（上半）：奶白墙 + 顶部横梁 + 护墙板
    d.rectangle([0, 0, W, 64], fill=WALL)
    for y in range(0, 64, 8):
        d.line([0, y, W, y], fill=WALL_D)
    d.rectangle([0, 52, 460, 64], fill=WAIN)      # 护墙板
    d.line([0, 52, 460, 52], fill=WOOD_D)
    d.rectangle([0, 0, W, 10], fill=WOOD_D)       # 顶梁
    d.rectangle([0, 10, W, 13], fill=WOOD_M)
    # 窗户 x2（带窗台）
    for wx in (70, 180):
        d.rectangle([wx, 18, wx + 36, 46], fill=WOOD_D, outline=INK)
        d.rectangle([wx + 3, 21, wx + 33, 43], fill=hx("#BFE3F2"))
        d.line([wx + 18, 21, wx + 18, 43], fill=WOOD_D)
        d.line([wx + 3, 32, wx + 33, 32], fill=WOOD_D)
        d.rectangle([wx - 2, 46, wx + 38, 49], fill=WOOD_L, outline=INK)
    # 菜单牌
    d.rectangle([130, 16, 168, 42], fill=INK)
    d.rectangle([132, 18, 166, 40], fill=WOOD_D)
    for i in range(3):
        d.line([136, 23 + i * 6, 162, 23 + i * 6], fill=CREAM)
    # 厨房区（x>=460）：深色石砖墙 + 地面深砖 + 吊架
    d.rectangle([460, 0, W, H], fill=KITCH_D)
    for ty in range(13, H, 13):
        off = 6 if (ty // 13) % 2 else 0
        d.line([460, ty, W, ty], fill=KITCH_M)
        for tx in range(460 + off, W, 26):
            d.line([tx, ty - 13, tx, ty], fill=KITCH_M)
    d.rectangle([460, 0, W, 10], fill=WOOD_D)
    d.line([460, 52, W, 52], fill=KITCH_L)
    # 吊架 + 锅剪影
    d.rectangle([470, 22, W - 20, 26], fill=GREY_D)
    for i in range(3):
        cx = 490 + i * 50
        d.rectangle([cx, 26, cx + 4, 34], fill=GREY_D)
        d.ellipse([cx - 6, 34, cx + 10, 48], fill=KITCH_L, outline=KITCH_M)
    # 吊灯 + 暖光锥（客席上方两盏）
    for lx in (125, 310):
        d.line([lx, 13, lx, 22], fill=INK)                       # 吊线
        d.polygon([(lx - 10, 30), (lx + 10, 30), (lx + 6, 22), (lx - 6, 22)], fill=WOOD_D, outline=INK)  # 灯罩
        d.ellipse([lx - 5, 29, lx + 5, 34], fill=GOLD)           # 灯泡
        cone = Image.new("RGBA", (640, 360), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cone)
        cd.polygon([(lx - 8, 34), (lx + 8, 34), (lx + 72, 205), (lx - 72, 205)], fill=(255, 214, 140, 42))
        im.alpha_composite(cone)
    # 分区线（客席 / 厨房）
    d.rectangle([458, 10, 462, H], fill=WOOD_D)
    d.line([460, 10, 460, H], fill=INK)
    save(im, "shop_bg", scale=2)


# ============ 食物（24x24，统一风格重画） ============

def food_milk_tea():
    im, d = canvas(24, 24)
    d.rounded_rectangle([6, 6, 17, 21], radius=3, fill=WHITE, outline=INK)   # 杯
    d.rectangle([7, 10, 16, 20], fill=hx("#C9925C"))                          # 奶茶
    d.rectangle([7, 10, 16, 12], fill=hx("#E8C79A"))
    d.rounded_rectangle([17, 9, 20, 17], radius=2, fill=WHITE, outline=INK)  # 把手
    d.rectangle([5, 4, 18, 7], fill=hx("#E8DCC8"), outline=INK)               # 盖
    d.rectangle([11, 1, 13, 5], fill=RED, outline=INK)                        # 吸管
    save(outline_sprite(im), "food_milk_tea")


def food_coffee():
    im, d = canvas(24, 24)
    d.rounded_rectangle([5, 7, 17, 21], radius=3, fill=WHITE, outline=INK)
    d.rectangle([6, 9, 16, 12], fill=COFFEE)
    d.rounded_rectangle([17, 10, 21, 17], radius=2, fill=WHITE, outline=INK)
    d.ellipse([9, 3, 11, 5], fill=WHITE)
    d.ellipse([13, 1, 15, 4], fill=WHITE)
    save(outline_sprite(im), "food_coffee")


def food_juice():
    im, d = canvas(24, 24)
    d.polygon([(6, 5), (18, 5), (16, 21), (8, 21)], fill=WHITE, outline=INK)
    d.polygon([(7, 9), (17, 9), (15.5, 20), (8.5, 20)], fill=hx("#F2A03C"))
    d.rectangle([5, 3, 19, 6], fill=hx("#E8E2D4"), outline=INK)
    d.rectangle([11, 0, 13, 4], fill=GREEN_D, outline=INK)   # 吸管
    save(outline_sprite(im), "food_juice")


def food_sandwich():
    im, d = canvas(24, 24)
    d.polygon([(3, 12), (12, 4), (21, 12)], fill=hx("#E8B868"), outline=INK)   # 上层面包
    d.rectangle([3, 12, 21, 14], fill=GREEN, outline=INK)                        # 生菜
    d.rectangle([3, 14, 21, 17], fill=RED, outline=INK)                          # 番茄/肉
    d.rectangle([3, 17, 21, 21], fill=hx("#D89A50"), outline=INK)                # 下层
    save(outline_sprite(im), "food_sandwich")


def food_salad():
    im, d = canvas(24, 24)
    d.pieslice([2, 8, 22, 24], 0, 180, fill=WHITE, outline=INK)
    for cx, cy, c in ((7, 10, GREEN), (12, 8, GREEN_D), (16, 10, GREEN), (10, 11, hx("#F2A03C")), (14, 12, RED)):
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 3], fill=c, outline=INK)
    save(outline_sprite(im), "food_salad")


def food_burger():
    im, d = canvas(24, 24)
    d.pieslice([3, 4, 21, 18], 180, 360, fill=hx("#E8B868"), outline=INK)   # 上层面包
    for i, c in enumerate((GREEN, RED, hx("#8A5A2E"))):
        d.rectangle([3, 11 + i * 3, 21, 13 + i * 3], fill=c, outline=INK)   # 馅
    d.rectangle([3, 17, 21, 21], fill=hx("#D89A50"), outline=INK)           # 下层
    save(outline_sprite(im), "food_burger")


def food_cake():
    im, d = canvas(24, 24)
    d.polygon([(4, 9), (12, 3), (20, 9), (20, 21), (4, 21)], fill=hx("#F2C8D8"), outline=INK)
    d.rectangle([4, 13, 20, 15], fill=WHITE)
    d.rectangle([4, 18, 20, 20], fill=WHITE)
    d.rectangle([11, 0, 13, 3], fill=RED, outline=INK)     # 樱桃梗
    d.ellipse([9, -1, 14, 3], fill=RED, outline=INK)
    save(outline_sprite(im), "food_cake")


def food_soup():
    im, d = canvas(24, 24)
    d.pieslice([2, 9, 22, 25], 0, 180, fill=GREY, outline=INK)
    d.ellipse([4, 7, 20, 13], fill=hx("#E8955C"), outline=INK)
    d.ellipse([8, 8, 11, 11], fill=hx("#F2B078"))
    d.ellipse([13, 9, 15, 11], fill=GREEN_D)
    d.ellipse([7, 2, 9, 4], fill=WHITE)
    d.ellipse([13, 1, 15, 3], fill=WHITE)
    save(outline_sprite(im), "food_soup")


def food_ice_cream():
    im, d = canvas(24, 24)
    d.polygon([(8, 12), (16, 12), (12, 23)], fill=hx("#D89A50"), outline=INK)   # 蛋筒
    d.ellipse([6, 5, 18, 15], fill=hx("#FBE8D8"), outline=INK)                   # 奶油
    d.ellipse([8, 1, 16, 8], fill=PINK, outline=INK)                             # 冰淇淋
    d.ellipse([11, -2, 14, 1], fill=RED)                                         # 樱桃
    save(outline_sprite(im), "food_ice_cream")


def food_pizza():
    im, d = canvas(24, 24)
    d.polygon([(12, 2), (21, 21), (3, 21)], fill=hx("#E8B868"), outline=INK)   # 饼底
    d.polygon([(12, 5), (19, 20), (5, 20)], fill=hx("#E8A050"))                  # 酱
    for cx, cy in ((12, 10), (9, 16), (15, 16), (12, 18)):
        d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=RED, outline=INK)      # 腊肠
    save(outline_sprite(im), "food_pizza")


if __name__ == "__main__":
    import os
    os.makedirs(OUT, exist_ok=True)

    # 顾客：熟客 + 路人 + 评论家
    person("customer_laozhang", GREY, TEAL, hair_style="short", accessory="moustache")
    person("customer_xiaowang", INK, hx("#D8784A"), hair_style="mop")
    person("customer_lijie", hx("#B85C38"), PINK, apron=CREAM, hair_style="long")
    person("customer_critic", INK, PURPLE, hair_style="short", accessory="hat")
    person("customer_g0", hx("#6B4226"), BLUE, hair_style="short")
    person("customer_g1", INK, GREEN, hair_style="short")
    person("customer_g2", hx("#C4724A"), GOLD, hair_style="bun")
    person("customer_g3", hx("#8A5A2E"), hx("#C47296"), hair_style="short")
    person("customer_g4", GREY_D, hx("#5E86C4"), hair_style="short")
    person("customer_g5", hx("#4A2E1C"), RED, hair_style="bun")

    table_set()
    icon_prep(); icon_stove(); icon_plate()
    plant("decor_plant_a"); plant("decor_plant_b", pot=hx("#7A8FA6"), leaf=GREEN_D)
    picture()
    background()

    food_milk_tea(); food_coffee(); food_juice(); food_sandwich(); food_salad()
    food_burger(); food_cake(); food_soup(); food_ice_cream(); food_pizza()

    # 预览总览
    names = ["customer_laozhang", "customer_xiaowang", "customer_lijie", "customer_critic",
             "customer_g0", "customer_g1", "customer_g2", "customer_g3", "customer_g4", "customer_g5"]
    foods = ["food_milk_tea", "food_coffee", "food_juice", "food_sandwich", "food_salad",
             "food_burger", "food_cake", "food_soup", "food_ice_cream", "food_pizza"]
    sheet = Image.new("RGBA", (960, 780), (210, 195, 170, 255))
    bg = Image.open(f"{OUT}/shop_bg.png").convert("RGBA").resize((940, 529), Image.NEAREST)
    sheet.paste(bg, (10, 10), bg)
    x = 10
    for n in names:
        im2 = Image.open(f"{OUT}/{n}.png").convert("RGBA").resize((64, 64), Image.NEAREST)
        sheet.paste(im2, (x, 545), im2); x += 70
    x = 10
    for n in foods:
        im2 = Image.open(f"{OUT}/{n}.png").convert("RGBA").resize((56, 56), Image.NEAREST)
        sheet.paste(im2, (x, 615), im2); x += 62
    x = 10
    for n in ["table_set", "icon_prep", "icon_stove", "icon_plate", "decor_plant_a", "decor_plant_b", "picture"]:
        im2 = Image.open(f"{OUT}/{n}.png").convert("RGBA")
        im2.thumbnail((96, 96), Image.NEAREST)
        sheet.paste(im2, (x, 675), im2); x += 110
    sheet.convert("RGB").save("/tmp/art_v2_preview.jpg", quality=88)
    print("generated ->", OUT, "| preview /tmp/art_v2_preview.jpg")
