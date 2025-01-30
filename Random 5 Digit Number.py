import tkinter as tk
import random

class RandomNumberGeneratorGUI:
    def __init__(self, master):
        self.master = master
        master.title("Random Number Generator")

        self.number_label = tk.Label(master, font=("Helvetica", 48), width=10)
        self.number_label.pack(pady=20)

        self.generate_button = tk.Button(master, text="Generate", font=("Helvetica", 24), command=self.generate_random_number)
        self.generate_button.pack(pady=10)

    def generate_random_number(self):
        random_number = random.randint(10000, 99999)
        self.number_label.config(text=str(random_number))

if __name__ == "__main__":
    root = tk.Tk()
    app = RandomNumberGeneratorGUI(root)
    root.mainloop()
