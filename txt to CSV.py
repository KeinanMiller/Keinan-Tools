# used for special case of txt to cvs
import csv
from tkinter import Tk, filedialog

def convert_tabs_to_csv(input_file, output_file):
    with open(input_file, 'r', encoding='utf-16') as infile:
        reader = csv.reader(infile, delimiter='\t')
        data = list(reader)

    with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
        writer = csv.writer(outfile)
        writer.writerows(data)

def select_files():
    root = Tk()
    root.withdraw()  # Hide the main window

    input_file_path = filedialog.askopenfilename(title="Select an input file", filetypes=[("Text files", "*.txt")])

    if not input_file_path:
        print("No input file selected. Exiting.")
        return None, None

    output_file_path = filedialog.asksaveasfilename(title="Select an output file", defaultextension=".csv", filetypes=[("CSV files", "*.csv")])

    if not output_file_path:
        print("No output file selected. Exiting.")
        return None, None

    return input_file_path, output_file_path

# Example usage:
input_file_path, output_file_path = select_files()

if input_file_path and output_file_path:
    convert_tabs_to_csv(input_file_path, output_file_path)
    print("Conversion complete.")
