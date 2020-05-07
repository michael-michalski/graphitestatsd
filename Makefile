IMAGE_NAME ?= michaelmichalski/graphitestatsd

ifndef ALPINE_VERSION
override ALPINE_VERSION=3.11.6
endif

build:
	docker build --squash --force-rm --build-arg ALPINE_VERSION=$(ALPINE_VERSION) -t $(IMAGE_NAME):$(ALPINE_VERSION) .

all: build

clean: ## Clean up generated images
	@docker rmi --force $(IMAGE_NAME):$(ALPINE_VERSION)

rebuild: clean all

push:
	docker push $(IMAGE_NAME):$(ALPINE_VERSION)
