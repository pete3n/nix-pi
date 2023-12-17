#!/bin/bash

SCRIPTS=(build_new_sd.sh rebuild_sd.sh deploy_config.sh)

if [ -x "/run/current-system/sw/bin/nix-shell" ]; then
    SHEBANG_LINE1="#! /usr/bin/env nix-shell"
    SHEBANG_LINE2="#! nix-shell -i bash -p mkpasswd age deploy-rs"
    echo "NIXOS" > .env
elif [ -x "/nix/var/nix/profiles/default/bin/nix-shell" ]; then
    SHEBANG_LINE1="#! /nix/var/nix/profiles/default/bin/nix-shell"
    SHEBANG_LINE2="#! nix-shell -i bash -p mkpasswd age deploy-rs"
    echo "NIX" > .env
else
    echo "nix-shell not found."
    exit 1
fi

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        sed -i "1s|.*|${SHEBANG_LINE1}|; 2s|.*|${SHEBANG_LINE2}|" "$script"
    fi
done

echo "Scripts modified for environment"

