#!/bin/bash
IMAGE_NAME="${1:-zero2w-nixos-k6.6.5.img}"
IMAGE_PATH="./result/sd-image/$IMAGE_NAME"
MOUNT_DIR="/tmp/sd-image"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo privileges."
    exit 1
fi

if ! which age > /dev/null; then
    echo "age not found, entering Nix shell to provide it...please re-run this script"
    nix-shell -p age
fi

echo "Building SD card image..."
nix build .#images.zero2w
echo
echo "Mounting image..."

LOOP_DEVICE=$(losetup -Pf --show "$IMAGE_PATH")
if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to create loop device."
    exit 1
fi

mkdir -p "$MOUNT_DIR"

if ! mount "${LOOP_DEVICE}p2" "$MOUNT_DIR"; then
    echo "Failed to mount the first partition of $LOOP_DEVICE"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

echo
echo "Copying ssh keys..."
if ! cp "./private/zero2w" "$MOUNT_DIR/root/.ssh/"; then
    echo "Failed to copy private system SSH key to $MOUNT_DIR/root/.ssh"
    ehco "Umounting image..."
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi
if ! cp "./private/admin" "$MOUNT_DIR/home/admin/.ssh/"; then
    echo "Failed to copy private admin SSH key to $MOUNT_DIR/home/admin/.ssh"
    echo "Unmounting image..."
    umount "$MOUNT_DIR"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

echo
echo "Unmounting image..."
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEVICE"
echo
echo "Image creation complete. You can copy your image with a command similar to:"
echo "sudo dd of=/dev/mmcblk0 if=./result/sd-card/zero2w-nixos-k6.6.5.img bs=1M status=progress"
echo "CAUTION: Confirm your SD card device is /dev/mmcblk0 before using this command"
