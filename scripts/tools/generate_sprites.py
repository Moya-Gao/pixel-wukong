#!/usr/bin/env python3
"""生成像素悟空占位精灵"""

from PIL import Image
import os

# 精灵尺寸
WIDTH = 16
HEIGHT = 24
WIDTH_ATTACK = 24  # 攻击帧更宽，容纳武器效果

# 颜色定义
COLORS = {
    'skin': (232, 176, 136),      # 肤色
    'hair': (45, 45, 45),         # 黑发
    'headband': (255, 215, 0),    # 金箍
    'body': (139, 69, 19),        # 棕色衣服
    'pants': (74, 53, 32),        # 深棕裤子
    'outline': (30, 30, 30),      # 轮廓
    'eye': (20, 20, 20),          # 眼睛
    'transparent': (0, 0, 0, 0),  # 透明
}

def create_sprite_dir():
    """创建精灵目录"""
    base_path = "assets/sprites/player"
    os.makedirs(base_path, exist_ok=True)
    return base_path

def draw_outline(img, x, y, color):
    """画一个像素点"""
    img.putpixel((x, y), color)

def create_idle_frame1():
    """Idle 帧 1 - 站立"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 头发（顶发）
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']

    # 头发两侧
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    # 脸部
    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    # 金箍
    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    # 眼睛
    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿
    for x in range(4, 7):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']
    for x in range(9, 12):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']

    return img

def create_idle_frame2():
    """Idle 帧 2 - 轻微呼吸"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 头发
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    # 脸部（整体上移1像素 - 呼吸效果）
    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    # 金箍
    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    # 眼睛
    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体（稍微拉伸）
    for x in range(4, 12):
        for y in range(9, 17):
            pixels[x, y] = COLORS['body']

    # 腿
    for x in range(4, 7):
        for y in range(17, 24):
            pixels[x, y] = COLORS['pants']
    for x in range(9, 12):
        for y in range(17, 24):
            pixels[x, y] = COLORS['pants']

    return img

def create_run_frame(leg_offset):
    """Run 帧 - 奔跑"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 头发
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    # 脸部
    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    # 金箍
    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    # 眼睛
    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿（根据帧不同偏移）
    if leg_offset == 0:  # 左腿前
        for x in range(3, 6):
            for y in range(16, 22):
                pixels[x, y] = COLORS['pants']
        for x in range(10, 13):
            for y in range(18, 24):
                pixels[x, y] = COLORS['pants']
    elif leg_offset == 1:  # 并拢
        for x in range(4, 7):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(9, 12):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
    elif leg_offset == 2:  # 右腿前
        for x in range(3, 6):
            for y in range(18, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(10, 13):
            for y in range(16, 22):
                pixels[x, y] = COLORS['pants']
    else:  # 并拢2
        for x in range(4, 7):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(9, 12):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']

    return img

def create_jump_frame(rising=True):
    """Jump 帧 - 跳跃"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 头发
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    # 脸部
    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    # 金箍
    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    # 眼睛
    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿（跳跃姿态）
    if rising:
        # 上升 - 腿收起
        for x in range(3, 7):
            for y in range(16, 21):
                pixels[x, y] = COLORS['pants']
        for x in range(9, 13):
            for y in range(16, 21):
                pixels[x, y] = COLORS['pants']
    else:
        # 下降 - 腿准备落地
        for x in range(3, 6):
            for y in range(16, 23):
                pixels[x, y] = COLORS['pants']
        for x in range(10, 13):
            for y in range(16, 23):
                pixels[x, y] = COLORS['pants']

    return img

