#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"

usage() {
    cat <<'EOF'
esk - Easy SSH Key Management

Usage:
  esk ls                                        List all SSH keys in ~/.ssh
  esk gen -n NAME                               Generate a new SSH key
  esk ssh -n NAME -h USER@HOST [-p PORT]        SSH into a host using a key
  esk git -n NAME [-d DIR]                      Configure a git repo to use a key

Options:
  -n NAME       Key name (stored as id_ed25519_NAME)
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
        echo "$name"
    done
}

cmd_gen() {
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

    if [ -f "$keyfile" ]; then
        echo "Error: Key '$name' already exists at $keyfile"
        exit 1
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    ssh-keygen -t ed25519 -f "$keyfile" -C "$name"
    echo "Key '$name' created at $keyfile"
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
    ls)  cmd_ls ;;
    gen) cmd_gen "$@" ;;
    ssh) cmd_ssh "$@" ;;
    git) cmd_git "$@" ;;
    *)   echo "Unknown command: $command"; usage; exit 1 ;;
esac
