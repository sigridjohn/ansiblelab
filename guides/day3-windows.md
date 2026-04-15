# Day 3 — Windows & Active Directory Setup Guide

You receive this guide on **Day 3 morning** along with the Windows VM
connection details from your instructor.

Do not start this guide until you have the VM details in hand.

---

## What You're Connecting To

A Windows Server 2022 VM pre-provisioned for the course. It is domain-joined
to `LAB.COURSE.LOCAL` and has WinRM enabled on ports 5985 (HTTP) and 5986 (HTTPS).

```
Your Laptop (control node)
    └── Ansible
            ├── WinRM (NTLM)    → winlab01 — Module 12
            └── WinRM (Kerberos) → winlab01 — Module 14
```

---

## Part A — Module 12 Setup: WinRM via NTLM

This gets you connected quickly using local credentials so you can start
practising Windows modules before switching to Kerberos.

### Step 1 — Install pywinrm

```bash
pip3 install pywinrm
```

### Step 2 — Update Your Inventory

Open `inventory/lab.ini`. Find the `[windows]` section and replace
`WIN_VM_IP` with the IP address your instructor provided:

```ini
[windows]
winlab01 ansible_host=YOUR_VM_IP_HERE
```

### Step 3 — Set the Windows Password

Open `inventory/group_vars/windows/vault.yml` and replace the placeholder:

```yaml
ansible_password: "THE_PASSWORD_FROM_YOUR_INSTRUCTOR"
```

Then encrypt it:

```bash
ansible-vault encrypt inventory/group_vars/windows/vault.yml
```

You'll be prompted to set a vault password. Use something you'll remember —
you'll need it every time you run a playbook targeting Windows today.

### Step 4 — Test Connectivity

```bash
ansible windows -m win_ping --ask-vault-pass
```

**Expected output:**
```
winlab01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**If it works — you're ready for Module 12.**

---

## Part B — Module 14 Setup: Kerberos Authentication

Complete this during or before Module 14. It requires a few extra packages
on your control node.

### Step 1 — Install Kerberos Libraries

**macOS:**
```bash
brew install krb5
export PATH="/usr/local/opt/krb5/bin:$PATH"   # add to ~/.zshrc to make permanent
pip3 install pywinrm[kerberos]
```

**Ubuntu/Debian (or WSL2):**
```bash
sudo apt install -y krb5-user python3-dev libkrb5-dev gcc
pip3 install pywinrm[kerberos]
```

When apt prompts for the default Kerberos realm, enter: `LAB.COURSE.LOCAL`
When prompted for the KDC, enter the IP your instructor provided.

**Windows/WSL2:** Use the Ubuntu/Debian steps inside your WSL2 terminal.

### Step 2 — Configure krb5.conf

Copy the template from the lab repo and fill in the KDC IP:

```bash
# macOS
sudo cp guides/krb5.conf.template /etc/krb5.conf

# Linux / WSL2
sudo cp guides/krb5.conf.template /etc/krb5.conf
```

Then edit `/etc/krb5.conf` and replace `LAB_KDC_IP` with the domain
controller IP your instructor provided.

### Step 3 — Verify Kerberos Works

```bash
kinit svc-ansible@LAB.COURSE.LOCAL
```

Enter the domain service account password when prompted (provided by instructor).

Then check the ticket was issued:
```bash
klist
```

You should see a valid ticket for `svc-ansible@LAB.COURSE.LOCAL`. If you do,
Ansible will be able to authenticate without any further setup.

Destroy the test ticket (Ansible will get its own):
```bash
kdestroy
```

### Step 4 — Update Inventory for Kerberos

Open `inventory/group_vars/windows/main.yml` and uncomment the Kerberos section:

```yaml
ansible_winrm_transport: kerberos
ansible_user: svc-ansible@LAB.COURSE.LOCAL
ansible_winrm_kerberos_delegation: false
```

Also update `inventory/group_vars/windows/vault.yml` (decrypt first, update
the password to the domain service account password, re-encrypt):

```bash
ansible-vault decrypt inventory/group_vars/windows/vault.yml
# Edit the file — replace ansible_password with the svc-ansible domain password
ansible-vault encrypt inventory/group_vars/windows/vault.yml
```

### Step 5 — Test Kerberos Auth

```bash
ansible windows -m win_ping --ask-vault-pass
ansible windows -m win_command -a "whoami" --ask-vault-pass
```

The `whoami` output should show `lab\svc-ansible` — confirming you are
authenticating as the domain service account, not the local admin.

---

## Troubleshooting

### win_ping fails: "connection refused" on port 5985
WinRM is not reachable. Check:
- Is the VM IP correct in your inventory?
- Can you ping the VM? `ping YOUR_VM_IP`
- WinRM firewall: your instructor needs to verify the rule is in place

### "kerberos: the specified credentials were rejected by the server"
- Clock skew: your laptop clock and the domain controller must be within 5 minutes. Check: `date` vs the VM clock.
- Wrong UPN format: must be `svc-ansible@LAB.COURSE.LOCAL` (uppercase domain)
- Try re-running `kinit svc-ansible@LAB.COURSE.LOCAL` and check `klist`

### "kinit: Cannot contact any KDC for realm LAB.COURSE.LOCAL"
- The KDC IP in `/etc/krb5.conf` is wrong or unreachable
- Verify with: `ping LAB_KDC_IP` — if it doesn't respond, tell your instructor

### "Failed to create temporary file ... Access is denied"
The svc-ansible account doesn't have write access to the temp directory.
Your instructor needs to verify the account's local permissions on the VM.

### pywinrm[kerberos] install fails on macOS
```bash
# Make sure Homebrew krb5 is linked
brew link --force krb5
export PATH="/usr/local/opt/krb5/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/krb5/lib"
export CPPFLAGS="-I/usr/local/opt/krb5/include"
pip3 install pywinrm[kerberos]
```

---

## Quick Reference — Windows Inventory Variables

| Variable | Module 12 Value | Module 14 Value |
|---|---|---|
| `ansible_connection` | `winrm` | `winrm` |
| `ansible_winrm_transport` | `ntlm` | `kerberos` |
| `ansible_port` | `5985` | `5985` |
| `ansible_user` | `labadmin` | `svc-ansible@LAB.COURSE.LOCAL` |
| `ansible_password` | local admin pass | domain svc account pass |
| `ansible_winrm_server_cert_validation` | `ignore` | `ignore` |
