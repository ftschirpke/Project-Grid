# Contributing

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org), in English, imperative mood,
lower case, no full stop:

```
<type>(<scope>): <summary>

<optional body: what changed and why, wrapped at 72 characters>
```

**Types**

| Type | For |
|---|---|
| `feat` | New gameplay, content or features |
| `fix` | Bug fixes |
| `balance` | Number changes only (health, damage, ranges, intervals) |
| `refactor` | Code changes without behaviour change |
| `test` | Tests only |
| `docs` | `DESIGN.md`, this file, comments |
| `chore` | Project setup, Godot settings, tooling |

**Scopes** (optional, one per commit, matching the code layout)

`rules` (turn and step resolution, `GameRules`), `abilities`, `enemies`, `tiles`,
`pickups`, `rooms`, `view`, `tests`, `design`.

Examples:

```
feat(abilities): add spear throw and spear thrust
balance(enemies): lower chaser health to 2
fix(view): show the turn counter after a restart
docs(design): record decisions from the second playtest
```

A change that touches several scopes and only makes sense as a whole (a new rule with its
data, tests and design notes) is one commit without a scope.

## Branches

`<type>/<short-kebab-description>`, using the commit types above, for example
`feat/two-move-turns`, `fix/projectile-swap`, `balance/boss-health`.
`main` always runs and passes the tests.

## Code and data

The existing conventions, kept for new files:

- Files and folders: `snake_case` (`chase_behavior.gd`, `spear_throw.tres`).
- Scripts: `class_name` in `PascalCase` matching the file (`ChaseBehavior`).
- Content ids: `snake_case` StringNames matching the file name (`id = &"spear_throw"`).
- Display names: English, title case (`"Spear Throw"`).
- Design decisions go into `DESIGN.md` with their status (`[Decided]`, `[Default]`) and,
  for later changes, the date.

## Before committing

```
godot --headless --path . --script res://tests/run_tests.gd
```

must end with `0 failed`.
