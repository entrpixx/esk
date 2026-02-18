#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"

usage() {
    cat <<'EOF'
esk - Easy SSH Key Management

Usage:
  esk ls                                        List all SSH keys in ~/.ssh
  esk gen -n NAME [-e EMAIL] [-f PATH]          Generate a new SSH key
  esk view -n NAME                              View the public key of an SSH key
  esk rm -n NAME                                Remove an SSH key
  esk ssh -n NAME -h USER@HOST [-p PORT]        SSH into a host using a key
  esk git -n NAME [-d DIR]                      Configure a git repo to use a key

Options:
  -n NAME       Key name (stored as id_ed25519_NAME)
  -e EMAIL      Email for the SSH key comment
  -f PATH       Directory to create the SSH key in (default: ~/.ssh)
  -h USER@HOST  Remote host to connect to
  -p PORT       SSH port (default: 22)
  -d DIR        Git repository directory (default: .)
EOF
}

cmd_ls() {
    if [ ! -d "$SSH_DIR" ]; then
        echo "No ~/.ssh directory found"
        return 0
    fi

    local keys=()

    for f in "$SSH_DIR"/id_ed25519_*.pub; do
        [ -e "$f" ] || continue
        keys+=("$f")
    done

    if [ ${#keys[@]} -eq 0 ]; then
        echo "No SSH keys found in ~/.ssh"
        return 0
    fi

    for f in "${keys[@]}"; do
        local basename
        basename=$(basename "$f" .pub)

        local name="${basename#id_ed25519_}"
        echo "$name  $f"
    done
}

cmd_gen() {
    local name="" email="" keydir="$SSH_DIR"

    while [ $# -gt 0 ]; do
        case "$1" in
            -n) name="$2"; shift 2 ;;
            -e) email="$2"; shift 2 ;;
            -f) keydir="$2"; shift 2 ;;
            *)  echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: -n NAME is required"
        exit 1
    fi

    local keyfile="$keydir/id_ed25519_$name"

    if [ -f "$keyfile" ]; then
        echo "Error: Key '$name' already exists at $keyfile"
        exit 1
    fi

    mkdir -p "$keydir"
    chmod 700 "$keydir"

    local comment="$name"
    if [ -n "$email" ]; then
        comment="$email"
    fi

    ssh-keygen -t ed25519 -f "$keyfile" -C "$comment"
    echo "Key '$name' created at $keyfile"
}

cmd_view() {
    local name=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -n) name="$2"; shift 2 ;;
            *)  echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: -n NAME is required"
        exit 1
    fi

    local pubfile="$SSH_DIR/id_ed25519_$name.pub"

    if [ ! -f "$pubfile" ]; then
        echo "Error: Public key for '$name' not found at $pubfile"
        exit 1
    fi

    cat "$pubfile"
}

cmd_rm() {
    local name=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -n) name="$2"; shift 2 ;;
            *)  echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: -n NAME is required"
        exit 1
    fi

    local keyfile="$SSH_DIR/id_ed25519_$name"

    if [ ! -f "$keyfile" ]; then
        echo "Error: Key '$name' not found at $keyfile"
        exit 1
    fi

    rm -f "$keyfile" "$keyfile.pub"
    echo "Key '$name' removed"
}

cmd_ssh() {
    local name="" host="" port="22"

    while [ $# -gt 0 ]; do
        case "$1" in
            -n) name="$2"; shift 2 ;;
            -h) host="$2"; shift 2 ;;
            -p) port="$2"; shift 2 ;;
            *)  echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: -n NAME is required"
        exit 1
    fi

    if [ -z "$host" ]; then
        echo "Error: -h USER@HOST is required"
        exit 1
    fi

    local keyfile="$SSH_DIR/id_ed25519_$name"

    if [ ! -f "$keyfile" ]; then
        echo "Error: Key '$name' not found at $keyfile"
        exit 1
    fi

    ssh -i "$keyfile" -p "$port" "$host"
}

cmd_git() {
    local name="" dir="."

    while [ $# -gt 0 ]; do
        case "$1" in
            -n) name="$2"; shift 2 ;;
            -d) dir="$2"; shift 2 ;;
            *)  echo "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "Error: -n NAME is required"
        exit 1
    fi

    local keyfile="$SSH_DIR/id_ed25519_$name"

    if [ ! -f "$keyfile" ]; then
        echo "Error: Key '$name' not found at $keyfile"
        exit 1
    fi

    if [ ! -d "$dir/.git" ]; then
        echo "Error: '$dir' is not a git repository"
        exit 1
    fi

    git -C "$dir" config core.sshCommand "ssh -i $keyfile -o IdentitiesOnly=yes"
    echo "Configured '$dir' to use key '$name'"
}

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

command="$1"
shift

case "$command" in
    ls)   cmd_ls ;;
    gen)  cmd_gen "$@" ;;
    view) cmd_view "$@" ;;
    rm)   cmd_rm "$@" ;;
    ssh)  cmd_ssh "$@" ;;
    git)  cmd_git "$@" ;;
    *)    echo "Unknown command: $command"; usage; exit 1 ;;
esac
