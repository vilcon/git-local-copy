#!/bin/sh
#
# Download and run Docker image to build and test Git
#

. ${0%/*}/lib.sh

case "$jobname" in
Linux32)
	CI_TARGET=linux32
	CI_CONTAINER="daald/ubuntu32:xenial"
	;;
*)
	exit 1 ;;
esac

docker pull "$CI_CONTAINER"

# Use the following command to debug the docker build locally:
# <host-user-id> must be 0 if podman is used in place of docker
# $ docker run -itv "${PWD}:/usr/src/git" --entrypoint /bin/sh "$CI_CONTAINER"
# root@container:/# /usr/src/git/ci/run-$CI_TARGET-build.sh <host-user-id>

container_cache_dir=/tmp/travis-cache

docker run \
	--interactive \
	--env DEVELOPER \
	--env DEFAULT_TEST_TARGET \
	--env GIT_PROVE_OPTS \
	--env GIT_TEST_OPTS \
	--env GIT_TEST_CLONE_2GB \
	--env cache_dir="$container_cache_dir" \
	--volume "${PWD}:/usr/src/git" \
	--volume "$cache_dir:$container_cache_dir" \
	"$CI_CONTAINER" \
	"/usr/src/git/ci/run-$CI_TARGET-build.sh" $(id -u $USER)

check_unignored_build_artifacts

save_good_tree
