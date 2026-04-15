# Instructor Operations Guide
## Ansible Course Lab — Delivery Reference

This guide covers everything you need to prepare and run the lab environment.
Keep it to yourself — it contains VM credentials and internal notes.

---

## Timeline

| When | Task |
|---|---|
| 2 weeks before | Provision Windows VM, run verification checklist |
| 1 week before | Send lab repo link and pre-work guide to participants |
| Day before | Verify all containers still build clean, confirm VM is reachable |
| Day 1 morning | 15 min buffer for pre-work stragglers |
| Day 3 morning | Distribute Day 3 connection details (do not send in advance) |

---

## Linux Lab Fleet — Instructor Notes

The Linux containers are entirely self-contained. Participants clone the repo,
run `docker-compose up -d`, and the fleet is live. Nothing to manage from your side.

**Common pre-work failure causes (in order of frequency):**

1. **Docker Desktop not running** — it's installed but not started. Fix: open Docker Desktop app.
2. **SSH key permissions** — `chmod 600 ssh/lab_key` fixes it every time.
3. **Wrong directory** — participant ran `ansible all -m ping` from the wrong folder.
4. **WSL2 without Docker integration** — Docker Desktop → Settings → Resources → WSL Integration.
5. **pip Ansible on PATH** — `pip3 install ansible` but `ansible` not found. PATH issue.

**If a container gets corrupted during the course:**
```bash
# Rebuild just that container (e.g., web01)
docker-compose stop web01
docker-compose rm -f web01
docker-compose up -d web01
```
This takes under 30 seconds and does not affect other containers.

**Full fleet reset (nuclear option):**
```bash
docker-compose down && docker-compose up -d --build
```
All containers return to pristine state. Participants lose any manual changes
they made inside containers (playbook-managed state rebuilds on next run).

---

## Windows VM — Provisioning Steps

### Recommended: Cloud VM (Azure)

**Provision (do this 2 weeks before the course):**

```powershell
# Azure CLI — create Windows Server 2022 VM
az vm create `
  --resource-group ansible-course-lab `
  --name winlab01 `
  --image Win2022AzureEditionCore `
  --admin-username labadmin `
  --admin-password "LabAdmin2024!" `
  --size Standard_B2s `
  --public-ip-sku Standard

# Open WinRM ports
az vm open-port --resource-group ansible-course-lab --name winlab01 --port 5985 --priority 100
az vm open-port --resource-group ansible-course-lab --name winlab01 --port 5986 --priority 101

# Get the public IP
az vm list-ip-addresses --resource-group ansible-course-lab --name winlab01 `
  --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv
```

**Then RDP into the VM and run the provisioning script:**
```powershell
# On the VM, from an elevated PowerShell:
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Provision-LabVM.ps1
```

**For Kerberos (Module 14), you also need:**
- The VM domain-joined to a lab AD domain (or a minimal AD DS install on the same or separate VM)
- DNS resolving `winlab01.lab.course.local` from participant control nodes

If you don't have an AD environment available, Module 14 can be run in
demonstration mode (instructor demonstrates, participants follow along
without executing) and the Kerberos content assessed through the
free-text assignment instead of a live exercise.

### Alternative: On-Premises VM

If running on-premises Hyper-V or VMware:
1. Deploy Windows Server 2022 from your standard template
2. Ensure participants can reach ports 5985 and 5986 from the training network
3. Run `Provision-LabVM.ps1` as above
4. Consider one VM per participant to avoid concurrent exercise conflicts

---

## Pre-Course Verification Checklist

Run through this 2–3 days before the course starts.

### Linux Fleet
- [ ] Fresh clone of the lab repo builds successfully: `docker-compose up -d --build`
- [ ] All 6 containers show `Up` in `docker-compose ps`
- [ ] `ansible all -m ping` returns SUCCESS for all 6 hosts
- [ ] SSH key permissions are `600` on `ssh/lab_key`
- [ ] `ansible all -m setup -a 'filter=ansible_distribution'` returns `Ubuntu`

### Windows VM
- [ ] VM is reachable: `ping WIN_VM_IP`
- [ ] WinRM HTTP responding: `Test-NetConnection WIN_VM_IP -Port 5985` (from any Windows machine)
- [ ] Local admin auth works:
  ```bash
  ansible windows -m win_ping -i "winlab01 ansible_host=WIN_VM_IP ansible_connection=winrm ansible_winrm_transport=ntlm ansible_port=5985 ansible_winrm_server_cert_validation=ignore ansible_user=labadmin ansible_password=LabAdmin2024!,"
  ```
