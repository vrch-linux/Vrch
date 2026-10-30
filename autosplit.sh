#!/usr/bin/env bash
set -euo pipefail

# build an official package with scaling-eureka's makepkg (vrch-build image)
# and fetch the official binary next to it, for sc.sh to compare
# usage: autosplit.sh <pkgname>, artifacts in build/<pkgname>
cd "$(dirname "$0")"
pkg=$1
eureka=$(realpath "${EUREKA:-../scaling-eureka}")
out=$PWD/build/$pkg
mkdir -p "$out/official"

# keep-id: builder (uid 1000) writes to out/ as the host user
podman run --rm --userns=keep-id \
	-v "$eureka/makepkg:/usr/bin/makepkg:ro,Z" \
	-v "$eureka/lib:/usr/share/makepkg:ro,Z" \
	-v "$PWD/autosplit.conf:/etc/makepkg.conf.d/autosplit.conf:ro,Z" \
	-v "$out:/home/builder/out:Z" \
	vrch-build bash -c '
	set -euo pipefail
	sudo pacman -Syu --noconfirm
	# same PKGBUILD as the repo binary, tags drop the epoch colon
	ver=$(pacman -Si "$1" | sed -n "s/^Version *: //p")
	git clone --depth 1 --branch "${ver/:/-}" \
		"https://gitlab.archlinux.org/archlinux/packaging/packages/$1.git"
	cd "$1"
	# upstream source signing keys ship with the packaging repo
	if [[ -d keys/pgp ]]; then
		gpg --import keys/pgp/*.asc
	fi
	PKGDEST=~/out makepkg -s --noconfirm --nocheck
	# pacman downloads as the alpm user, which cannot write to out/
	sudo pacman -Sw --noconfirm "$1"
	cp "/var/cache/pacman/pkg/$(basename "$(pacman -Sp "$1")")" ~/out/official/
	' _ "$pkg"
