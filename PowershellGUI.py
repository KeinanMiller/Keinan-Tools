import os
import subprocess
import tkinter as tk
from tkinter import messagebox
from github import Github

# Replace this with your personal access token
GITHUB_ACCESS_TOKEN = "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"

def fetch_powershell_scripts(repo_url):
    repo_name = repo_url.split("github.com/")[-1].rstrip("/")
    github = Github(GITHUB_ACCESS_TOKEN)
    repo = github.get_repo(repo_name)
    contents = repo.get_contents("")
    
    ps_files = []
    for content in contents:
        if content.type == "file" and content.name.endswith(".ps1"):
            ps_files.append(content)
    
    return ps_files

def on_select(event):
    selected_script = listbox_scripts.get(listbox_scripts.curselection())
    run_script(selected_script)

def run_script(script_url):
    response = requests.get(script_url)
    if response.status_code == 200:
        with open("temp_script.ps1", "w") as f:
            f.write(response.text)
        
        process = subprocess.Popen(["powershell.exe", "temp_script.ps1"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, error = process.communicate()
        
        if process.returncode == 0:
            messagebox.showinfo("Success", "Script executed successfully")
        else:
            messagebox.showerror("Error", "Script execution failed")
    else:
        messagebox.showerror("Error", "Unable to download script")

root = tk.Tk()
root.title("PowerShell Script Runner")

frame = tk.Frame(root, padx=10, pady=10)
frame.pack()

label_repo = tk.Label(frame, text="GitHub Repository URL:")
label_repo.pack()

entry_repo = tk.Entry(frame, width=50)
entry_repo.pack()

button_fetch = tk.Button(frame, text="Fetch Scripts", command=lambda: fetch_scripts(entry_repo.get()))
button_fetch.pack()

listbox_scripts = tk.Listbox(frame, width=50, height=10)
listbox_scripts.pack()
listbox_scripts.bind("<<ListboxSelect>>", on_select)

label_status = tk.Label(frame, text="")
label_status.pack()

root.mainloop()
