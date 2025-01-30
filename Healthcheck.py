import psutil
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from tkinter import *
import socket

def get_machine_data():
    
    cpu_usage = str(psutil.cpu_percent()) + '%'
    ram = str(round(psutil.virtual_memory().total / (1024.0 **3))) + ' GB'
    ram_usage = str(psutil.virtual_memory().percent) + '%'
    disk = str(round(psutil.disk_usage('/').total / (1024.0 ** 3))) + ' GB'
    disk_usage = str(psutil.disk_usage('/').percent) + '%'
    network_card = psutil.net_if_addrs()
    network_usage = psutil.net_io_counters()
    ip_address = socket.gethostbyname(socket.gethostname())
    hostname = socket.gethostname()

    machine_data = {
        
        'CPU Usage': cpu_usage,
        'RAM': ram,
        'RAM Usage': ram_usage,
        'Disk Space': disk,
        'Disk Space Usage': disk_usage,
        'Network Card Info': network_card,
        'Network Usage': network_usage,
        'IP Address': ip_address,
        'Hostname': hostname
    }

    return machine_data

def export_to_pdf(machine_data):
    pdf_file = canvas.Canvas("machine_data.pdf", pagesize=letter)

    textobject = pdf_file.beginText()
    textobject.setTextOrigin(50, 700)

    for key, value in machine_data.items():
        textobject.textLine(key + ': ' + value)

    pdf_file.drawText(textobject)
    pdf_file.save()

root = Tk()
root.geometry("300x200")

def gather_and_export_data():
    machine_data = get_machine_data()
    export_to_pdf(machine_data)

button = Button(root, text="Export Machine Data to PDF", command=gather_and_export_data)
button.pack()

root.mainloop()
