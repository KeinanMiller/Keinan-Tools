import pyautogui
import time

# Calibration (Run this first to find the box's coordinates)
print("Move your mouse over the center of the box and press Enter.")
input()
box_x, box_y = pyautogui.position()
print(f"Box coordinates: ({box_x}, {box_y})")

# Main Loop
while True:
    # Get a screenshot of the box area
    box_screenshot = pyautogui.screenshot(region=(box_x - 5, box_y - 5, 10, 10))  # Capture a small area around the center

    # Check if the box color is predominantly white
    if box_screenshot.getpixel((5, 5))[0] >= 240:  # Threshold for 'whiteness' (adjust if needed)
        pyautogui.click(box_x, box_y)  # Click the center of the box
        print("Clicked the box!")
        time.sleep(0.5)  # Brief delay to avoid excessive clicking

    time.sleep(0.1)  # Adjust polling frequency as needed 