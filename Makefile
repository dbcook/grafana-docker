# Makefile for grafana-docker

# configuration

# artifact_store can be 'artifactory' or 's3'
artifact_store := artifactory

# vars that can be set from command line
# if DOCKER_TAG is not set, it will be set equal to GRAFANA_VERSION
GRAFANA_VERSION :=
DOCKER_TAG :=


# computed vars
# if RELEASE_BUILD is set, then the 'latest' tag will be moved up to this build
RELEASE_BUILD :=

ifdef GRAFANA_VERSION
	ifndef DOCKER_TAG
		DOCKER_TAG :=$(GRAFANA_VERSION)
	endif
else
#   Read version from file if not specified on command line
	GRAFANA_VERSION := $(shell cat GRAFANA_VERSION | cut -d '=' -f2)
	DOCKER_TAG :=$(GRAFANA_VERSION)
	RELEASE_BUILD=true
endif

grafana_artifact_filename := grafana_$(GRAFANA_VERSION)_amd64.deb

#
# set up artifact store specific mechanics
# Must define
#   curl_get_url - URL to the artifact
#   curl_info_args - curl args and URL used to test access to the artifact
#

ifeq ($(artifact_store), artifactory)
#
# Artifactory source for .deb
#
artifactory_base_url := https://artifactory.viasat.com/artifactory
grafana_subrepo := databus-deb/grafana

curl_get_base := $(artifactory_base_url)/$(grafana_subrepo)

# artifactory creds needed if .deb source is artifactory
ifndef ARTIFACTORY_USERNAME
$(error ARTIFACTORY_USERNAME must be defined)
endif
ifndef ARTIFACTORY_PASSWORD
$(error ARTIFACTORY_PASSWORD must be defined)
endif

artifactory_api_info := $(artifactory_base_url)/api/storage
artifactory_info_uri := $(artifactory_api_info)/$(grafana_subrepo)/$(grafana_artifact_filename)

curl_get_url := $(curl_get_base)/$(grafana_artifact_filename)
curl_info_args := -u $(ARTIFACTORY_USERNAME):$(ARTIFACTORY_PASSWORD) --write-out "\nhttp_status: %{http_code}\n" $(artifactory_info_uri)

# this can be used to do the actual get
curl_get_args  := -u $(ARTIFACTORY_USERNAME):$(ARTIFACTORY_PASSWORD) --write-out "\nhttp_status: %{http_code}\n" -O $(curl_get_url)

else ifeq ($(artifact_store), s3)
#
# S3 bucket source for .deb
#
s3_bucketname := grafanarel
s3_bucketpath := builds

curl_get_url := https://$(s3_bucketname).s3.amazonaws.com/$(s3_bucketpath)/$(grafana_artifact_filename)
curl_info_args := --write-out "\nhttp_status: %{http_code}\n" $(curl_get_url)

else
$(error artifact_store $(artifact_store) not supported yet)
endif

tmpfile:=$(shell mktemp /tmp/grafanabuild.XXXXXX)

# To avoid lengthy fail/debug cycles inside the docker builds, we pre-check accessibility of the .deb artifact
#     1) target artifact exists
#     2) credentials are valid
#   Using the Artifactory file info API will verify both in a fairly reasonable length of time
#
.PHONY: check_artifact
check_artifact:
	@echo Testing $(artifact_store) curl target
	curl $(curl_info_args) 2>/dev/null > $(tmpfile)
	if [[ -z `grep 200 $(tmpfile)` ]]; then echo "Error checking artifact curl"; cat $(tmpfile); rm $(tmpfile); false; fi
	rm $(tmpfile)

.PHONY: build
build: check_artifact
	@echo "GRAFANA_VERSION = "$(GRAFANA_VERSION)
	@echo "DOCKER_TAG = "$(DOCKER_TAG)
	@echo "RELEASE_BUILD ="$(RELEASE_BUILD)
	@echo Building version tagged docker image
	docker build --build-arg GRAFANA_VERSION=$(GRAFANA_VERSION) --build-arg DEB_URL=$(curl_get_url) --tag "grafana/grafana:$(DOCKER_TAG)"  --no-cache=true .
ifdef RELEASE_BUILD
	@echo Tagging release image as latest
	docker tag grafana/grafana:$(DOCKER_TAG) grafana/grafana:latest
endif


.PHONY: update-from-upstream
update-from-upstream:
	git fetch upstream
	git checkout master
	git merge upstream/master

