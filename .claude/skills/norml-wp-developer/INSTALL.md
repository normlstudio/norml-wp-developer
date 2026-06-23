# Install norml-wp-developer

You don't really install this by hand — you paste a prompt and **Claude Code
installs it for you**. One-time skill install, then a ~30-minute setup the first
time you point it at a project (see `onboarding.md`). macOS and Windows.

> The visual version of this page is `install.html` — open it in a browser for
> copy-buttons on every prompt.

## Prerequisites

- **macOS** 12+ or **Windows** 10+ (WSL recommended on Windows)
- **Claude Code** installed and signed in → https://claude.com/claude-code
- **Git** installed and configured (`git config user.name`, `user.email`)
- **A local WordPress environment.** Default: WP Local (https://localwp.com).
  Alternates recognized: DDEV, Lando, Local Lightning, Valet+, MAMP. At least one
  must be running before you finish project setup.
- **SSH access to your production WordPress server** (host, port, username, key —
  or willingness to generate one and add it to the server). Managed hosts: usually
  under "SSH Keys" in the panel.
- **A remote Git repo.** GitHub by default (Bitbucket / GitLab supported). An empty
  repo, or push access to an existing one.
- **WP-CLI on the production server.** Most managed hosts have it; otherwise see
  https://wp-cli.org/#installing or ask your host.

> **No backups are provided by this skill.** It assumes the production host has
> automatic backups on, or that you take manual backups before destructive
> operations. The deploy commands refuse to run without an explicit "I have a
> backup" acknowledgement.

## Fastest — one paste

Unzip the package, open **Claude Code with the extracted folder as its working
directory**, and paste this. Claude installs the skill and then walks you through
your first project — no terminal needed.

```text
You're in the extracted norml-wp-developer package folder. Install this Claude skill for me, then help me set up my first project.

1. Copy the folder ".claude/skills/norml-wp-developer" from here into "~/.claude/skills/" (create ~/.claude/skills/ if it doesn't exist).
2. If I'm on macOS, make its scripts executable: chmod +x ~/.claude/skills/norml-wp-developer/scripts/*.sh  (skip this on Windows).
3. Confirm the norml-wp-developer skill is installed and you can see it.

Then walk me through onboarding for my first WordPress project: ask me for the theme folder, detect my local WP, initialize Git and wire the remote, collect SSH access through the native OS dialog (never ask me to type a secret in chat), pick a CI/CD pattern with me, and scaffold the .claude/ folder in the repo.
```

Restart Claude Code once afterward so it loads the new skill. Prefer to go step by
step (or run it in a terminal)? Read on.

## Step by step

### Step 1 — Extract the package

If you received this as a zip, unzip it anywhere convenient (Desktop or Downloads),
then open Claude Code with that folder as its working directory.

### Step 2 — Install the skill

Paste this prompt — Claude copies the skill into place and verifies it:

```text
Copy the folder ".claude/skills/norml-wp-developer" from this package into "~/.claude/skills/" (create the folder if needed). If I'm on macOS, then run: chmod +x ~/.claude/skills/norml-wp-developer/scripts/*.sh. Afterward, confirm the norml-wp-developer skill is installed and visible.
```

Or run it yourself in a terminal:

**macOS**
```bash
mkdir -p ~/.claude/skills
cp -R "/path/to/extracted/norml-wp-developer/.claude/skills/norml-wp-developer" ~/.claude/skills/
chmod +x ~/.claude/skills/norml-wp-developer/scripts/*.sh
```

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills" | Out-Null
Copy-Item -Recurse -Force "C:\path\to\extracted\norml-wp-developer\.claude\skills\norml-wp-developer" "$env:USERPROFILE\.claude\skills\"
```

Then restart Claude Code so it picks up the new skill. Confirm with *"List my
available skills"* — you should see `norml-wp-developer`.

### Step 3 — Set up your first project

Navigate Claude Code to your theme folder, then paste:

```text
Set up this WordPress project for norml-wp-developer. Walk me through onboarding: detect my local WP environment, initialize Git and wire the remote, collect SSH access to production through the native OS dialog (no secrets in chat), pick a CI/CD pattern with me, and scaffold the .claude/ folder inside my theme repo. Optionally pull the production database down to local at the end.
```

Claude pops **native OS dialogs for SSH passphrases** — you never type a secret into
the terminal. The full step-by-step is in `onboarding.md`.

Prefer to drive the script directly?

**macOS**
```bash
bash ~/.claude/skills/norml-wp-developer/scripts/setup-macos.sh
```

**Windows**
```powershell
& "$env:USERPROFILE\.claude\skills\norml-wp-developer\scripts\setup-windows.ps1"
```

### Repeat step 3 for every project

Each project gets its own `~/.config/norml-wp-developer/projects/{slug}.json` and its
own `.claude/` folder in its theme repo. You can manage many projects from one
machine — they share the SSH agent, not the config.

## Start building

Once setup finishes, paste any of these into Claude Code:

- *"add a hero block to this theme"*
- *"build a CPT archive for case studies"*
- *"what plugins are active on production? on staging?"*
- *"pull the production database to my local"*
- *"ship this branch to staging"*
- *"promote staging to production"* — gated by the backup prompt
- *"show me the recent changelog for this project"*

## Troubleshooting

| Problem | Fix |
|---|---|
| Claude can't see the skill | Restart Claude Code. Confirm the folder is at `~/.claude/skills/norml-wp-developer/`. |
| `Permission denied (publickey)` during setup | Your SSH public key isn't on the production server. Re-run setup; the script prints the public key for you to paste into your host's panel. |
| `wp: command not found` on the remote | WP-CLI isn't on the server. Ask your host or install per https://wp-cli.org/#installing. |
| `Composer detected ... platform_check.php` | Server PHP is below what the theme's `composer.json` requires. Bump server PHP in the panel, or lower the theme's `require.php` floor. |
| Setup script won't run on Windows | Run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` in PowerShell first. |
| WP Local site not detected | Make sure the site is **running** (green status in WP Local). Detection looks for an active MySQL process matching `/Local Sites/`. |
| `git push` rejected (no remote auth) | Configure GitHub auth. The setup script offers `gh auth login`, the easiest path. |

If you get stuck, contact whoever sent you this package.

## What's NOT installed

For full transparency, the skill writes only these things on your machine:

- The skill folder at `~/.claude/skills/norml-wp-developer/`
- Per-project config at `~/.config/norml-wp-developer/projects/{slug}.json` (no secrets)
- A per-project SSH config alias in `~/.ssh/config` (host alias only — the key file
  stays wherever you keep it)
- One entry per project in macOS Keychain / Windows Credential Manager for the SSH
  passphrase (if any)
- A `.claude/` folder INSIDE each theme repo it initializes (in git; travels with
  the code)
- A first commit on the theme repo if it wasn't already a git repo

It does **not** install system services, daemons, PowerShell modules, Python
packages, or Node packages. It does **not** modify your WordPress install beyond
`rsync`ing theme files and (optionally) running WP-CLI cache flushes after deploy.
And it does **not** make backups for you.

## Updating later

When a new version of the skill is sent to you:

1. Re-extract the package and re-run step 2 (the copy) — it overwrites the old skill
   folder. (Or just paste the install prompt again.)
2. Your config in `~/.config/norml-wp-developer/` is **not** touched — you keep your
   project list, SSH aliases, and per-project knowledge.
3. The `.claude/` folder inside each theme repo is **not** touched — it lives in git
   and travels with the code.
