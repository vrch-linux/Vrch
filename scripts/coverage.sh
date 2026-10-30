#!/usr/bin/env bash
set -euo pipefail

# rank unsplit official packages by how many autosplit types their files hit
# runs in the vrch-build image: needs pacman -F and expac
# usage: coverage.sh [count], prints "<types> <pkg> <csize> <type...>"
declare -A paths=(
	[docs]='^usr/share/(doc|info|gtk-doc|help)/'
	[lang]='^usr/share/locale/'
	[dev]='^usr/include/'
	[libs]='^usr/lib/lib[^/]*\.so\.[0-9]'
	[static]='^usr/lib/[^/]*\.a$'
	[bash-completion]='^usr/share/bash-completion/completions/.'
	[zsh-completion]='^usr/share/zsh/site-functions/.'
	[fish-completion]='^usr/share/fish/(vendor_)?completions'
	[pyc-opt]='\.opt-1\.pyc$'
)

sudo pacman -Fy
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# pkgbases with a single package, others already split by hand
expac -S '%e %n' | awk '{ n[$1]++; p[$1] = $2 }
	END { for (b in n) if (n[b] == 1) print p[b] }' | sort -u > "$work/unsplit"

for type in "${!paths[@]}"; do
	pacman -Fxq "${paths[$type]}" | sed 's|^[^/]*/||' | sort -u |
		sed "s/\$/ $type/"
done > "$work/hits"

# csize: compressed size, a rough proxy for build time
expac -S '%n %k' | sort -u > "$work/sizes"
awk 'NR == FNR { ok[$1] = 1; next }
	FILENAME ~ /sizes$/ { size[$1] = $2; next }
	ok[$1] { n[$1]++; t[$1] = t[$1] " " $2 }
	END { for (p in n) print n[p], p, size[p], t[p] }' \
	"$work/unsplit" "$work/sizes" "$work/hits" |
	sort -k1,1nr -k3,3n | sed -n "1,${1:-25}p"
