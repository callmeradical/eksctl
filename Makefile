builtAt := $(shell date +%s)
gitCommit := $(shell git describe --dirty --always)
gitTag := $(shell git describe --tags --abbrev=0 --always)

.PHONY: build
build:
	go build -ldflags "-X main.gitCommit=$(gitCommit) -X main.builtAt=$(builtAt)" ./cmd/eksctl

.PHONY: update-bindata
update-bindata:
	go generate ./pkg/eks

.PHONY: install-bindata
install-bindata:
	go get -u github.com/jteeuwen/go-bindata/...

.PHONY: eksctl_build_image
eksctl_build_image:
	docker build --tag=eksctl_build ./build

.PHONY: eksctl_image
eksctl_image: eksctl_build_image
	docker build --tag=eksctl ./

.PHONY: release
release: eksctl_build_image
	docker run \
	  --env=GITHUB_TOKEN \
	  --env=CIRCLE_TAG \
	  --volume=$(CURDIR):/go/src/github.com/weaveworks/eksctl \
	  --workdir=/go/src/github.com/weaveworks/eksctl \
	    eksctl_build \
	      make do_release

.PHONY: do_release
do_release:
	@if [ $(CIRCLE_TAG) = latest_release ] ; then \
	  git tag -d $(gitTag) ; \
	  github-release info --user weaveworks --repo eksctl --tag latest_release > /dev/null 2>&1 && \
	    github-release delete --user weaveworks --repo eksctl --tag latest_release ; \
	  goreleaser release --skip-validate --config=./.goreleaser.floating.yml ; \
	else \
	  goreleaser release --config=./.goreleaser.permalink.yml ; \
        fi
