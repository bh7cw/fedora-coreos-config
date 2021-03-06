#!/bin/bash
set -euo pipefail

# This is implementation details of Ignition; in the future, we should figure
# out a way to ask Ignition directly whether there's a filesystem with label
# "root" being set up.
ignition_cfg=/run/ignition.json
rootdisk=/dev/disk/by-label/root
saved_sysroot=/run/ignition-ostree-rootfs
partstate=/run/ignition-ostree-rootfs-partstate.json

case "${1:-}" in
    detect)
        wipes_root=$(jq '.storage?.filesystems? // [] | map(select(.label == "root" and .wipeFilesystem == true)) | length' "${ignition_cfg}")
        if [ "${wipes_root}" = "0" ]; then
            exit 0
        fi
        echo "Detected rootfs replacement in fetched Ignition config: /run/ignition.json"
        mkdir "${saved_sysroot}"
        ;;
    save)
        mount "${rootdisk}" /sysroot
        echo "Moving rootfs to RAM..."
        cp -aT /sysroot "${saved_sysroot}"
        # also store the state of the partition
        lsblk "${rootdisk}" --nodeps --json -b -o PATH,SIZE | jq -c . > "${partstate}"
        ;;
    restore)
        # This one is in a private mount namespace since we're not "offically" mounting
        mount "${rootdisk}" /sysroot
        echo "Restoring rootfs from RAM..."
        cd "${saved_sysroot}"
        find . -mindepth 1 -maxdepth 1 -exec mv -t /sysroot {} \;
        chattr +i $(ls -d /sysroot/ostree/deploy/*/deploy/*/)
        ;;
    *)
        echo "Unsupported operation: ${1:-}" 1>&2; exit 1
        ;;
esac
