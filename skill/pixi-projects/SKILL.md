---
name: pixi-projects
description: Work with software repositories managed by Pixi using the bundled verified Pixi executable. Use when a repository contains pixi.toml, a Pixi workspace in pyproject.toml, pixi.lock, or the user asks to use Pixi for tasks, environments, dependency management, tests, linting, formatting, builds, benchmarks, or project commands. Prefer repository-defined Pixi tasks and environments, preserve an existing lockfile during ordinary validation, and use mutating Pixi commands only when project changes are intended.
---

# Pixi Projects

Use the bundled launcher at `scripts/pixi` as the Pixi executable. Do not assume a system `pixi` exists and do not replace the bundled executable with a network download.

## Workflow

1. Inspect the repository before running commands.
   - Look for `pixi.toml`, `pixi.lock`, and Pixi configuration in `pyproject.toml`.
   - Read the manifest and relevant project documentation to identify environments, tasks, supported platforms, and repository conventions.
   - Do not assume conventional task names exist.

2. Check the bundled Pixi executable.
   - Run `scripts/pixi --version` when first using the skill in a session or when diagnosing compatibility.
   - The launcher supports Linux x86-64 only, decompresses the bundled static Pixi binary into a writable cache, and verifies its pinned SHA-256 before execution.
   - If the launcher reports an unsupported platform or integrity failure, stop and report the failure. Do not silently fall back to another Pixi installation.

3. Discover repository tasks rather than guessing.
   - Use `scripts/pixi task list --summary` or `scripts/pixi task list`.
   - Inspect named environments when necessary with `scripts/pixi task list -e <environment>`.
   - Prefer repository-defined tasks such as `fmt`, `fmt-check`, `lint`, `test`, `check`, `build`, or benchmark tasks when they exist.
   - Prefer a project task over spelling out its underlying `cargo`, `python`, `pytest`, `ruff`, or other command directly.

4. Preserve repository state during ordinary execution.
   - If `pixi.lock` exists and the request is to test, inspect, lint, format-check, build, benchmark, reproduce, or otherwise validate existing code, run commands with `--locked` unless the repository explicitly documents another requirement.
   - Examples: `scripts/pixi run --locked test` and `scripts/pixi run --locked -e analysis python analysis/foo.py`.
   - Treat a stale lockfile failure as useful evidence. Do not silently rerun without `--locked` and update the lockfile.
   - If no lockfile exists, do not invent one merely to inspect the repository. If execution requires Pixi to create one, make that side effect explicit and inspect repository changes afterward.

5. Allow intentional project mutations when requested.
   - For requests that intentionally add, remove, upgrade, or update dependencies or workspace configuration, use the appropriate Pixi command without `--locked` and expect both manifest and lockfile changes as applicable.
   - Review the resulting diff and run the repository's validation tasks afterward.
   - Do not use `pixi global` as a substitute for declaring project dependencies.

6. Select the correct environment explicitly when the repository has multiple environments.
   - Use `scripts/pixi run -e <environment> ...` for commands associated with a non-default environment.
   - Infer the environment from task definitions, documentation, CI, or the user's command examples; do not choose arbitrarily when the distinction matters.

7. Finish by reporting what actually ran.
   - Summarize the Pixi task or command, environment, and whether locked mode was used.
   - Surface failures with enough command output to diagnose them.
   - If a command changed `pixi.toml`, `pyproject.toml`, or `pixi.lock`, call that out explicitly.

## Safety and reproducibility

- Never claim a Pixi command passed unless it was actually executed successfully.
- Do not bypass a failing Pixi task by invoking underlying host tools unless diagnosing the failure requires it; distinguish diagnostic commands from repository validation.
- Do not change channels, dependencies, platforms, environments, or lockfiles as a workaround unless the user's task calls for repository changes.
- Prefer the repository's checked-in conventions over generic Pixi conventions when they conflict.
