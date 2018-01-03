# git revision

Work in progress...

## Usage

```
> git revision
Revision: 321
Version name: TODO
```

### Help

```
> git revision help
Welcome to git revision! This tool helps to generate useful version numbers and
revision codes for your project. Semantic versioning (i.e. "1.4.2") is nice but
only useful for end users. Wouldn't it be nice if each commit had a unique
revision which is meaningful and comparable?

Usage:

-v, --version    Shows the version information
-h, --help       Shows a help message for a given command 'git revision init --help'

Commands:

init    Creates a configuration file (.gitrevision.yaml)
help    Shows this help text
```

### Init
```
> git revision init
Creates a configuration file `.gitrevision.yaml` to add a fixed config to this project

Usage: git revision init [--baseBranch] [--format] [--help]

-f, --format        format options
                    [revision (default), more will come...]

-h, --help
-b, --baseBranch    The branch you work on most of the time
                    (defaults to "master")
```
