.PHONY: all build test clean build-image publish-image lint
.DEFAULT_GOAL := all

# Boiler plate for bulding Docker containers.
SUDO := $(shell docker info >/dev/null 2>&1 || echo "sudo -E")
RM := --rm
IMAGE_TAG := $(shell bash ./tools/image-tag)
UPTODATE := .uptodate

# Flags to pass to stack. Typically `--docker`
STACK_FLAGS :=

# Flags to pass to stack build & test. Typically `--fast`
STACK_BUILD_FLAGS :=

# This must match the base image in stack.yaml
BASE_IMAGE_NAME := quay.io/jml0/mass-driver-base

# This must match the output image generated by Stack
STACK_OUTPUT_IMAGE_NAME := quay.io/jml0/mass-driver

# The image name we actually want to generate. This is what we push to an
# image registry.
OUTPUT_IMAGE_NAME := quay.io/jml0/mass-driver

UPTODATE_FILES := $(UPTODATE) mass-driver-base/$(UPTODATE)
IMAGE_NAMES := $(BASE_IMAGE_NAME) $(STACK_OUTPUT_IMAGE_NAME) $(OUTPUT_IMAGE_NAME)

# Build the base image
mass-driver-base/$(UPTODATE): mass-driver-base/Dockerfile
	$(SUDO) docker build -t $(BASE_IMAGE_NAME) mass-driver-base/
	touch $@

all: build-image lint

lint:
	hlint .

# stack does its own dependency management and it's a fool's errand to try to
# second-guess it. Instead, just always run stack when we think we need a build.
build:
	stack $(STACK_FLAGS) build $(STACK_BUILD_FLAGS)

test: build
	stack $(STACK_FLAGS) test $(STACK_BUILD_FLAGS)

$(UPTODATE): mass-driver-base/$(UPTODATE) build
	stack $(STACK_FLAGS) image container
	$(SUDO) docker tag $(STACK_OUTPUT_IMAGE_NAME) $(OUTPUT_IMAGE_NAME):$(IMAGE_TAG)
	@echo $(OUTPUT_IMAGE_NAME):$(IMAGE_TAG)
	touch $@

# Human friendly alias for building the Docker image
build-image: $(UPTODATE)

publish-image: build-image
	$(SUDO) docker push $(OUTPUT_IMAGE_NAME):$(IMAGE_TAG)

clean:
	$(SUDO) docker rmi $(IMAGE_NAMES) >/dev/null 2>&1 || true
	rm -rf $(UPTODATE_FILES)
	stack $(STACK_FLAGS) clean
