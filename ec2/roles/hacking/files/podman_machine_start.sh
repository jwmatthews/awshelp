podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine set --rootful
podman machine start
# Don't need to install qemu-user-static as of: stream release 36.20220703.3.1
# As of https://github.com/coreos/fedora-coreos-tracker/issues/1088#issuecomment-1189114706 
#
#podman machine ssh sudo rpm-ostree install qemu-user-static
#podman machine ssh sudo rpm-ostree install buildah
#podman machine ssh sudo systemctl reboot
# #### As of Oct 2022
# Note: podman issue with ubi9 and arm64 on Mac
# Running ubi9 on Apple silicon breaks on unsupported x86_64-v2 instruction set #15456
# https://github.com/containers/podman/issues/15456
#####
