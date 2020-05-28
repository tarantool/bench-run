# Use host network at dockerfiles builds
DOCKERFILE_BUILD=docker build --network=host

# #########################################################
# Prepare 2 images for performance testings:
# - perf/ubuntu-bionic:perf_master
#   image with only built benchmarks w/o Tarantool sources,
#   image rare changed, for its fast rebuild better to save
#   it on performance build hosts
# - perf_tmp/ubuntu-bionic:perf_<commit_SHA>
#   images with always changed Tarantool sources and its
#   depends benchmarks like 'cbench', image need to be
#   removed after each testing to save the disk space
# #########################################################
prepare:
	docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} \
		${CI_REGISTRY}
	# build all benchmarks w/o depends on Tarantool sources
	${DOCKERFILE_BUILD} --add-host $(shell hostname):127.0.0.1 \
		-t ${IMAGE_PERF} -f bench-run/dockerfiles/ubuntu_benchs .
	docker push ${IMAGE_PERF}
	# build Tarantool and benchmarks with depends on Tarantool sources
	${DOCKERFILE_BUILD} --build-arg image_from=${IMAGE_PERF} \
		-t ${IMAGE_PERF_BUILT} --no-cache -f bench-run/dockerfiles/ubuntu_tnt .
	docker push ${IMAGE_PERF_BUILT}
	# build Tarantool patched for TPC-H bench
	${DOCKERFILE_BUILD} --build-arg image_from=${IMAGE_PERF} \
		-t ${IMAGE_PERF_TPCH_BUILT} --no-cache -f bench-run/dockerfiles/ubuntu_tnt_tpch .
	docker push ${IMAGE_PERF_TPCH_BUILT}

# #####################################################
# Remove temporary performance image from the test host
# #####################################################
cleanup:
	docker rmi --force ${IMAGE_PERF_BUILT}
	docker rmi --force ${IMAGE_PERF_TPCH_BUILT}

