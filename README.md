# AI-DLC Kit v2.5

**AI-Driven Development Lifecycle for every project and every AI agent, with a brain that learns.**
The agent analyzes, asks questions, thinks the plan through, and waits for your approval. Only then does it
build, test, review and verify, following your architecture standard. After every task it writes down
what it learned, with proof, and reads those lessons before the next task.

Works with **Claude Code**, **Google Antigravity**, **Gemini CLI**, **Gemini in Android Studio** and any
agent that reads `AGENTS.md`. Architecture standards: **Flutter house standard v3** (built from a production
app, with complete compile-checked code), **native Android** and **native iOS** (proposed), and a generic
standard generated from any other codebase.

```
 Your request
     │
     ▼
 Recall the brain ─► Route ─► questions ─► plans (each one: think → draft → your approval)
                        ├─ New project: brief · business plan · requirements · integration plan · architecture · delivery plan
                        ├─ Feature / change: requirements · integration plan · implementation_plan.md
                        ├─ Bug fix: triage · root cause · bugfix_plan.md
                        └─ Release: release-plan.md
                                              │
                                              ▼  🛑 your approval
               build (live 🔄/✅ status) ─► tests ─► review ─► analyze · test · build ─► report
                                              │
                                              ▼
               reflect: lessons with evidence ─► 🧠 your batch approval ─► brain (project + shared)
```

## What you get
- **Plan first, always.** No file changes without an approved plan. Claude Code enforces it with a hook.
- **Questions before every plan**, multiple choice with a ★ recommendation. Nothing is guessed.
- **New projects get a full analysis:** project brief, **business plan**, requirements, **integration plan**,
  architecture, delivery plan.
- **A thinking protocol** for every plan: options in a decision table, a pre-mortem, a self-review.
- **Research for big decisions:** official sources first, version-checked, saved and reused.
- **A self-learning brain:** 7 learning triggers, reflection after each task, lessons with evidence, your
  batch approval, a shared brain for all projects, and a scorecard that shows improvement.
- **A token optimizer:** every request becomes a short task brief (better results, less rework), a prompt
  rewriter (`/aidlc prompt`), an always-on token rule (read, run and write lean; one work item per session)
  and real token numbers per work item from Claude Code's own records (`tokens.sh`).
- **Flutter house standard v3:** your architecture, rebuilt from real code. It includes one interceptor +
  `ApiRequest` for API calls, a session manager, secure storage, safe routing, and complete core, feature and
  test code in `reference/` files next to the skill (opened only when needed). That code passes
  `flutter analyze` and 39 tests on Riverpod 2 and 3.
- **Plans that show how they work:** three diagrams (plan flow, file map, runtime flow) and How / Why /
  Check under every task, so you see the approach before you approve.
- **Your rules built in:** the 11-section `implementation_plan.md`, live status, gap analysis, build
  verification, code preservation, knowledge retention.

