from PIL import Image, ImageDraw


CANVAS = 1024
BG = "#0A1929"
SHIELD = "#3399FF"
WHITE = "#FFFFFF"


def main() -> None:
    image = Image.new("RGBA", (CANVAS, CANVAS), BG)
    draw = ImageDraw.Draw(image)

    center = CANVAS // 2

    shield_size = int(CANVAS * 0.80)
    half = shield_size // 2
    left = center - half
    top = center - half
    right = center + half
    bottom = center + half

    # Classic shield silhouette occupying 80% of canvas.
    shield_points = [
        (center, top),
        (left + int(shield_size * 0.16), top + int(shield_size * 0.12)),
        (left + int(shield_size * 0.12), top + int(shield_size * 0.45)),
        (center, bottom),
        (right - int(shield_size * 0.12), top + int(shield_size * 0.45)),
        (right - int(shield_size * 0.16), top + int(shield_size * 0.12)),
    ]
    draw.polygon(shield_points, fill=SHIELD)

    doc_size = int(CANVAS * 0.40)
    doc_w = int(doc_size * 0.74)
    doc_h = int(doc_size * 0.92)
    doc_left = center - (doc_w // 2)
    doc_top = center - (doc_h // 2) + int(CANVAS * 0.01)
    doc_right = doc_left + doc_w
    doc_bottom = doc_top + doc_h
    fold = int(doc_w * 0.22)

    # White document icon with folded corner.
    draw.polygon(
        [
            (doc_left, doc_top),
            (doc_right - fold, doc_top),
            (doc_right, doc_top + fold),
            (doc_right, doc_bottom),
            (doc_left, doc_bottom),
        ],
        fill=WHITE,
    )
    draw.polygon(
        [
            (doc_right - fold, doc_top),
            (doc_right - fold, doc_top + fold),
            (doc_right, doc_top + fold),
        ],
        fill=SHIELD,
    )

    line_color = "#CFE4FF"
    line_inset = int(doc_w * 0.12)
    line_start_x = doc_left + line_inset
    line_end_x = doc_right - line_inset
    first_y = doc_top + int(doc_h * 0.36)
    line_gap = int(doc_h * 0.14)
    for i in range(3):
        y = first_y + (i * line_gap)
        draw.rounded_rectangle(
            (line_start_x, y, line_end_x, y + int(doc_h * 0.05)),
            radius=6,
            fill=line_color,
        )

    image.save("assets/app_icon.png", "PNG")


if __name__ == "__main__":
    main()