def create_attack_light_frame(combo_step):
    """轻攻击帧 - 三连击"""
    img = Image.new('RGBA', (WIDTH_ATTACK, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 基础身体（同 idle）
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体（攻击时前倾）
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿（根据连击阶段不同站姿）
    if combo_step == 0:  # 第一击 - 稳定站姿
        for x in range(4, 7):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(9, 12):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
    elif combo_step == 1:  # 第二击 - 前倾
        for x in range(3, 6):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(10, 13):
            for y in range(18, 24):
                pixels[x, y] = COLORS['pants']
    else:  # 第三击 - 大幅前倾
        for x in range(2, 5):
            for y in range(18, 24):
                pixels[x, y] = COLORS['pants']
        for x in range(10, 13):
            for y in range(16, 24):
                pixels[x, y] = COLORS['pants']

    # 攻击效果（金箍棒挥动轨迹）- 用金色表示
    if combo_step == 0:
        for x in range(13, 18):
            for y in range(8, 14):
                pixels[x, y] = (255, 215, 0, 200)
    elif combo_step == 1:
        for x in range(13, 20):
            for y in range(5, 12):
                pixels[x, y] = (255, 200, 0, 200)
    else:
        for x in range(14, 24):
            for y in range(3, 15):
                pixels[x, y] = (255, 180, 0, 220)

    return img

def create_attack_heavy_frame():
    """重攻击帧"""
    img = Image.new('RGBA', (WIDTH_ATTACK, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 基础身体
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体（蓄力姿势）
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿（站稳）
    for x in range(3, 6):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']
    for x in range(10, 13):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']

    # 重攻击效果（大范围金色）
    for x in range(13, 24):
        for y in range(2, 18):
            pixels[x, y] = (255, 180, 0, 180)

    return img

def create_dodge_frame():
    """闪避帧 - 快速移动残影"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 残影效果 - 半透明身体
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = (45, 45, 45, 100)  # 半透明头发
    pixels[3, 1] = (45, 45, 45, 100)
    pixels[3, 2] = (45, 45, 45, 100)
    pixels[12, 1] = (45, 45, 45, 100)
    pixels[12, 2] = (45, 45, 45, 100)

    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = (232, 176, 136, 100)  # 半透明肤色

    for x in range(4, 12):
        pixels[x, 4] = (255, 215, 0, 120)  # 半透明金箍

    pixels[5, 6] = (20, 20, 20, 80)
    pixels[10, 6] = (20, 20, 20, 80)

    # 身体（前倾闪避姿态）
    for x in range(5, 12):
        for y in range(10, 16):
            pixels[x, y] = (139, 69, 19, 100)  # 半透明身体

    # 腿（移动姿态）
    for x in range(2, 6):
        for y in range(17, 23):
            pixels[x, y] = (74, 53, 32, 100)
    for x in range(10, 14):
        for y in range(19, 24):
            pixels[x, y] = (74, 53, 32, 100)

    # 速度线效果
    for y in range(5, 20):
        pixels[0, y] = (255, 255, 255, 50)
        pixels[1, y] = (255, 255, 255, 80)
        pixels[2, y] = (255, 255, 255, 40)

    return img

def create_block_frame():
    """格挡帧 - 防御姿态"""
    img = Image.new('RGBA', (WIDTH, HEIGHT), COLORS['transparent'])
    pixels = img.load()

    # 头发
    for x in range(4, 12):
        for y in range(0, 3):
            pixels[x, y] = COLORS['hair']
    pixels[3, 1] = COLORS['hair']
    pixels[3, 2] = COLORS['hair']
    pixels[12, 1] = COLORS['hair']
    pixels[12, 2] = COLORS['hair']

    # 脸部
    for x in range(4, 12):
        for y in range(3, 9):
            pixels[x, y] = COLORS['skin']

    # 金箍
    for x in range(4, 12):
        pixels[x, 4] = COLORS['headband']

    # 眼睛
    pixels[5, 6] = COLORS['eye']
    pixels[10, 6] = COLORS['eye']

    # 身体（防御姿态）
    for x in range(4, 12):
        for y in range(9, 16):
            pixels[x, y] = COLORS['body']

    # 腿（站稳）
    for x in range(3, 7):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']
    for x in range(9, 13):
        for y in range(16, 24):
            pixels[x, y] = COLORS['pants']

    # 防御护盾效果（金色光环）
    for x in range(1, 15):
        for y in range(2, 22):
            # 只画边框
            if x == 1 or x == 14 or y == 2 or y == 21:
                pixels[x, y] = (255, 215, 0, 150)

    return img

def main():
    base_path = create_sprite_dir()

    # Idle 动画
    create_idle_frame1().save(f"{base_path}/idle_1.png")
    create_idle_frame2().save(f"{base_path}/idle_2.png")

    # Run 动画
    for i in range(4):
        create_run_frame(i).save(f"{base_path}/run_{i+1}.png")

    # Jump 动画
    create_jump_frame(True).save(f"{base_path}/jump_rise.png")
    create_jump_frame(False).save(f"{base_path}/jump_fall.png")

    # 轻攻击动画（三连击）
    for i in range(3):
        create_attack_light_frame(i).save(f"{base_path}/attack_light_{i+1}.png")

    # 重攻击动画
    create_attack_heavy_frame().save(f"{base_path}/attack_heavy.png")

    # 闪避动画
    create_dodge_frame().save(f"{base_path}/dodge.png")

    # 格挡动画
    create_block_frame().save(f"{base_path}/block.png")

    print(f"精灵已生成到 {base_path}/")
    print("- idle_1.png, idle_2.png")
    print("- run_1.png ~ run_4.png")
    print("- jump_rise.png, jump_fall.png")
    print("- attack_light_1.png ~ attack_light_3.png")
    print("- attack_heavy.png")
    print("- dodge.png")
    print("- block.png")

if __name__ == "__main__":
    main()
