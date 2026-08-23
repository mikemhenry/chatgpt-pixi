# Recovering missing tools for `--as-is`

Use this reference only when a repository-defined Pixi task cannot run because
its Pixi environment cannot be materialized and one or more executables are
missing from the `--as-is` execution path.

## Recovery workflow

1. Identify the exact missing executable from the original Pixi task and the
   environment that owns the task. Do not ask the user to upload a broad
   toolchain until the task shows that one is actually required.
2. Check the known recipes below. If none applies, use the generic executable
   recipe.
3. Give commands for the user's shell. If the user uses fish, make every
   command they should paste fish-compatible.
4. Locate the executable through the user's working Pixi environment rather
   than guessing a system path. Prefer `pixi run ... -x sh -c 'command -v ...'`
   over asking the user to enter an interactive `pixi shell`.
5. Inspect architecture and dynamic dependencies before asking for an upload.
   The bundled Pixi skill runtime is Linux x86-64, so an uploaded executable
   must be compatible with Linux x86-64 unless the runtime reports otherwise.
6. Copy the upload candidate to a browser-visible staging directory and print
   the final path. Do not make the user navigate into `.pixi/envs/...` in a file
   picker.
7. Tell the user to upload the staged file in the ChatGPT web UI using
   **+ -> Add photos & files**. If an archive is required, stage and upload the
   archive instead.
8. After the upload appears in the conversation, stage it in a writable tool
   directory, set executable permissions as needed, verify its version, prepend
   that directory to `PATH`, and retry the original repository-defined task
   through `pixi run --as-is`.
9. Report the supplied tool and version. Treat this as an `--as-is` validation,
   not as reproduction of the locked Pixi environment.

## Generic single-executable recipe

For a named Pixi environment such as `analysis`, give the user commands like
these, substituting the actual executable and environment:

```fish
set tool_name ruff
set pixi_env analysis
set tool_path (pixi run -e $pixi_env -x sh -c "command -v $tool_name")
printf 'Pixi executable: %s\n' $tool_path
file $tool_path
ldd $tool_path; or true
sha256sum $tool_path
```

For the default environment, omit `-e`:

```fish
set tool_name ruff
set tool_path (pixi run -x sh -c "command -v $tool_name")
printf 'Pixi executable: %s\n' $tool_path
file $tool_path
ldd $tool_path; or true
sha256sum $tool_path
```

If the executable is compatible and appears self-contained enough to transfer,
copy it to a browser-visible location. On native Linux, a useful default is:

```fish
set upload_path ~/Downloads/chatgpt-$tool_name
cp $tool_path $upload_path
chmod u+rx $upload_path
printf 'Upload this file: %s\n' $upload_path
sha256sum $upload_path
```

If the user is working in WSL, prefer the Windows Downloads directory so the
browser file picker can reach it easily. One fish-compatible approach is:

```fish
set windows_home (wslpath (cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r'))
set upload_path $windows_home/Downloads/chatgpt-$tool_name
cp $tool_path $upload_path
printf 'Upload this file: %s\n' $upload_path
sha256sum $upload_path
```

If the user is on another platform or `~/Downloads` is not browser-visible,
ask them to substitute a directory their browser can access. Do not hide the
final upload path in prose; print it explicitly.

`ldd` output is diagnostic, not an absolute portability guarantee. If the
binary depends only on common system libraries, try the single-file upload and
verify it in the sandbox. If it depends on libraries from the Pixi prefix, or
if the executable delegates to sibling tools, use or add a multi-file recipe
instead of pretending the single file is sufficient.

## Known recipes

### Ruff

Treat `ruff` as a single-executable candidate first.

1. Locate it with the generic recipe in the repository's relevant Pixi
   environment.
2. Confirm `file` reports a Linux x86-64 executable for the current hosted
   runtime.
3. Inspect `ldd` output. If it has no Pixi-prefix library dependencies, stage
   and request that one executable.
4. After upload, verify `ruff --version`, then retry the original Ruff-bearing
   Pixi task with `--as-is` and the staged tool directory first on `PATH`.

Do not replace the repository's Ruff task with a guessed `ruff check` or
`ruff format` command. The value of this fallback is preserving the checked-in
Pixi task while supplying its missing executable.

### `cargo fmt` / Rust formatting

Do not request only the `cargo` executable for a `cargo fmt` task. `cargo fmt`
is a toolchain operation and can require `cargo`, `cargo-fmt`, `rustfmt`, and
`rustc`, plus supporting toolchain files depending on how that Rust toolchain
was packaged.

First ask the user to locate the relevant commands in the repository's working
Pixi environment:

```fish
set pixi_env default
for tool in cargo cargo-fmt rustfmt rustc
    printf '%-10s %s\n' $tool (pixi run -e $pixi_env -x sh -c "command -v $tool" 2>/dev/null)
end
```

If the repository uses the default Pixi environment and `-e default` is not
appropriate for that workspace, omit `-e $pixi_env`.

Also inspect repository metadata such as `rust-toolchain.toml`, `Cargo.toml`,
and the Pixi lockfile before deciding what to request. Prefer transferring the
smallest toolchain subset that can reproduce the repository's actual
`cargo fmt` task, but do not claim that a collection of individual binaries is
sufficient until it has been verified in the sandbox. If a multi-file subset is
needed, ask the user to create an archive in a browser-visible directory and
upload that archive.

Add more known recipes only after a real recovery demonstrates that the recipe
is reliable. Keep the generic path as the default for uncommon tools.
