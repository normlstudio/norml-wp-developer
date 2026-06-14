# norml-wp-developer — Onboarding

Run this **once per project**. After this, the project is wired up:
local WP environment, Git repo, GitHub remote, SSH access to staging
and production, CI/CD pattern selected, `.claude/` scaffolded inside
the theme repo. Setup takes ~30 minutes. After it's done, building +
deploying is fast and pleasurable.

> **The easiest way to onboard is just to ask Claude.** Open Claude
> Code in the project folder and say *"set up this project for
> norml-wp-developer."* Claude walks you through it in chat — popping
> native OS dialogs for any secret entry. You never type SSH passphrases
> or GitHub tokens into a terminal.

## Why onboarding has multiple steps

The skill needs to learn a lot about your project before it can safely
build + deploy:

1. **Local WordPress environment** — where the theme lives on disk,
   what local URL it runs at, what database it uses.
2. **Git state** — is this a git repo? If not, init it. Is there a
   remote? If not, create one (GitHub by default).
3. **SSH access to production** — host, port, username, key path,
   passphrase (if any), WordPress path on the server.
4. **(Optional) SSH access to staging** — same details, second
   environment.
5. **CI/CD pattern** — full pipeline (staging → prod), prod-direct
   with git, or prod-direct with rsync. The choice depends on how the
   site is hosted and how much risk tolerance you have.
