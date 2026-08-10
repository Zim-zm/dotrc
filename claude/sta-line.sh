#!/bin/bash
# Claude Code statusline: model name, cwd + git branch (clean/dirty colored),
# context-window usage, and 5-hour/weekly rate-limit usage/reset.

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name')
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir')
ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

RCol=$(tput sgr0)
Red=$(tput setaf 1)
Gre=$(tput setaf 2)
BBlu=$(tput setaf 4)
Yel=$(tput setaf 3)
Cya=$(tput setaf 6)

# git branch + dirty state; skip optional locks so we don't race the repo's own git commands
git_info=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if [ -z "$(git -C "$cwd" --no-optional-locks status --untracked-files=no --porcelain 2>/dev/null)" ]; then
            git_info=" ${Gre}${branch}${RCol}"
        else
            git_info=" ${Red}${branch}${RCol}"
        fi
    fi
fi

parts=()
parts+=("${BBlu}${model}${RCol}")
parts+=("${cwd}${git_info}")

if [ -n "$ctx_pct" ]; then
    ctx_round=$(printf '%.0f' "$ctx_pct")
    parts+=("${Cya}ctx ${ctx_round}%${RCol}")
fi

usage_str=""
if [ -n "$five_pct" ]; then
    five_round=$(printf '%.0f' "$five_pct")
    five_reset_str=""
    if [ -n "$five_reset" ]; then
        five_reset_str=$(date -d "@${five_reset}" +%H:%M 2>/dev/null)
    fi
    if [ -n "$five_reset_str" ]; then
        usage_str="usage: ${five_round}% (resets ${five_reset_str})"
    else
        usage_str="usage: ${five_round}%"
    fi
fi

weekly_str=""
if [ -n "$week_pct" ]; then
    week_round=$(printf '%.0f' "$week_pct")
    week_reset_str=""
    if [ -n "$week_reset" ]; then
        week_reset_str=$(date -d "@${week_reset}" +%a 2>/dev/null)
    fi
    if [ -n "$week_reset_str" ]; then
        weekly_str="weekly: ${week_round}% (resets ${week_reset_str})"
    else
        weekly_str="weekly: ${week_round}%"
    fi
fi

if [ -n "$usage_str" ] || [ -n "$weekly_str" ]; then
    if [ -n "$usage_str" ] && [ -n "$weekly_str" ]; then
        rate_str="${usage_str} - ${weekly_str}"
    else
        rate_str="${usage_str}${weekly_str}"
    fi
    parts+=("${Yel}${rate_str}${RCol}")
fi

out=""
sep=""
for p in "${parts[@]}"; do
    out="${out}${sep}${p}"
    sep=" | "
done
printf '%s' "$out"
