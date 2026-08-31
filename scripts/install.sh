#!/usr/bin/env bash
# Installs the dotnet-engineering skill for an agent.
#
# Usage:
#   ./scripts/install.sh <target> [path] [--link]
#
# Targets:
#   claude-project <path>   -> <path>/.claude/skills
#   copilot-project <path>  -> <path>/.github/skills
#   codex-project <path>    -> <path>/.agents/skills
#   claude-user             -> ~/.claude/skills
#   copilot-user            -> ~/.copilot/skills
#   agents-user             -> ~/.agents/skills
#
# --link creates a symlink instead of copying, so the installation follows this checkout.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
source_dir="$repo_root/skills/dotnet-engineering"

if [ ! -f "$source_dir/SKILL.md" ]; then
  echo "Skill not found at $source_dir" >&2
  exit 1
fi

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

[ $# -ge 1 ] || usage

target="$1"
shift

path=""
link=false
for arg in "$@"; do
  case "$arg" in
    --link) link=true ;;
    *) path="$arg" ;;
  esac
done

case "$target" in
  claude-project|copilot-project|codex-project)
    if [ -z "$path" ]; then
      echo "A path is required for the '$target' target." >&2
      exit 1
    fi
    if [ ! -d "$path" ]; then
      echo "Path '$path' does not exist." >&2
      exit 1
    fi
    ;;
esac

case "$target" in
  claude-project)  skills_dir="$path/.claude/skills" ;;
  copilot-project) skills_dir="$path/.github/skills" ;;
  codex-project)   skills_dir="$path/.agents/skills" ;;
  claude-user)     skills_dir="$HOME/.claude/skills" ;;
  copilot-user)    skills_dir="$HOME/.copilot/skills" ;;
  agents-user)     skills_dir="$HOME/.agents/skills" ;;
  *) echo "Unknown target '$target'." >&2; usage ;;
esac

mkdir -p "$skills_dir"
destination="$skills_dir/dotnet-engineering"

if [ -e "$destination" ] || [ -L "$destination" ]; then
  rm -rf "$destination"
  echo "Replaced the existing installation."
fi

if [ "$link" = true ]; then
  ln -s "$source_dir" "$destination"
  echo "Linked $destination -> $source_dir"
else
  cp -R "$source_dir" "$destination"
  echo "Copied the skill to $destination"
fi

file_count="$(find "$destination/" -type f | wc -l | tr -d ' ')"
echo "$file_count files installed."
echo
echo "Invoke it in chat with /dotnet-engineering, or let the agent pick it up automatically on .NET work."
