#! /usr/bin/env nix-shell
#! nix-shell -i bash -p age
IMAGE_NAME="${1:-zero2w-nixos-k6.6.5.img}"
IMAGE_PATH="./result/sd-image/$IMAGE_NAME"
MOUNT_DIR="./image"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo privileges."
    exit 1
fi

read -p "Enter SSID for the provisioning network: " ssid
echo
while true; do
    read -s -p "Enter password for the provisioning network: " password
    echo
    read -s -p "Confirm password for the provisioning network: " password_confirm
    echo
    if [ "$password" = "$password_confirm" ]; then
        break
    else
        echo "Passwords do not match, please try again."
    fi
done
echo
while true; do
    read -s -p "Enter password for the admin user: " admin_password
    echo
    read -s -p "Confirm password for the admin user: " admin_password_confirm
    echo
    if [ "$admin_password" = "$admin_password_confirm" ]; then
        break
    else
        echo "Passwords do not match, please try again."
    fi
done
echo
echo "Making private and secret directories..."
mkdir -p ./private
mkdir -p ./secrets

ssh-keygen -t ed25519 -C "zero2w_system_key" -f ./private/zero2w
ssh-keygen -t ed25519 -C "admin_user_key" -f ./private/admin
echo
echo "Making secrets.nix..."
cat <<EOF >./secrets/secrets.nix
let 
  userKey = "$(cat ./private/admin.pub)";
  systemKey = "$(cat ./private/zero2w.pub)";
in
{
    "provision_net_pass.age".publicKeys = [ userKey systemKey ];
    "provision_net_ssid.age".publicKeys = [ userKey systemKey ];
    "admin_pass.age".publicKeys = [ userKey systemKey ];
}
EOF

echo "Writing age encrypted files..."
echo "$admin_password" | mkpasswd -m sha-512 -s > ./private/admin_hash
age -R ./private/zero2w.pub -R ./private/admin.pub -e -i ./private/zero2w -i ./private/admin -o ./secrets/admin_pass.age ./private/admin_hash
echo "$ssid" | age -R ./private/zero2w.pub -R ./private/admin.pub -e -o ./secrets/provision_net_ssid.age
echo "$password" | age -R ./private/zero2w.pub -R ./private/admin.pub -e -o ./secrets/provision_net_pass.age

# Copy age secrets files to working directory so nix can build them
echo
echo "Creating /run/zero2w-build-secrets build placeholders..."
mkdir -p /run/zero2w-build-secrets
cp ./secrets/*.age /run/zero2w-build-secrets/
echo

echo "Adding admin public key to authorized keys in config..."
admin_pub_key=$(cat ./private/admin.pub)
echo
replacement_ssh="users.users.admin.openssh.authorizedKeys.keys = [ \"$admin_pub_key\" ];"
sed -i "s|users.users.admin.openssh.authorizedKeys.keys = \[.*\];|$replacement_ssh|" ./zero2w.nix
echo

echo "Building SD card image..."
nix build .#images.zero2w
exit_status=$?
if [ $exit_status -ne 0 ]; then
    echo "Error detected in build process, exiting..."
    exit $exit_status
fi
echo

echo "Copying result image..."
cp $IMAGE_PATH ./
echo
chmod +w $IMAGE_NAME
echo
echo "Mounting image..."
LOOP_DEVICE=$(losetup -Pf --show "$IMAGE_NAME")
if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to create loop device."
    exit 1
fi

mkdir -p "$MOUNT_DIR"

if ! mount "${LOOP_DEVICE}p2" "$MOUNT_DIR"; then
    echo "Failed to mount the second partition of $LOOP_DEVICE"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

echo
echo "Copying ssh keys..."
if ! cp "./private/zero2w" "$MOUNT_DIR/boot/"; then
    echo "Failed to copy private system SSH key to $MOUNT_DIR/boot/"
    echo "Umounting image..." 
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    rmdir "$MOUNT_DIR"
    exit 1
fi
if ! cp "./private/admin" "$MOUNT_DIR/boot/"; then
    echo "Failed to copy private admin SSH key to $MOUNT_DIR/boot/"
    echo "Unmounting image..."
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    rmdir "$MOUNT_DIR"
    exit 1
fi

echo
echo "Unmounting image..."
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEVICE"
echo

echo "Cleaning up temporary build secrets..."
rm /run/zero2w-build-secrets -rf

echo
echo "Image creation complete"
echo 
echo "You can copy your image with a command similar to:"
echo "sudo dd of=/dev/mmcblk0 if=./zero2w-nixos-k6.6.5.img bs=1M status=progress"
echo "CAUTION: Confirm your SD card device is /dev/mmcblk0 before using this command"
