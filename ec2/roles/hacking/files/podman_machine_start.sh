podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine set --rootful
podman machine start
podman machine ssh sudo rpm-ostree install qemu-user-static
podman machine ssh sudo rpm-ostree install buildah
podman machine ssh sudo systemctl reboot