6. **Project mode** — is this a new Sage theme (Norml-authored), or
   an inherited theme (someone else built it, you're picking it up)?
   The conventions Claude follows differ.
7. **(Optional) First architecture scrape** — Claude SSHes into the
   production server, runs `wp plugin list`, `wp theme list`, etc., and
   writes a 5-file architecture snapshot under `.claude/docs/`.

The setup script handles all seven. You can skip optional steps; they
can be filled in later.

## Prerequisites

Re-confirmed from `INSTALL.md`:

- Local WordPress environment installed and running (WP Local
  recommended)
- The theme folder exists locally (the folder containing `style.css`
  with a `Theme Name:` header and `functions.php`)
- Git installed; `git config user.name` and `user.email` set
- SSH access to the production server, or willingness to add a public
  key to it
- A remote Git repo (empty or existing) — GitHub by default
- WP-CLI on the production server (verify by SSHing in and running
  `wp --info`)
- ~30 minutes

## Steps

### Step 1 — Open a terminal in the theme folder

Navigate to the theme folder. For WP Local users on macOS:

```bash
cd ~/Local\ Sites/{site}/app/public/wp-content/themes/{theme}
```

Confirm with:

```bash
ls style.css functions.php
```

If both exist, you're in the right place.

### Step 2 — Run the setup script

**macOS:**
```bash
bash ~/.claude/skills/norml-wp-developer/scripts/setup-macos.sh
```

**Windows:**
```powershell
& "$env:USERPROFILE\.claude\skills\norml-wp-developer\scripts\setup-windows.ps1"
```

### Step 3 — Answer the project-level prompts

| Prompt | Example | Notes |
|---|---|---|
| Project slug | `acme-marketing` | Kebab-case. Used for the config file and SSH alias. |
| Production URL | `https://acme.com` | The live URL, no trailing slash. |
| Project mode | `sage` or `inherited` | Default `inherited` if uncertain — safer. |
| Theme name | (read from `style.css`) | Confirms the script is in the right folder. |

### Step 4 — Local environment detection

The script looks for a running local WP at the current path. It
recognizes:

- WP Local (Flywheel) — `~/Local Sites/...`
- DDEV — `.ddev/config.yaml` in a parent folder
- Lando — `.lando.yml` in a parent folder
- Valet+ — current folder is a `valet park`ed root
- Local Lightning — same as WP Local

If detected: the script captures the local URL and DB credentials from
the environment.

If not detected: the script asks for the local URL manually and assumes
you'll handle DB credentials when you need them.

### Step 5 — Git setup

If the theme folder isn't already a git repo:

- `git init`
- `.gitignore` scaffolded with sensible WordPress defaults
- First commit made (`chore: initial commit` with `style.css`,
  `functions.php`, and whatever else is already in the folder)

If it IS a git repo: the script confirms the current branch and that
the working tree is clean, then proceeds.

### Step 6 — Remote setup

The script asks which remote provider:

- **GitHub** (default) — needs either GitHub CLI (`gh auth login`) or
  a Personal Access Token. The script offers to install `gh` via
  Homebrew (macOS) or winget (Windows) if missing.
- **Bitbucket** — needs your Bitbucket username + App Password.
- **GitLab** — needs your GitLab Personal Access Token.

Then asks:

- Does a remote repo exist? If yes, the URL. If no, the script can
  create one (private by default).

The remote is added to git as `origin` and the current branch is
pushed.

### Step 7 — SSH details for production

The script collects:

| Field | Example |
|---|---|
| SSH host | `ssh.acme.com` or `203.0.113.4` |
| SSH port | `22` (default), some hosts use `2222` |
| SSH username | `acme` |
| SSH key path | `~/.ssh/id_ed25519` or `~/.ssh/norml-wp-dev-{slug}` if generating |
| WordPress path on server | `/home/acme/public_html` or `/var/www/html` |

If you don't have an SSH key already, the script generates one
(`ed25519`, stored at `~/.ssh/norml-wp-dev-{slug}`) and **prints the
public key**. You paste the public key into your host's "SSH Keys"
panel.

### Step 8 — Passphrase + ssh-agent (via OS dialog)

If your SSH key has a passphrase, a native OS dialog opens to collect
it once. The passphrase goes into:

- **macOS Keychain** via `ssh-add --apple-use-keychain` — from then
  on, `ssh` reads it silently.
- **Windows ssh-agent** (DPAPI-backed) — same idea.

You never paste the passphrase into a terminal. Claude never sees the
value.

### Step 9 — Optional: staging

If your project has a staging environment, the script collects the same
SSH details for it. If not, skip — staging-less projects work too,
they just have fewer deploy options.

### Step 10 — CI/CD pattern selection

Three supported patterns:

| Pattern | When | What it does |
|---|---|---|
| `full-pipeline` | Recommended. Staging gates production. | `.github/workflows/staging.yml` deploys on push to `main` or `develop`; production deploys on git tag. Smoke tests after each. |
| `prod-direct-with-git` | Single env, no staging, git as safety net. | Push to `main` rsyncs to production. Backup-acknowledgement before each. |
| `prod-direct-no-ci` | Smallest sites, no CI/CD at all. | `rsync` over SSH on-demand from local. Backup-acknowledgement before each. |

The script writes the chosen pattern into the project's `.claude/ci-cd.md`
and (for `full-pipeline` and `prod-direct-with-git`) scaffolds the
GitHub Actions workflows in `.github/workflows/`.

### Step 11 — Scaffold `.claude/` inside the theme repo

The script creates:

```
{theme_root}/.claude/
├── CLAUDE.md          (project overview, mode, URLs, deploy hints)
├── ci-cd.md           (the pattern from Step 10, with command details)
├── changelog/
│   ├── README.md      (rolling three-tier protocol)
│   ├── daily.md       (empty, today's date)
│   ├── weekly.md      (empty)
│   └── changelog.md   (empty)
├── docs/              (empty, filled by Step 12 if you opt in)
└── skills/            (empty, for project-specific skills)
```

This folder is **committed to git** as part of the same first commit
(or appended as a follow-up commit on existing repos).

### Step 12 — Optional: first architecture scrape

The script offers to SSH into production and run a read-only architecture
scrape — `wp plugin list`, `wp theme list`, `wp post-type list`,
`wp option get template/stylesheet/blogname`, etc. — and write the
result to `.claude/docs/01-infrastructure.md` through
`.claude/docs/05-issues.md`.

Skip this if production isn't ready, or if you'd rather do it later
("rescan architecture" in a Claude session).

### Step 13 — Verify

The script runs:

- `ssh {alias} echo ok` against production (and staging if configured)
- `git status` against the local repo (should be clean)
- `git remote -v` to confirm the remote is wired
- A quick "what would deploy do?" dry-run for the chosen pattern

If all four pass, setup is complete.

## After setup — typical first session

```
You:    "I want to add a hero block with an ACF field group."
Claude: (reads .claude/CLAUDE.md → mode: inherited)
Claude: (reads references/dev-conventions.md → Inherited section)
Claude: (reads .claude/changelog/daily.md → nothing yet)
Claude: "I see this is an inherited theme — I'll follow the existing
        section/component/partial structure. Here's the plan: ..."
```

```
You:    "Ship this to staging."
Claude: (reads .claude/ci-cd.md → pattern: full-pipeline)
Claude: "Running `npm run build`, committing, pushing to develop —
        that triggers the staging workflow. I'll watch the run."
```

```
You:    "Promote staging to prod."
Claude: (gated)
Claude: "Promoting to production requires a backup acknowledgement.
        Please confirm: 'I have a backup from {date}.' Default is
        abort."
```

## Verification

In Claude Code, ask:

> *"What's the deploy pattern for this project?"*

Claude should read `.claude/ci-cd.md` and tell you. If it asks you to
run onboarding, the project's config file is missing — re-run setup.

> *"Show me the recent changelog for this project."*

Claude reads `.claude/changelog/daily.md`. After your first session it
should have a `[CODE]` entry from setup ("project initialized").

## Troubleshooting

**`Permission denied (publickey)` against production**
Your public key isn't on the server. Re-run setup; copy the public key
into your hosting control panel (Kinsta → Sites → SSH Keys, WP Engine
→ User Portal → SSH, etc.).

**`No GitHub auth configured`**
Run `gh auth login` and pick "Login with web browser." Then re-run
setup; the script picks up the gh-cached token automatically.

**`Could not open a connection to your authentication agent`**
SSH agent isn't running.
- macOS: `eval "$(ssh-agent -s)"`
- Windows (PowerShell, may need admin):
  ```powershell
  Set-Service ssh-agent -StartupType Automatic
  Start-Service ssh-agent
  ```

**`Composer platform_check.php` failure**
Server PHP version is below the theme's required version. Either bump
PHP in the hosting panel or lower the theme's `require.php` floor
(developer task).

**WP Local site not detected**
Make sure the site is running (green dot in WP Local). The detection
script looks for an active mySQL process. Open the site once in WP
Local to start it.

**`wp: command not found` over SSH**
WP-CLI isn't on the server. Most managed hosts have it pre-installed;
if yours doesn't, install per https://wp-cli.org/#installing or ask
your host.

## Rotation / revoke

To rotate the SSH key (lost laptop, contractor leaving):

1. Remove the public key from `~/.ssh/authorized_keys` on the server
   (or in the host's panel).
2. Delete the local key files:
   ```bash
   rm ~/.ssh/norml-wp-dev-{slug} ~/.ssh/norml-wp-dev-{slug}.pub
   ```
3. Remove the passphrase from Keychain / Credential Manager:
   - macOS: Keychain Access → search for `{slug}` → delete the entry
   - Windows: `cmdkey /delete:norml-wp-dev-{slug}`
4. Re-run onboarding to generate a fresh key.

To rotate the GitHub PAT: revoke the old one at
`github.com/settings/tokens`, then re-run `gh auth login` or re-run
this onboarding flow.

## What gets written to disk

| File | What it holds | Permissions |
|---|---|---|
| `~/.config/norml-wp-developer/projects/{slug}.json` | **Per-project config.** Theme path, production URL, SSH alias, remote URL, deploy pattern, local-env details. **No secrets.** | `600` (macOS) |
| `{theme_root}/.claude/CLAUDE.md` | **Project overview.** Mode, URLs, pointers. Committed to git. | default |
| `{theme_root}/.claude/ci-cd.md` | **Per-project deploy contract.** Pattern, commands, hooks. Committed to git. | default |
| `{theme_root}/.claude/changelog/*.md` | **Rolling changelog.** Daily / weekly / long-term. Committed to git. | default |
| `{theme_root}/.claude/docs/*.md` | **Architecture scrape (optional).** Committed to git. | default |
| `{theme_root}/.github/workflows/*.yml` | **CI/CD workflows** (if pattern is `full-pipeline` or `prod-direct-with-git`). Committed to git. | default |
| `~/.ssh/config` alias for the server | Host, port, user, key path. | `600` |
| `~/.ssh/norml-wp-dev-{slug}` | SSH private key (only if generated by setup; if you used existing key, the script doesn't touch it). | `600` |
| macOS Keychain entry / Windows Credential Manager target `norml-wp-dev-{slug}` | SSH passphrase (only if your key has one). | OS-managed |

The split: `~/.config/` is per-machine connection state; `{theme_root}/.claude/`
is portable project knowledge; the OS secret store is for secrets;
`~/.ssh/` is your normal SSH setup with one alias added.
