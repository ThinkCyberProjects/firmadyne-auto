# Firmadyne Automation for IoT Firmware Emulation

This project provides a fully working, automated setup and execution environment for Firmadyne, tailored for modern IoT firmware analysis.

## ⚡ Why This Exists

Most public Firmadyne forks are outdated, broken, or require complex setup steps that frustrate both beginners and experienced analysts. I built this system to:

- Actually work out of the box  
- Handle the full firmware emulation lifecycle  
- Be easy enough for students and labs, but powerful for real use  

Behind the scenes, this setup automatically takes care of:

- Installing all required dependencies (QEMU, Binwalk, PostgreSQL, etc.)
- Setting up the full Firmadyne environment
- Unpacking firmware (supports `.bin`, `.img`, `.zip`)
- Detecting architecture (MIPS, ARM, etc.)
- Generating emulation images and patching them
- Booting the firmware in QEMU with no manual steps

## ✅ Features

- Full automation of firmware extraction, analysis, and boot  
- Tested and working on Kali Linux (2023+)  
- Logs and cleanup handled automatically  
- Root login disabled on boot is bypassed automatically  
- SSH/HTTP detection and access through QEMU  
- Default PostgreSQL password is handled internally (`firmadyne`)  

## 🚀 How to Use

### 1. Clone the repository

```bash
git clone https://github.com/ThinkCyberProjects/firmadyne-auto.git
cd firmadyne-auto
2. Run the one-time setup script
bash
Copy
Edit
sudo bash Firmadyne_setup.sh
This will install everything and prepare the system. After setup, you’ll see:

css
Copy
Edit
[✔] Setup complete.
To run: sudo bash /opt/firmadyne/Firmadyne.sh
3. Run and emulate a firmware image
bash
Copy
Edit
sudo bash /opt/firmadyne/Firmadyne.sh
You’ll be prompted to:

Enter the full path to the firmware file

Enter a vendor name (any label you want)

Example:

text
Copy
Edit
Enter full path to firmware file: /home/kali/Desktop/firmware.zip
Enter the firmware vendor: netgear
The script will:

Extract the firmware

Detect architecture

Patch and build the filesystem

Boot it in QEMU automatically

🧠 Behind the Scenes (for those curious)
This tool automates every part of the Firmadyne pipeline:

Step	What It Does
Firmware extraction	Handles .bin, .zip, .img formats
Architecture check	Uses getArch.sh and ELF parsing to detect CPU type
Database setup	Inserts firmware into PostgreSQL for tracking
Image generation	Builds QEMU-compatible rootfs image
Patching	Disables root password, configures tty, etc.
Emulation	Boots QEMU with the correct options

All intermediate files and logs are saved in /opt/firmadyne.

🔐 Default PostgreSQL Access
Username: firmadyne

Password: firmadyne

This is configured automatically, so you won’t need to manually manage any DB settings.

🧼 Reset and Cleanup
To reset the system before running a new firmware image, just re-run the launcher:

bash
Copy
Edit
sudo bash /opt/firmadyne/Firmadyne.sh
It will:

Flush the database

Clean old image files

Reset the environment

🌐 After Booting
Once the firmware is running in QEMU:

Check open ports using nmap -p- 192.168.0.100

Try accessing services in your browser or terminal

Log in with known credentials or analyze the rootfs you extracted earlier

Example (accessing web interface):

cpp
Copy
Edit
http://192.168.0.100
📎 Requirements
This has been tested on:

Kali Linux (2023.1+)

Debian-based systems

Make sure your system supports:

QEMU

64-bit virtualization

📜 License
This project is released under the MIT License.

✍️ Author
Built and maintained by ThinkCyberProjects

This was made to simplify complex firmware emulation workflows for both training and real-world IoT research.

yaml
Copy
Edit

---

Let me know if you'd like me to auto-generate a `LICENSE` file (MIT), add example firmware URLs, or create a `.gitignore` file.







