# build env: official PKGBUILDs, official build config, autosplit on
# makepkg (scaling-eureka) and autosplit.conf are bind-mounted at run time
FROM docker.io/archlinux/archlinux:base-devel

RUN pacman -Syu --noconfirm --needed git devtools expac

# same config makechrootpkg gives official builds (flags, zstd -20),
# pacman's default /etc/makepkg.conf skews size comparisons
RUN cp /usr/share/devtools/makepkg.conf.d/x86_64.conf /etc/makepkg.conf && \
	cp /usr/share/devtools/makepkg.conf.d/x86_64.conf.d/* /etc/makepkg.conf.d/

# makepkg refuses root, -s installs deps through sudo pacman
RUN useradd -m builder && \
	echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder

USER builder
WORKDIR /home/builder
