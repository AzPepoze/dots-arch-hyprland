#!/bin/bash

#-------------------------------------------------------
# Group: System
#-------------------------------------------------------

install_inotify_tools() {
     install_pacman_package "inotify-tools" "inotify-tools"
}

install_fuse() {
     install_paru_package "fuse" "FUSE (Filesystem in Userspace)"
}

install_ntfs_3g() {
     install_pacman_package "ntfs-3g" "NTFS Support (ntfs-3g utilities for kernel ntfs3)"
}
