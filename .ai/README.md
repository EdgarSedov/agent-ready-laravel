# Portable AI Assets

This folder is the tracked, vendor-neutral source for shared agent assets.

## What Belongs Here

- reusable skills in `.ai/skills/<name>/SKILL.md`
- optional tracked agent definitions or templates in `.ai/agents/`
- docs that explain how the repo expects agents to behave

## Local Install Targets

Use gitignored client-specific folders as install targets when you need them:

- `.agents/skills/`
- optional `.claude/`
- optional `.codex/`
- optional `.copilot/`

Typical pattern:

```bash
mkdir -p .agents/skills
ln -s ../../.ai/skills/bootstrap-current-checkout .agents/skills/bootstrap-current-checkout
ln -s ../../.ai/skills/worktree-lifecycle .agents/skills/worktree-lifecycle
```

Each tracked skill should follow the Agent Skills layout so Boost and OpenCode can both consume it:

```text
.ai/skills/<name>/SKILL.md
```

The tracked files remain canonical. Local targets are just discovery surfaces for a specific tool.
