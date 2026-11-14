# Features documented only in the binary

nushell.sh is generated per stable release and lags even the stable binary, so
the installed `nu` is the authority on what exists. A command, flag or config
key can be real, documented by `help`, and absent from the website.

## Is this a nightly?

```nu
(version).version                  # 0.117.0, or e.g. 0.116.2-nightly.33
(version).version =~ 'nightly'     # true on a nightly build
version | select commit_hash build_time experimental_options
```

Nightly semantics drift between builds, so check `nu --version` before relying
on a behavior, and verify it empirically (`nu --no-config-file -c '…'`) rather
than from memory or the website.

## Where the binary describes itself

| Question | Ask the binary |
|---|---|
| What does a command do, and which flags does it take? | `help <command>` (or the `nu_doc_help` tool) |
| Which commands exist? | `scope commands`, `help commands` |
| Which config keys exist, with their docs? | `config nu --doc` |
| What are the defaults? | `config default` |
| Which in-progress features exist, and which are on? | `debug experimental-options` |
| Which `$nu` constants exist? | `$nu \| columns` |

Experimental options are toggled per process with
`nu --experimental-options '[name=true]'` (or `all`). Several are on by default
and shape everyday behavior, so they belong in any version check
(`pipefail`, `enforce-runtime-annotations` and `reorder-cell-paths` on 0.117.0).

## Finding what changed between two versions

Dump each binary's self-description, then diff the dumps.

```nu
# inventory.nu — run once per binary: nu --no-config-file inventory.nu <out-dir>
def main [out: path] {
  let v = (version).version
  config nu --doc | lines | where $it starts-with '$env.config.'
  | parse --regex '^\$env\.config\.(?<key>[\w.-]+)' | get key | uniq | sort
  | save --force ($out | path join $"config-keys-($v).txt")
  scope commands | select name type signatures | sort-by name | to nuon
  | save --force ($out | path join $"commands-($v).nuon")
  $nu | columns | sort | save --force ($out | path join $"nu-keys-($v).txt")
}
```

Compare with row conditions: new command names are
`open new.nuon | where name not-in (open old.nuon | get name)`; new config keys
the same over the `.txt` lines; changed flags by comparing each command's
`signatures` (named and switch parameters). A stable baseline binary comes from
a release tarball, and the upstream commit titles between two tags from GitHub's
compare API for `nushell/nushell`.
