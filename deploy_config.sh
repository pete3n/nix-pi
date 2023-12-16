#! /usr/bin/env nix-shell
#! nix-shell -i bash -p deploy-rs

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo privileges."
    exit 1
fi

read -p "Enter the target IP for the system to be updated: " target_ip
echo

# Copy age secrets files to working directory so nix can build them
echo "Creating /run/zero2w-build-secrets build placeholders..."
mkdir -p /run/zero2w-build-secrets
cp ./secrets/*.age /run/zero2w-build-secrets/
echo

echo "Deploying config with deploy-rs..."
deploy --hostname=${target_ip} --ssh-opts="-i""./private/admin" --magic-rollback=true --confirm-timeout=30
echo

echo "Cleaning up temporary build secrets..."
rm /run/zero2w-build-secrets -rf
