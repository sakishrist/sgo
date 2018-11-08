# SGO
Simple GetOpts. This is a source-able script that provides a simpler way to get all the command line options.

## Overview

To define your rules on how to parse the command line parameters, start by writing some rules for sgoInit:

```
sgoInit 'PROTOCOL=[4|6]
HOST={h<host>}
VERBOSE=[v<verbose>]'
```

In the main script, the parsing of the arguments is initiated with sgo:

```
sgo "$@"
```
Then the script can be launched by the following options:

```
script.sh -v4 --host=host.com ls /dir
```

After sgo has bin executed in the above example, There will be the following variables defined in the main script:

```
PROTOCOL=4
HOST=host.com
VERBOSE=1
```

For a more in-depth example that exposes all of the functionality, see __Usage__ -> __Example__ below.

## Usage

This is a more in depth presentation of each option.

### Configuration

#### Flags

Square brackets in `sgoInit` (`VAR=[x]`) tells the `sgo` function to expect an option without a parameter (`-x`). In this mode, when an option is specified, it sets `VAR` to `1`. Options in this mode can be specified multiple times and each time one is encountered by the `sgo` function, it increments `VAR` by one.

Multiple short options without arguments can be specified without separation (`-2qq` is the same as `-2 -q -q`).

Square brackets also support specifying full option names (`VAR=[x<xephos>]`). This allow the parsing of both short (`-x`) and long (`--xephos`) options.

#### Mutually exclusive flags

To specify mutually excluding options (e.g. -4 and -6 for IPv4 or IPv6), the pipe symbol can be used in-between the options (e.g. `VAR=[4|6|b<both>]`). When two or more mutually exclusive options are used, the last one is taken into account (e.g. `-4 --both -6` will set `VAR` to `6`). If the long option is used, the short one is stored in the variable.

#### Options with values

Curly brackets (`VAR={x}`) permit an argument to be provided for the option. In this mode, `VAR` is set to the argument provided after `-x`.

As with square brackets, long names can be provided (`VAR={x<xephos>}`).

Long options can have their arguments either separated from the option by a white-space or by an equals sign (`--xephos=gold` or `--xephos rusty`), while the short options can be separated by a white-space or left right after the option (`-x gold` or `-xrusty`).

#### Compatibility with multiple option names

Multiple options with arguments cannot be currently specified in the same definition (e.g. `VARIANT={v<variant>|d<distribution>}` is not allowed) but they can be defined on different lines:

```
VARIANT={v<variant>}
VARIANT={d<distribution>}
```
Again, the last one on the command line is the one that is used (e.g. `-v redhat -d ubuntu` will set `VARIANT` to `ubuntu`)

#### Mandatory options with values

An exclamation mark (!) in the beginning of the variable, denotes that this is a mandatory option. This is only acceptable for options with arguments (defined with curly brackets).

#### Ignore options

An exclamation mark with only the options (without a variable) can be used to specify options that should be ignored (including their values).

```
sgoInit '![1|2|4|6|A|a|C|f|G|g|K|k|M|N|n|q|s|T|t|V|v|X|x|Y|y]
!{b|c|D|E|e|F|I|i|L|l|m|O|o|p|Q|R|S|W|w}'

sgo -t -p 22222 less -S /var/log/messages
```

In the above example, all the ssh options (both with arguments and without) will be ignored and not be set to any variables.

To ignore flags, an exclamation mark and square brackets are used. To ignore options with their values, curly brackets are used instead.

To use the ignored options in the main script, see __Unprocessed arguments__ below

### Usage
The sgo function can be used to initiate the processing of the arguments. It expects the command line arguments that need parsing passed the same way as arguments to it. In most cases, the best thing to do is:

```
sgo "$@"
```
This will pass the same arguments that the script has received, and will pass them quoted the same way as they were on the script.

The sgo function will set any found options and arguments to their respective global variables.

#### Unprocessed arguments

Once sgo reaches the end of the usable options, it stops processing. The end can either be denoted by `--` as an argument, or by the next argument being a normal string and not an option.

```
sgo -p 2222 host.com

sgo -v centos -- ssh -p 22 host.com
```
In the above cases, sgo will stop processing after the first option.

The function will set a global variable named `__SGO_SHIFT` to the value needed for use by main script to shift the options and get to the rest of the arguments that are left unprocessed.

Also, in case of ignored options, they are stored in `__SGO_IGNORED` in the way they were encountered (without messing the quotation).

In the case of a wrapper to a program for instance, a probable way to pass arguments to the program would be the following:

```
sgo "$@"

shift $__SGO_SHIFT
program "$__SGO_IGNORED" "$@"
```

This will pass all arguments that sgo did not parse.

### Example

Start by configuring the function what to expect and how to store it:

```
sgoInit 'STAGE=[1|2|3|f<full>]
QUIET=[q<quiet>]
COMP={c<components>}
WIZ=[w<wizard>]
!VARIANT={v<variant>}
LANGUAGE={l<language>}
MONOC=[m<monochrome>]
HELP=[h<help>]'
```

After which, parse some arguments, in this case the command line arguments of the script:

```
sgo "$@"
```
Then the script can be launched by the following options:

```
script.sh -2qq -m --components=tech --wizard -v centos7 -vasd command argument
```

## Issues
Please let me know.

## Planned features
 * Help message based on the defined rules.
 * Quiet mode with specific exit codes to let the main script define the messages.

