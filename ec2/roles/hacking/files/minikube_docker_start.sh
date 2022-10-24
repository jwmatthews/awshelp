# Using docker until the below podman machine issue is resolve for Mac arm64
# #### As of Oct 2022
# Note: podman issue with ubi9 and arm64 on Mac
# Running ubi9 on Apple silicon breaks on unsupported x86_64-v2 instruction set #15456
# https://github.com/containers/podman/issues/15456
#####
#
minikube --driver docker start --memory=6g --cpus=4

