# Ansible Lab – Arkitektur och Struktur

Detta repository är designat för att demonstrera en realistisk Ansible-miljö där flera typer av noder (Linux, Windows, databaser, monitoring, etc.) hanteras via en central kontrollnod. Fokus ligger på hur komponenterna samverkar snarare än hur miljön sätts upp.

---

## Översikt

Arkitekturen bygger på klassiska Ansible-koncept:

* **Inventory** definierar vilka system som hanteras
* **Group variables** styr beteende per roll/hostgrupp
* **Playbooks** beskriver *vad* som ska göras
* **Roles** organiserar *hur* det görs
* **Templates** möjliggör dynamisk konfiguration
* **Docker** används för att simulera en distribuerad miljö

---

## Struktur och ansvar

### `ansible/` – kärnan i automationen

Detta är den centrala katalogen där all Ansible-logik bor.

#### `ansible.cfg`

Definierar globala inställningar för Ansible, t.ex.:

* vilken inventory som används som default
* var roller och templates finns
* SSH-beteende och anslutningsparametrar

Den fungerar som "runtime-konfiguration" för alla playbooks.

---

#### `inventory/`

##### `lab.ini`

Den statiska inventory-filen som definierar:

* hosts (t.ex. containrar eller VM:er)
* grupper (webservers, databases, windows, etc.)
* eventuella anslutningsparametrar (SSH, WinRM)

Denna fil är ingångspunkten som binder ihop infrastrukturen med Ansible.

---

##### `group_vars/`

Här definieras variabler kopplade till grupper i inventoryn.

Strukturen speglar grupperna i `lab.ini`, vilket gör att:

* variabler laddas automatiskt baserat på hostens grupptillhörighet
* logik kan hållas generisk i playbooks och roles

Exempel:

* `all/main.yml` → globala defaults
* `webservers/main.yml` → webbserverspecifika värden
* `databases/main.yml` → databaskonfiguration
* `windows/main.yml` → WinRM, autentisering etc.

###### `vault.yml`

Innehåller känsliga värden (lösenord, tokens), krypterade med **Ansible Vault**.
Separering av hemligheter från övrig konfiguration är en central best practice.

---

#### `playbooks/`

##### `site.yml`

Huvud-playbooken – fungerar som orchestration layer.

Typiskt ansvar:

* mappar hostgrupper → roller
* definierar körordning
* sätter globala parametrar per körning

Exempel på logik:

```yaml
- hosts: webservers
  roles:
    - web-role

- hosts: databases
  roles:
    - db-role
```

Denna fil är entrypointen vid exekvering och binder ihop hela systemet.

---

#### `roles/`

Roller är den primära abstraheringen för återanvändbar automation.

Exempel:

```
roles/
└── create-service-account/
    └── tasks/
        └── main.yml
```

En role kapslar:

* tasks (vad som görs)
* eventuella handlers
* defaults/vars
* templates
* files

I detta repo är strukturen avskalad men följer standardkonventionen:
`tasks/main.yml` fungerar som rollens entrypoint.

Roller anropas från playbooks och appliceras på specifika hostgrupper.

---

#### `templates/`

Jinja2-templates (`.j2`) används för att generera konfigurationsfiler dynamiskt.

Exempel:

* `motd.j2` → genererar systemets MOTD baserat på variabler
* `agent.conf.j2` → konfigurationsfil där värden injiceras från `group_vars`

Templates används typiskt via `template`-modulen i en role:

```yaml
- name: Render config
  template:
    src: agent.conf.j2
    dest: /etc/agent.conf
```

Detta möjliggör:

* miljöspecifika konfigurationer
* DRY-principen (ingen duplicering av statiska filer)

---

### `docker/` – simulerad infrastruktur

#### `Dockerfile`

Definierar basimagen för noderna:

* Ubuntu 22.04
* Python (krav för Ansible)
* SSH (för anslutning)

Varje container fungerar som en "host" i inventoryn.

---

#### `docker-compose.yml`

Orkestrerar flera containrar:

* skapar nätverk
* startar flera roller (web, db, etc.)
* exponerar portar vid behov

Denna del gör att labben kan köras lokalt men ändå efterlikna en distribuerad miljö.

---

### `windows/` – Windows-specifik hantering

Eftersom Windows inte använder SSH på samma sätt som Linux:

* PowerShell-script (`Provision-LabVM.ps1`) används för bootstrap
* `krb5.conf.template` används för Kerberos-autentisering

Detta kopplas till Ansible via WinRM och variabler i `group_vars/windows/`.

---

### `ssh/`

Dokumentation kring:

* nyckelhantering
* autentisering mellan kontrollnod och hosts

SSH är standardtransporten för Linux-noder i Ansible.

---

### `guides/`

Innehåller stödmaterial för labben, t.ex.:

* instruktörsguider
* specifika scenarion (t.ex. Windows-integration)

Dessa är separerade från kärnlogiken för att hålla repot modulärt.

---

## Hur allt hänger ihop

Förenklad exekveringskedja:

1. **Ansible startas via `site.yml`**
2. **Inventory (`lab.ini`) laddas**
3. **Hosts matchas mot grupper**
4. **Group variables (`group_vars/`) injiceras**
5. **Playbook applicerar roller på grupper**
6. **Roller exekverar tasks**
7. **Tasks använder templates + variabler**
8. **Konfiguration skrivs till målnoder**

---

## Designprinciper i repot

* **Separation of concerns**

  * inventory ≠ logik ≠ konfiguration ≠ hemligheter
* **Konvention över konfiguration**

  * Ansible laddar `group_vars` och `roles` automatiskt
* **Återanvändbarhet**

  * roller kan appliceras på flera hostgrupper
* **Deklarativ modell**

  * playbooks beskriver slutläge, inte steg-för-steg-skript

---

Denna struktur speglar hur större Ansible-miljöer organiseras i praktiken och ger en tydlig separation mellan infrastruktur, konfiguration och automation.
