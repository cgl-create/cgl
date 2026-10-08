from microbit import display, Image

# CGL+ LabZ micro:bit v2 display receiver.
# Flash this file to the micro:bit v2 using the micro:bit Python editor.

def show_status(value):
    value = value.strip()
    if value == "NORMAL":
        display.show(Image.YES)
    elif value == "ALERT":
        display.show(Image.NO)
    elif value.startswith("WARMUP:"):
        try:
            remaining = int(value.split(":", 1)[1])
            display.show(str(remaining % 10))
        except ValueError:
            display.show(Image.ASLEEP)
    else:
        display.show(Image.ASLEEP)

display.show(Image.ASLEEP)
while True:
    try:
        line = input()
        if line:
            show_status(line)
    except Exception:
        pass
