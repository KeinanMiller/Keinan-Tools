using System;
using System.Drawing;
using System.Windows.Forms;

namespace ClipboardCopier
{
    public partial class MainForm : Form
    {
        private NotifyIcon notifyIcon;
        private ContextMenuStrip contextMenu;
        private ToolStripMenuItem exitMenuItem;

        public MainForm()
        {
            InitializeComponent();
            InitializeTrayIcon();
            RegisterHotKey(this.Handle, 0, (int)Keys.Control | (int)Keys.Alt, (int)Keys.R);
        }

        private TextBox inputTextBox;

        private void InitializeComponent()
        {
            this.inputTextBox = new System.Windows.Forms.TextBox();
            this.SuspendLayout();
            // 
            // inputTextBox
            // 
            this.inputTextBox.Location = new System.Drawing.Point(12, 12);
            this.inputTextBox.Name = "inputTextBox";
            this.inputTextBox.Size = new System.Drawing.Size(260, 20);
            this.inputTextBox.TabIndex = 0;
            // 
            // MainForm
            // 
            this.ClientSize = new System.Drawing.Size(284, 45);
            this.Controls.Add(this.inputTextBox);
            this.Name = "MainForm";
            this.ShowInTaskbar = false; // Hide from taskbar
            this.Text = "Clipboard Copier";
            this.WindowState = FormWindowState.Minimized; // Start minimized
            this.Load += new System.EventHandler(this.MainForm_Load);
            this.ResumeLayout(false);
            this.PerformLayout();
        }

        private void InitializeTrayIcon()
        {
            // Create NotifyIcon
            this.notifyIcon = new NotifyIcon();
            this.notifyIcon.Icon = SystemIcons.Application; // You can change this to a custom icon
            this.notifyIcon.Text = "Clipboard Copier";
            this.notifyIcon.Visible = true;

            // Create Context Menu
            this.contextMenu = new ContextMenuStrip();
            this.exitMenuItem = new ToolStripMenuItem("Exit");
            this.exitMenuItem.Click += new EventHandler(ExitMenuItem_Click);
            this.contextMenu.Items.Add(this.exitMenuItem);

            // Assign Context Menu to NotifyIcon
            this.notifyIcon.ContextMenuStrip = this.contextMenu;
        }

        // ... (Rest of the code for hotkey registration and handling remains the same) ...

        private void MainForm_Load(object sender, EventArgs e)
        {
            this.Hide(); // Hide the main form on load
        }

        private void ExitMenuItem_Click(object sender, EventArgs e)
        {
            // Clean up and close the application
            this.notifyIcon.Visible = false;
            Application.Exit();
        }
    }

    // ... (Program class remains the same) ...
}