- [ ] Chocolatey installed: RDP in, run `choco --version`
- [ ] `C:\deploy\` directory exists with correct permissions
- [ ] If using AD: `kinit svc-ansible@LAB.COURSE.LOCAL` works from your control node

---

## Day 3 Morning Checklist

Give participants the following at the start of Day 3 (Slack message or printed card):

```
Day 3 — Windows VM Connection Details

VM IP:               [YOUR_VM_IP]
WinRM port (HTTP):   5985
Local admin user:    labadmin
Local admin pass:    [YOUR_PASSWORD]

Domain:              LAB.COURSE.LOCAL
KDC IP:              [YOUR_DC_IP]
Domain service acct: svc-ansible@LAB.COURSE.LOCAL
Domain svc pass:     [YOUR_SVC_PASS]

Setup guide:         guides/day3-windows.md in your lab repo
```

**Do not send this before Day 3 morning.** Distributing credentials early
increases the chance of VM tampering before the course.

---

## If the Windows VM Goes Down Mid-Course

**Azure restart:**
```bash
az vm start --resource-group ansible-course-lab --name winlab01
```
Wait ~2 minutes then verify WinRM is responding before resuming.

**On-premises:** Restart via Hyper-V/vCenter console.

WinRM and all configuration survive a reboot — the provisioning script sets
everything as persistent.

If a participant's exercise has left the VM in a bad state (corrupted registry,
broken service, etc.), the fastest recovery is to snapshot-restore. If no
snapshot is available, re-run `Provision-LabVM.ps1` from an RDP session —
it is idempotent and safe to run again.

---

## Module-by-Module Instructor Notes

### Day 1

**Module 1 — How Ansible Works (Demo)**
Walk through `ansible all -m ping` live. Show the SSH connection in verbose
mode (`-vvv`) so participants can see the Python copy, execute, cleanup cycle.
This is the most important 10 minutes of the course — the mental model set here
persists through everything else.

**Module 3 — First Playbook**
Idempotency is the concept most beginners struggle with. Run the playbook twice
and contrast the `changed` vs `ok` counts explicitly. Ask the group: "Why did
nothing change on the second run? Is that a problem?"

**Day 1 Milestone**
Budget 45 minutes. Some participants will get there in 15; others will need
the full time. Encourage pairing on the milestone — the discussion of *why*
they structured it a certain way is more valuable than the code itself.

### Day 2

**Module 7 — Roles**
`ansible-galaxy role init` generates a lot of boilerplate. Walk through the
generated directory structure before participants start filling it in. The
confusion is almost always about the difference between `defaults/` and `vars/`.

**Module 9 — Vault**
Most participants will encrypt the vault file and then forget the vault password.
Suggest they write it on a sticky note for the lab (this is fine — lab, not prod).
The lesson is the workflow, not the password security of the training environment.

### Day 3

**Module 11 — AD Fundamentals**
Keep this tightly scoped to "what Ansible needs to know." Resist the pull into
a full AD lecture. Aim for 30–40 minutes including Q&A. The common questions:
- "Can Ansible manage AD objects?" → Yes, with win_domain_* modules, not covered today.
- "What about GPOs?" → Ansible can apply registry settings that mirror GPO effects but
  doesn't manage GPO objects directly.

**Module 12 — WinRM Setup**
This is the highest-risk module for participants getting stuck. If more than 2–3
participants can't reach the VM after 15 minutes, do a group troubleshooting
session before proceeding. Connection problems here block the rest of the day.

**Module 14 — Kerberos**
If AD / domain join is unavailable, run this as a demonstration + discussion.
The free-text assignment ("Why Kerberos vs NTLM? What are the prerequisites?")
still assesses the learning outcome without requiring a live exercise.

**Day 3 Milestone**
This is the hardest exercise of the course. Participants are combining everything
across three days in one role. Budget 60–75 minutes. The cross-platform
`include_tasks` pattern is where most participants get stuck — have a working
example ready to show (not give) if the group is stuck.

---

## Lab Repo Maintenance

When updating the lab repo between cohorts:
1. Regenerate the SSH keypair if the previous one was widely distributed
2. Update any package versions in the Dockerfile
3. Test a full build before the next cohort: `docker-compose down && docker-compose up -d --build`
4. Re-run the Windows VM provisioning script if reusing the same VM
