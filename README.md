# check-shell
check a single shell script, list functions and dependency tree

Call method: parms are relative to this script directory

parm 1: ShellSource="${1:-"../wwanHotspot-devel/files/wwanHotspot.sh"}"
parm 2: OutputDir="${2:-"./$(basename "${ShellSource}")"}"

environment:
DEBUG set to any character will enable shell script xtrace to stderr

Output:
- List of function names. "&" marks forked processes.
- One separated file for each function.
- Calling tree of function names to "functions-tree.txt"
