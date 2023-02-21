# nushell

## Amend path variable

Edit `~/.config/nushell/config.nu`

```nu
let-env PATH = ($env.HOME + "/.bin" |
        append $env.PATH )
```

## Variable and command substitution (backtick equivalent)

```sh
export MYVAR="this_is_a_string_with_a_${VAR}_and_`id -u`_command"
```

```nu
let-env MYVAT=$"this_is_a_string_with_a_($env.VAR)_and_(id -u)_command"
```

## Auto-complete

Detailed information can be found [here][custom_autocomplete].

### Example: Auto-complete rake tasks

```nu
module completions {
  def "nu-complete-rake-tasks" [] {
    # With the `do { cmd }` instruction, we redirect the stderr output to null.
    # Otherwise, it may print directory switching instructions.
    (
      do { rake -T } | grep rake | lines |
      each { |line| $line | str replace ' #.*$' '' | str replace '^rake ' '' | str trim }
    )
  }

  # This is the specification of the external `rake` comment.
  # - The optional string argument for `-T` was left out because I did not know
  #   how to specify it here and nu complains about the usage without it above
  #   otherwise.
  # - Some flags with `--flag=VALUE` were left out.
  export extern "rake" [
    task?: string@"nu-complete-rake-tasks"
    --comments                       # Show commented tasks only
    --job-stats: string              # Display job statistics. LEVEL=history displays a complete job list
    --rules                          # Trace the rules resolution.
    --suppress-backtrace: string     # Suppress backtrace lines matching regexp PATTERN. Ignored if --trace is on.
    --all(-A)                        # Show all tasks, even uncommented ones (in combination with -T or -D)
    --build-all(-B)                  # Build all prerequisites, including those which are up-to-date.
    --describe(-D): string           # Describe the tasks (matching optional PATTERN), then exit.
    --execute(-e): string            # Execute some Ruby code and exit.
    --execute-continue(-E): string   # Execute some Ruby code, then continue with normal task processing.
    --rakefile(-f): string           # Use FILENAME as the rakefile to search for.
    --no-system(-G)                  # Use standard project Rakefile search paths, ignore system wide rakefiles.
    --nosystem                       # Use standard project Rakefile search paths, ignore system wide rakefiles.
    --system(-g)                     # Using system wide (global) rakefiles (usually '~/.rake/*.rake').
    --libdir(-I): string             # Include LIBDIR in the search path for required modules.
    --jobs(-j): string               # Specifies the maximum number of tasks to execute in parallel. (default is number of CPU cores + 4)
    --multitask(-m)                  # Treat all tasks as multitasks.
    --dry-run(-n)                    # Do a dry run without executing actions.
    --no-search(-N)                  # Do not search parent directories for the Rakefile.
    --nosearch                       # Do not search parent directories for the Rakefile.
    --prereqs(-P)                    # Display the tasks and dependencies, then exit.
    --execute-print(-p): string      # Execute some Ruby code, print the result, then exit.
    --quiet(-q)                      # Do not log messages to standard output.
    --require(-r): string            # Require MODULE before executing rakefile.
    --rakelibdir(-R): string         # Auto-import any .rake files in RAKELIBDIR. (default is 'rakelib')
    --rakelib: string                # Auto-import any .rake files in RAKELIBDIR. (default is 'rakelib')
    --silent(-s)                     # Like --quiet, but also suppresses the 'in directory' announcement.
    --tasks(-T)                      # Display the tasks (matching optional PATTERN) with descriptions, then exit. -AT combination displays all of tasks contained no description.
    --verbose(-v)                    # Log message to standard output.
    --version(-V)                    # Display the program version.
    --where(-W): string              # Describe the tasks (matching optional PATTERN), then exit.
    --no-deprecation-warnings(-X)    # Disable the deprecation warnings.
    --help(-h)                       # Display this help message.
  ]
}
```

[custom_autocomplete]: https://www.nushell.sh/book/custom_completions.html
