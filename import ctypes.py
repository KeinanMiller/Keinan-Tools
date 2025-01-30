import ctypes
import schedule
import time

def prevent_sleep():
    ctypes.windll.kernel32.SetThreadExecutionState(0x80000002)

schedule.every(5).minutes.do(prevent_sleep)

while True:
    schedule.run_pending()
    time.sleep(1)