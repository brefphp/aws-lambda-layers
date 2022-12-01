These images provide Amazon Linux 2 images with some packages pre-installed.

These packages are the same for all layers, and we don't need to rebuild everything every time we build layers. So to optimize the builds, we build these base layers once (every now and then) and publish them to Docker Hub.

Then the layers build can use the published versions without having to rebuild them every time. That accelerates the build process.
