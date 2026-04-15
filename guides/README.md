# Ansible Course Lab — Pre-Work Setup Guide

Complete this guide **before Day 1**. Estimated time: 45–60 minutes.

You need everything working before you arrive. If you get stuck, post in the
course Slack channel — don't leave it for the morning.

---

## What You're Setting Up

Your laptop becomes the **Ansible control node**. Six Docker containers running
Ubuntu 22.04 become your **managed fleet**. Ansible runs on your laptop and
connects to the containers over SSH — exactly how it works in production,
just locally.

```
Your Laptop (control node)
    └── Ansible
            ├── SSH → web01 (localhost:2201)
            ├── SSH → web02 (localhost:2202)
            ├── SSH → db01  (localhost:2203)
            ├── SSH → db02  (localhost:2204)
            ├── SSH → mon01 (localhost:2205)
            └── SSH → mon02 (localhost:2206)
```

---

## Step 1 — Install Ansible

### macOS
```bash
# Using pip (recommended — gives you the latest version)
pip3 install ansible

# Verify
ansible --version
```

### Linux (Ubuntu/Debian)
```bash
pip3 install ansible

# Or via apt (older version but works fine for this course)
sudo apt update && sudo apt install ansible -y

ansible --version
```

### Windows
Ansible's control node does not run natively on Windows. Use one of these:

**Option A — WSL2 (recommended):**
1. Install WSL2: `wsl --install` from an elevated PowerShell
2. Open the Ubuntu terminal that appears after restart
3. Run the Linux install steps above inside WSL2

**Option B — Git Bash / MSYS2:**
Not recommended — SSH key handling is unreliable. Use WSL2.

---

## Step 2 — Install Docker Desktop

Download Docker Desktop from **https://www.docker.com/products/docker-desktop**

- macOS: Download the `.dmg`, install, and start Docker Desktop
- Windows: Download the `.exe`, install. If prompted, enable WSL2 integration.
- Linux: Follow the Docker Engine install guide for your distro

**Verify Docker is running:**
```bash
docker --version
docker ps
```

`docker ps` should return an empty table (no error).

---

## Step 3 — Clone the Lab Repository

```bash
git clone https://github.com/[YOUR_ACADEMY]/ansible-course-lab
cd ansible-course-lab
```

The repo structure:
```
ansible-course-lab/
├── docker/
│   ├── docker-compose.yml    ← defines the 6 containers
│   └── Dockerfile            ← Ubuntu 22.04 with SSH + Python
├── inventory/
│   ├── lab.ini               ← your inventory file
│   ├── group_vars/           ← variables by group
│   └── templates/            ← Jinja2 templates for exercises
├── ssh/
│   ├── lab_key               ← private key (do not share)
│   └── lab_key.pub           ← public key (baked into containers)
└── guides/
    ├── README.md             ← this file
    └── day3-windows.md       ← Day 3 setup (given out on Day 3 morning)
```

---

## Step 4 — Start the Lab Fleet

```bash
# From the ansible-course-lab directory:
cd docker
docker-compose up -d
```

The first run downloads the Ubuntu base image and builds the containers.
This takes 2–5 minutes. Subsequent starts are instant.

**Verify all containers are running:**
```bash
docker-compose ps
```

You should see all six containers with status `Up`:
```
NAME      STATUS
web01     Up
web02     Up
db01      Up
db02      Up
mon01     Up
mon02     Up
```

---

## Step 5 — Fix SSH Key Permissions

The lab SSH private key must have strict permissions or SSH will refuse it:

```bash
# From the ansible-course-lab directory:
chmod 600 ssh/lab_key
```

---

## Step 6 — Configure ansible.cfg

Create an `ansible.cfg` file in the `ansible-course-lab` directory:

```ini
[defaults]
inventory          = ./inventory/lab.ini
private_key_file   = ./ssh/lab_key
remote_user        = labadmin
host_key_checking  = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

This file tells Ansible where to find your inventory and SSH key so you don't
need to pass them on every command.

---

## Step 7 — Verify Everything Works

Run the pre-work verification command from the `ansible-course-lab` directory:

```bash
ansible all -m ping
```

**Expected output — all green:**
```
web01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
web02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
db01  | SUCCESS => { ... "ping": "pong" }
db02  | SUCCESS => { ... "ping": "pong" }
mon01 | SUCCESS => { ... "ping": "pong" }
mon02 | SUCCESS => { ... "ping": "pong" }
```

**Take a screenshot of this output. You'll submit it as your pre-work assignment.**

---

## Troubleshooting

### "ssh: connect to host 127.0.0.1 port 2201: Connection refused"
The container isn't running. Check with `docker-compose ps` and restart with
`docker-compose up -d`.

### "WARNING: UNPROTECTED PRIVATE KEY FILE!"
The SSH key permissions are wrong. Run: `chmod 600 ssh/lab_key`

### "UNREACHABLE — Failed to connect to the host via ssh"
1. Confirm Docker Desktop is running (not just installed)
2. Confirm containers are up: `docker-compose ps`
3. Test SSH manually: `ssh -i ssh/lab_key -p 2201 labadmin@127.0.0.1`
   If this works, Ansible will work.

### "No inventory was parsed" or "provided hosts list is empty"
You're running `ansible` from the wrong directory. Run from `ansible-course-lab/`
where `ansible.cfg` is, or pass `-i inventory/lab.ini` explicitly.

### On Windows/WSL2 — "docker: command not found"
Open Docker Desktop settings → Resources → WSL Integration → enable for your
Ubuntu distro. Restart the WSL terminal.

### macOS — "ansible: command not found" after pip install
Add pip's bin directory to your PATH:
```bash
echo 'export PATH="$HOME/Library/Python/3.x/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
Replace `3.x` with your Python version (`python3 --version`).

---

## Stopping and Restarting the Lab

```bash
# Stop containers (data is preserved)
docker-compose stop

# Start them again
docker-compose start

# Stop and remove containers (fresh start next time)
docker-compose down

# Fresh start including rebuild
docker-compose down && docker-compose up -d --build
```

If something goes badly wrong, `docker-compose down && docker-compose up -d --build`
gives you a completely clean slate in about 3 minutes.

---

## Pre-Work Assignment

Once `ansible all -m ping` shows all six hosts returning `pong`:

1. Take a screenshot of the terminal output
2. Submit the screenshot via the course platform and mark the assignment complete

**If you can't get this working before Day 1, post in the course Slack channel
with the error message you're seeing. Do not arrive on Day 1 without a working
lab — the first exercises begin immediately.**
