import pyautogui
import keyboard

while True:
    pyautogui.moveRel(5, 0, duration=0.1)
    pyautogui.moveRel(-5, 0, duration=0.1)
    if keyboard.is_pressed('q'):  # if key 'q' is pressed 
        break  # finishing the loopq