## Set up
Three steps. The scripts back up every file they change. What each step changes:
[GUIDE.md §2](GUIDE.md#2-quick-start).
```bash
# 1. Once per machine
cd aidlc-kit && bash install.sh

# 2. Once per project (use --dry-run first to preview; --migrate if you have old .agents rules)
bash ~/.aidlc-kit/init-project.sh ~/StudioProjects/MyApp

# 3. Commit the pack
cd ~/StudioProjects/MyApp && git add AGENTS.md CLAUDE.md GEMINI.md .agents aidlc-docs .gitignore && git commit -m "chore: add AI-DLC"
```
A new app in an empty folder: add `--standard flutter` (or `android`, `ios`) in step 2, because there is
nothing to detect yet.

## Use it
| Claude Code | Antigravity / Gemini | What happens |
|---|---|---|
| `/aidlc analyze` | "analyze this project" | Project analysis → `aidlc-docs/project-profile.md` |
| `/aidlc new-project <idea>` | "new project: <idea>" | Full inception with business and integration plans |
| `/aidlc feature <what>` | "new feature: <what>" | Questions → requirements → integration plan → implementation plan |
| `/aidlc bugfix <what>` | "fix bug: <what>" | Triage → root cause → bug-fix plan |
| `/aidlc release 1.2.0` | "prepare release 1.2.0" | Release plan → builds → hand-over |
| `/aidlc brain` · `learn` · `research <topic>` | "show the brain" · "reflect" · "research <topic>" | Brain stats, reflection, research notes |
| `/aidlc prompt <text>` · `/aidlc tokens` | "optimize prompt: <text>" | A clear, compact prompt for any AI tool · real token use of the session or a work item |
| `/aidlc` or `/aidlc status` | "status" / "continue" | Progress; resumes where the work stopped |

At every approval point, reply **approve** (or *proceed* / *go ahead* / *do it* / a plain *yes*), **change: …**
or **stop**.
For lessons: **approve lessons**, `approve L-12 L-13, reject L-14`, or `edit L-15: …`.

## What's inside
```
aidlc-kit/
├── install.sh · init-project.sh · remove-project.sh · uninstall.sh · brain.sh · tokens.sh · VERSION
├── README.md · GUIDE.md · CHANGELOG.md · FLUTTER-STANDARD-V3-ANALYSIS.md
├── pack/                       → copied into each project
│   ├── AGENTS.md · CLAUDE.md · GEMINI.md          entry blocks for each agent
│   └── .agents/
│       ├── rules/              00-aidlc-core · 10-quality-gates · 30-learning · 40-token-efficiency (always on)
│       ├── skills/             project-analysis · aidlc-new-project · aidlc-feature · aidlc-bugfix · aidlc-construction
│       │                       aidlc-release · aidlc-think · aidlc-reflect · aidlc-research · aidlc-prompt
│       └── templates/          23 templates (plans, reports, brain, research, question bank, …)
├── standards/                  flutter (v3 + reference/ code) · android · ios · generic → project-architecture skill + 20-architecture rule
├── brain/                      shared-brain starter: 27 verified lessons (updates refresh the ones you never edited)
├── claude/                     Claude Code: /aidlc · aidlc-reviewer · hooks (plan gate, session, auto-format, learning hint) · doctor
├── global/                     plan-first rules for ~/.claude/CLAUDE.md and ~/.gemini/GEMINI.md
├── lib/kit.sh                  shared script helpers
└── tests/                      run-tests.sh (320 checks) · flutter-standard-check.sh (compiles the Flutter standard)
```

## Settings (`~/.aidlc-kit/config` or environment variables)
| Setting | Values |
|---|---|
| `AIDLC_ENFORCE` | `project` (default) · `all-repos` · `off` |
| `AIDLC_GATE_SCOPE` | `plan-files` (default) · `any` |
| `AIDLC_AUTOFORMAT` | `new-files` (default) · `all` · `off` |
| `AIDLC_LEARN_HINTS` | `on` (default) · `off` |

## Common tasks
Replace `~/StudioProjects/MyApp` with your project folder.

**Check versions**
```bash
cat ~/.aidlc-kit/VERSION                                   # the kit on this machine
cat ~/StudioProjects/MyApp/.agents/.aidlc-version          # the pack in a project (version + standard)
```

**Check that everything works** (machine and project; it says when a project's pack is older than the kit).
In Claude Code: `/aidlc doctor`.
```bash
bash ~/.aidlc-kit/claude/bin/doctor.sh ~/StudioProjects/MyApp
```

**Update the kit** (a newer `aidlc-kit` folder). Your settings and shared brain are kept; starter lessons you
never edited are updated.
```bash
cd aidlc-kit && bash install.sh
```

**Update a project** to the kit's version. Kit files are updated (your edits backed up); your own files are
kept. Preview first, then run it without `--dry-run`, then commit.
```bash
bash ~/.aidlc-kit/init-project.sh ~/StudioProjects/MyApp --dry-run
```
Add `--migrate` to archive old workflow rules (like `agent-workflow.md`), `--standard flutter` for a new app
in an empty folder, or `--update-architecture` to switch the project to the kit's architecture standard
(your current one is archived first).

**Remove AI-DLC from a project.** It removes the AI-DLC blocks in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`
(your own text stays), the kit's files in `.agents/`, the state file and the `.gitignore` lines. It keeps
your architecture standard, archived old files and `aidlc-docs/` work (add `--all` to remove those too), and
copies everything to `~/.aidlc-kit/backups/` first. Preview, then run without `--dry-run`, then commit.
```bash
bash ~/.aidlc-kit/remove-project.sh ~/StudioProjects/MyApp --dry-run
```

**Uninstall from this Mac** (remove it from your projects first if you want that). It removes `/aidlc`, the
reviewer agent, the hooks, the global rules and `~/.aidlc-kit`; your shared brain and settings are saved.
```bash
bash ~/.aidlc-kit/uninstall.sh
```

**See token use** (Claude Code; the latest session, or `--work-item <id>`). In Claude Code: `/aidlc tokens`.
```bash
bash ~/.aidlc-kit/tokens.sh ~/StudioProjects/MyApp
```

**The brain:** `bash ~/.aidlc-kit/brain.sh stats|lint|sync ~/StudioProjects/MyApp` (lessons, checks,
sharing). In Claude Code: `/aidlc brain`.

**Pause the plan gate for one Claude Code session:** start it with `AIDLC_ENFORCE=off claude`. To change it
for good, edit `~/.aidlc-kit/config` (see Settings).

**Test the kit itself:** `bash tests/run-tests.sh` and `bash tests/flutter-standard-check.sh` (in the kit
folder).

Read **[GUIDE.md](GUIDE.md)** for the full workflow, the brain, examples and troubleshooting, and
**[CHANGELOG.md](CHANGELOG.md)** for what changed in each version.
