import tkinter as tk
from tkinter import filedialog
import csv
import pyperclip

class CSVSelector:
    def __init__(self, master):
        self.master = master
        self.master.title("Keinan CSV Clipboard")

        # Set window size
        self.master.geometry("225x200")

        # Set always on top
        self.master.wm_attributes("-topmost", 1)

        # Create variables
        self.csv_data = []
        self.current_row = 0

        # Create GUI elements
        self.csv_label = tk.Label(self.master, text="Select a CSV file:")
        self.csv_label.pack()

        self.csv_entry = tk.Entry(self.master)
        self.csv_entry.pack()

        self.load_button = tk.Button(self.master, text="Load CSV", command=self.load_csv)
        self.load_button.pack()

        self.current_label = tk.Label(self.master, text="Current clipboard item:")
        self.current_label.pack()

        self.clipboard_var = tk.StringVar()
        self.clipboard_entry = tk.Entry(self.master, textvariable=self.clipboard_var, state="readonly")
        self.clipboard_entry.pack()

        self.prev_button = tk.Button(self.master, text="Previous", command=self.prev_row)
        self.prev_button.pack()

        self.next_button = tk.Button(self.master, text="Next", command=self.next_row)
        self.next_button.pack()

    def load_csv(self):
        # Get file path using file dialog
        file_path = filedialog.askopenfilename()
        self.csv_entry.delete(0, tk.END)
        self.csv_entry.insert(0, file_path)

        # Load CSV file and store data in self.csv_data
        with open(file_path) as f:
            reader = csv.reader(f)
            self.csv_data = list(reader)
        
        # Set clipboard to first item in CSV
        pyperclip.copy(self.csv_data[0][0])
        self.clipboard_var.set(pyperclip.paste())

    def prev_row(self):
        # Decrement current row and set clipboard to item in CSV
        if self.current_row > 0:
            self.current_row -= 1
            pyperclip.copy(self.csv_data[self.current_row][0])
            self.clipboard_var.set(pyperclip.paste())

    def next_row(self):
        # Increment current row and set clipboard to item in CSV
        if self.current_row < len(self.csv_data) - 1:
            self.current_row += 1
            pyperclip.copy(self.csv_data[self.current_row][0])
            self.clipboard_var.set(pyperclip.paste())

if __name__ == "__main__":
    root = tk.Tk()
    CSVSelector(root)
    root.mainloop()
