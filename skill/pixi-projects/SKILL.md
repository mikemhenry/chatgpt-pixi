---
name: pixi-projects
description: Work with software repositories managed by Pixi using the bundled verified Pixi executable. Use when a repository contains pixi.toml, a Pixi workspace in pyproject.toml, pixi.lock, or the user asks to use Pixi for tasks, environments, dependency management, tests, linting, formatting, builds, benchmarks, or project commands. Prefer repository-defined Pixi tasks and environments, preserve an existing lockfile during ordinary validation, and use mutating Pixi commands only when project changes are intended.
---

# Pixi Projects

Use the bundled launcher at `scripts/pixi` as the Pixi executable. Invoke it as `sh scripts/pixi ...` because skill packaging may not preserve its executable bit. Do not assume a system `pixi` exists and do not replace the bundled executable with a network download.

## Workflow

1. Inspect the repository before running commands.
   - Look for `pixi.toml`, `pixi.lock`, and Pixi configuration in `pyproject.toml`.
   - Read the manifest and relevant project documentation to identify environments, tasks, supported platforms, and repository conventions.
   - Do not assume conventional task names exist.

2. Check the bundled Pixi executable.
   - Run `sh scripts/pixi --version` when first using the skill in a session or when diagnosing compatibility.
   - Always invoke the launcher through `sh scripts/pixi ...`; do not rely on the executable bit surviving skill packaging.
   - The launcher supports Linux x86-64 only, decompresses the bundled static Pixi binary into a writable cache, and verifies its pinned SHA-256 before execution.
   - If the launcher reports an unsupported platform or integrity failure, stop and report the failure. Do not silently fall back to another Pixi installation.

3. Discover repository tasks rather than guessing.
   - Use `sh scripts/pixi task list --summary` or `sh scripts/pixi task list`.
   - Inspect named environments when necessary with `sh scripts/pixi task list -e <environment>`.
   - Prefer repository-defined tasks such as `fmt`, `fmt-check`, `lint`, `test`, `check`, `build`, or benchmark tasks when they exist.
   - Prefer a project task over spelling out its underlying `cargo`, `python`, `pytest`, `ruff`, or other command directly.

4. Preserve repository state during ordinary execution.
   - If `pixi.lock` exists and the request is to test, inspect, lint, format-check, build, benchmark, reproduce, or otherwise validate existing code, run commands with `--locked` unless the repository explicitly documents another requirement.
   - Examples: `sh scripts/pixi run --locked test` and `sh scripts/pixi run --locked -e analysis python analysis/foo.py`.
   - Treat a stale lockfile failure as useful evidence. Do not silently rerun without `--locked` and update the lockfile.
   - If no lockfile exists, do not invent one merely to inspect the repository. If execution requires Pixi to create one, make that side effect explicit and inspect repository changes afterward.

5. Distinguish Pixi availability from package availability.
   - The bundled launcher makes Pixi itself available, but fresh environment creation, dependency changes, and `pixi global install` can still require network access to package channels.
   - In hosted sandboxes, Pixi may start successfully while downloads from conda-forge, prefix.dev, or PyPI fail with DNS or connection errors. Treat that as a runtime network limitation, not as a repository or lockfile failure.
   - Do not repeatedly retry a deterministic DNS or connection failure and do not silently bypass Pixi with host tooling. Report what URL or channel failed.
   - Existing Pixi environments or package caches may permit offline execution. If a command succeeds from cache, do not infer that general network access is available.

6. Use `--as-is` only as a controlled fallback for unavailable environments.
   - If a normal `pixi run --locked ...` attempt cannot materialize the environment because package-channel network access is unavailable, inspect the selected task before deciding whether `--as-is` is useful.
   - `pixi run --as-is` is equivalent to `--no-install --frozen`: it does not install dependencies or update the lockfile. It still executes the checked-in Pixi task with Pixi's activation path plus the inherited process environment, so commands can resolve tools from an already-materialized `.pixi` environment or from the host `PATH`.
   - Never assume common development tools are present. Hosted execution images can differ between sessions, and a previous `.pixi` environment may or may not exist. Probe required executables through the same `--as-is` context before relying on them.
   - Prefer a non-mutating executable probe such as `sh scripts/pixi run --as-is -x cargo fmt --version`, `sh scripts/pixi run --as-is -x ruff --version`, or `sh scripts/pixi run --as-is -x python3 --version`. This tests the search path the fallback task will actually use.
   - Inspect task dependencies as well as the task command. Do not add `--skip-deps` merely to make an offline validation appear to pass.
   - For Python commands, the interpreter probe is not sufficient when the task imports project dependencies; rely on the actual task result to establish whether those imports are available.
   - If the required pre-existing tools are available, run the original repository-defined task with `sh scripts/pixi run --as-is ...`; do not replace the task with a hand-written approximation.
   - Treat an `--as-is` success as "the Pixi task passed using pre-existing tools," not as proof that the locked Pixi environment can be installed or reproduced. Compare relevant tool versions with the lockfile, toolchain file, or repository documentation when exact environment fidelity matters.
   - If a required executable is absent, report that the task could not be run offline. Do not claim success merely because another task in the same workflow passed.
   - If a task is skipped because it is outside the scope of the changed files, say explicitly that it was not run. Do not report the aggregate validation suite as passing unless every required component actually ran successfully.

7. Allow intentional project mutations when requested.
   - For requests that intentionally add, remove, upgrade, or update dependencies or workspace configuration, use the appropriate Pixi command without `--locked` and expect both manifest and lockfile changes as applicable.
   - Review the resulting diff and run the repository's validation tasks afterward.
   - Use `pixi global` only when the user explicitly requests standalone global tooling or the repository documents it; do not use it as a substitute for declaring project dependencies.

8. Select the correct environment explicitly when the repository has multiple environments.
   - Use `sh scripts/pixi run -e <environment> ...` for commands associated with a non-default environment.
   - Infer the environment from task definitions, documentation, CI, or the user's command examples; do not choose arbitrarily when the distinction matters.

9. Finish by reporting what actually ran.
   - Summarize the Pixi task or command, environment, and whether locked mode was used.
   - If `--as-is` was used, state that explicitly and identify the pre-existing tools that satisfied the task.
   - Surface failures with enough command output to diagnose them.
   - If a command changed `pixi.toml`, `pyproject.toml`, or `pixi.lock`, call that out explicitly.

## Safety and reproducibility

- Never claim a Pixi command passed unless it was actually executed successfully.
- Do not bypass a failing Pixi task by directly invoking underlying host tools unless diagnosing the failure requires it. `pixi run --as-is <task>` is an allowed fallback because Pixi still executes the repository-defined task, but report that it used host/pre-existing tools rather than a materialized Pixi environment.
- Do not change channels, dependencies, platforms, environments, or lockfiles as a workaround unless the user's task calls for repository changes.
- Prefer the repository's checked-in conventions over generic Pixi conventions when they conflict.
