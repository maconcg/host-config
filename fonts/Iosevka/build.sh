#!/bin/bash -

# This script generates customized builds of Renzhi Li's Iosevka font,
# following the instructions published at:
# https://github.com/be5invis/Iosevka/blob/main/doc/custom-build.md

# It's overkill for what it does, but that's kind of the point.

######################################################################
# ┌────────────────────────────────────────────────────────────────┐
# │                         Shell Options                          │
# └────────────────────────────────────────────────────────────────┘
shopt -so errexit nounset pipefail

shopt -s extglob failglob

######################################################################
# ┌────────────────────────────────────────────────────────────────┐
# │                           Constants                            │
# └────────────────────────────────────────────────────────────────┘
# The upstream-provided npm build script expects this basename.
readonly build_spec=private-build-plans.toml

# This script is unlikely to work with any other font, so it's safe
# hard-code the value of ‘font’ as ‘Iosevka’.
readonly font=Iosevka

# This allows us to call the build script from any directory.
readonly invocation_dir="$PWD"

# The upstream's build script will output to ‘Iosevka/dist’.
readonly output_dir=dist

# Ensure we're using the distribution-provided version of each
# external command.
readonly PATH=$(type -p getconf) PATH

######################################################################
# ┌────────────────────────────────────────────────────────────────┐
# │                           Functions                            │
# └────────────────────────────────────────────────────────────────┘
function build_variant() {
    : "${1?‘$FUNCNAME’ must be passed a spec file.}"

    if (( $quiet )); then
        local ln_options='-sf'
    else
        local ln_options='-si'
    fi

    cd "$repo_dir" &&
        ln "$ln_options" "$1" "$build_spec"

    local b="$(basename $1)"
    npm run-script build -- "$output::${b%.*}" &&
        rm "$repo_dir/$build_spec"
}

function print_plan() {
    spec_files="$1"
    local summary
    # We pass the ‘END OF TRANSMISSION BLOCK’ character (codepoint 25,
    # o31, #x19) to ‘read’ builtin's  ‘-d’ option.  This enables us to
    # make better use  of here documents.  It's  a bit unconventional,
    # perhaps, but this  character is part of the  ASCII standard, and
    # this use is actually close to the character's original purpose.

    # The  performance advantage  of  using ‘read’  with  the ‘END  OF
    # TRANSMISSION BLOCK’  character (vs. the common  ‘cat’ technique)
    # becomes apparent  once you've  printed about  10,000–20,000 help
    # messages in a loop.
    read -d summary<<EOF
Here's the plan:
  → Output format: ‘$output’
  → Specification file(s):
$(for f in "$@"; do echo "        • $(basename $f)"; done)
  → Output destination: ‘$repo_dir/$output_dir’.
EOF
    echo "$summary"
} 1>&2

function prompt_user() {
    while read -p 'Does this look ok? [y/N] '; do
        case "${REPLY@L}" in
            n*)
                exit 3
                ;;
            y?(es))
                break
                ;;
            *)
                continue
                ;;
        esac
    done
} 1>&2

function show_help() {
    local msg
    read -d help_message<<EOF
usage: ${0##*/} [OPTIONS] [-]
Build customized Iosevka font family from source.

  Options:
    -h            output this help message
    -o OUTPUT     specify an output format
    -q            quiet this script (Don't prompt the user)
    -r REPO_DIR   specify the directory containing cloned Iosevka repo
EOF
    echo "${help_message[@]}"
} 1>&2

######################################################################
# ┌────────────────────────────────────────────────────────────────┐
# │                  Option Parsing and Defaults                   │
# └────────────────────────────────────────────────────────────────┘
while getopts hoqr: OPT; do
    case $OPT in
        h|+h)
            show_help
            exit 255
            ;;
        o|+o)
            output="$OPTARG"
            ;;
        q|+q)
            quiet=1
            ;;
        r|+r)
            repo_dir="$OPTARG"
            ;;
        *)
            show_help
            exit 2
            ;;
    esac
done
shift $(( OPTIND - 1 ))
OPTIND=1

# If a variable is unset or null, assign its default value.
: ${output:=ttf}
: ${quiet:=0}
: ${repo_dir:="$HOME/src/repos/$font"}

######################################################################
# ┌────────────────────────────────────────────────────────────────┐
# │                              Body                              │
# └────────────────────────────────────────────────────────────────┘
for spec; do
    if [[ ! -f "$spec" || ! "$spec" =~ \.toml$ ]]; then
        echo "${0##*/}: line $BASH_LINENO: Cannot process ‘$spec’." 1>&2
        exit 4
    fi
done

if (( ! $quiet )); then
    print_plan "$@"
    prompt_user
fi

for spec; do
    build_variant "$invocation_dir/$spec"
done
