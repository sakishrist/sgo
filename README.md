# SGO
Simple GetOpts. This is a source-able script that provides a simpler way to get all the command line options.

## Usage overview
Start by configuring the function what to expect and how to store it:
```
sgoInit 'STAGE=[1|2|3|f<full>]
QUIET=[q<quiet>]
COMP={c<components>}
WIZ=[w<wizard>]
VARIANT={v<variant>}
MONOC=[m<monochrome>]
HELP=[h<help>]'
```

After which, parse some arguments:

```
sgo -2qq -m --components=tech --wizard -v centos7 -vasd command argument

# OR:

# Parse the command line arguments of your script.
sgo "$@"
```

## Usage
This is a more in depth presentation of each option.
### Configuration
Square brackets in `sgoInit` (`VAR=[x]`) tells the `sgo` function to expect an option without a parameter (`-x`). In this mode, when an option is specified, it sets `VAR` to `1`. Options in this mode can be specified multiple times and each time one is encountered by the `sgo` function, it increments `VAR` by one.

Multiple short options without arguments can be specified without separation (`-2qq` is the same as `-2 -q -q`).

Square brackets also support specifying full option names (`VAR=[x<xephos>]`). This allow the parsing of both short (`-x`) and long (`--xephos`) options.

To specify mutually excluding options (e.g. -4 and -6 for IPv4 or IPv6), the pipe symbol can be used in-between the options (e.g. `VAR=[4|6|b<both>]`). When two or more mutually exclusive options are used, the last one is taken into account (e.g. `-4 --both -6` will set `VAR` to `6`). If the long option is used, the short one is stored in the variable.

Curly brackets (`VAR={x}`) permit an argument to be provided for the option. In this mode, `VAR` is set to the argument provided after `-x`.

As with square brackets, long names can be provided (`VAR={x<xephos>}`).

Long options can have their arguments wither separated from the option by a whitespace or by an equals sign (`--xephos=gold` or `--xephos rusty`), while the short options can be separated by a whitespace or left right after the option (`-x gold` or `-xrusty`).

Multiple options with arguments cannot be currently specified in the same definition (e.g. `VARIANT={v<variant>|d<distribution>}` is not allowed) but they can be defined on different lines:
```
VARIANT={v<variant>}
VARIANT={d<distribution>}
```
Again, the last one on the command line is the one that is used (e.g. `-v redhat -d ubuntu` will set `VARIANT` to `ubuntu`)

### sgo
The sgo function expects the command line arguments that need parsing passed the same way as arguments to it. In most cases, the best thing to do is:
```
sgo "$@"
```
This will pass the same arguments that the script has received, and will pass them quoted the same way as they were on the script.

The sgo function will set any found options and arguments to their respective global variables.

The function will also set a global variable named `__SGO_SHIFT` to the value needed for use by the shift built-in command to skip the options and get to the arguments.

## Issues
Please let me know.

## Planned features
Ignore options.
```
sgoInit '![1|2|4|6|A|a|C|f|G|g|K|k|M|N|n|q|s|T|t|V|v|X|x|Y|y]
!{b|c|D|E|e|F|I|i|L|l|m|O|o|p|Q|R|S|W|w}'

sgo -t -p 22222 less -S /var/log/messages
```

In the above, all the ssh options (both with arguments and without) will be ignored and not be set to any variables.
