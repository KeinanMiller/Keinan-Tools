#XML to CSV converter
import xml.etree.ElementTree as ET
import csv
import tkinter as tk
from tkinter import filedialog

def select_xml_file():
    # Initialize Tkinter
    root = tk.Tk()
    root.withdraw()  # Use to hide the main window

    # Open the file dialog
    file_path = filedialog.askopenfilename(filetypes=[("XML files", "*.xml")])

    return file_path

def main():
    # Use the file dialog to select the XML file
    xml_file_path = select_xml_file()

    if not xml_file_path:
        print("No file selected.")
        return

    # Parse the XML file
    tree = ET.parse(xml_file_path)
    root = tree.getroot()

    # Open a CSV file for writing
    with open('events.csv', 'w', newline='') as file:
        writer = csv.writer(file)

        # Write the header
        writer.writerow(['Name', 'Value_Name'])

        # Find all 'Event' elements, concatenate 'Value' and 'Name' (in this order), enclose in single quotes, and write to the CSV
        for event in root.findall(".//Event"):
            name = event.find('Name').text if event.find('Name') is not None else ''
            value = event.find('Value').text if event.find('Value') is not None else ''
            value_name = f"'{value}_{name}'"  # Concatenating Value and Name (note the order) and enclosing in single quotes
            writer.writerow([name, value_name])

    print(f"Data has been written to events.csv successfully.")

if __name__ == "__main__":
    main()

