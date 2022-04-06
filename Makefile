.PHONY: clean requirements test

#################################################################################
#
# Makefile to build the entire fish IOT service
#
# This make file can be controlled to some extent using variables passed in at
# invocation time. These are:
#
# CI 				=> Boolean - True if running under CI/CD pipeline, False otherwise (default False)
# FORCE_VENV 		=> Boolean - True to force running in a virtual env (default is conda)
# DOCKER_NO_CACHE   => Boolean - True to force the docker to build without its local cache (default False)
#
#################################################################################

PROJECT_NAME = fish-cam
STACK_NAME = FishCam
REGION = eu-west-1
NAMESPACE=pbasford
PYTHON_INTERPRETER = python3
PYTHONPATH=./fish_cam/:./tests/
SHELL := /bin/bash
CF_BUCKET = cf-templates-fishcam-dev-$(REGION)
PROFILE = pbasford-sandbox
AWS_XRAY_SDK_ENABLED = false

CF_OVERRIDES_DEV := $(shell jq -r '.[] | [.ParameterKey, .ParameterValue] | "\(.[0])=\(.[1])"' template.dev.params)

# artiface repo
AWS_XRAY_CONTEXT_MISSING=LOG_ERROR

# Images are tagged with the current commit hash
REVISION=$(shell git rev-parse HEAD | head -c8)

################################################################################################################
# Setup

ifeq (,$(shell conda info --envs | grep $(PROJECT_NAME)))
	HAS_CONDA_ENV=False
else
	HAS_CONDA_ENV=True
endif

# If conda is available then run that, unless its overriden on the command line with FORCE_VENV=True
ifeq (True, $(FORCE_VENV))
	HAS_CONDA=False
else ifeq (,$(shell which conda))
	HAS_CONDA=False
else
	HAS_CONDA=True
endif

# In CI (alpine) we want to run pip3
ifeq (True, $(CI))
	PIP:=pip3
else
	PIP:=pip
endif

## Create python interpreter environment. If Conda is installed this will be used, if not it will fall back to virtual env.
create-environment:
	@echo ">>> About to create environment: $(PROJECT_NAME)..."
ifeq (True,$(HAS_CONDA))
ifeq (True,$(HAS_CONDA_ENV))
	@echo ">>> Detected conda, found existing conda environment."
else
	@echo ">>> Detected conda, creating conda environment."
	( \
	  conda create -m -y --name $(PROJECT_NAME) python=3.8; \
	)
endif
else
	@echo ">>> check python3 version"
	( \
		$(PYTHON_INTERPRETER) --version; \
	)
	@echo ">>> No conda detected, using VirtualEnv."
	( \
	    $(PIP) install -q virtualenv virtualenvwrapper; \
	    virtualenv venv --python=$(PYTHON_INTERPRETER); \
	)
endif
#/Users/phil/Workspace/labs/fishLambda/fish-lambda/venv/bin/python -m pip install --upgrade pip

# Define utility variable to help calling Python from the virtual environment
ifeq (True,$(HAS_CONDA))
    #ACTIVATE_ENV := conda activate $(PROJECT_NAME)
    # This is some strange shizzle as per conda 4.4 and caused by make spawning shells all the time, this is a workaround... (see https://stackoverflow.com/questions/53382383/makefile-cant-use-conda-activate)
    ACTIVATE_ENV=source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate $(PROJECT_NAME); conda activate $(PROJECT_NAME)
else
    ACTIVATE_ENV := source venv/bin/activate
endif

# Execute python related functionalities from within the project's environment
define execute_in_env
	$(ACTIVATE_ENV) && $1
endef

## Login to the DEV aws code commit repo (token is stored for ~24hrs in the pip conf)
login-dev:
	@echo ">>> Logging into DEV"

## Build the environment requirements
requirements: create-environment
	$(call execute_in_env, which $(PYTHON_INTERPRETER))
	$(call execute_in_env, $(PIP) install --extra-index-url $(PIP_EXTRA_URL) -r ./hello_world/requirements.txt)
	
################################################################################################################
# Build / Run

## Run the security test (bandit + safety)
security-test:
	$(call execute_in_env, safety check -r ./fish_cam/requirements.txt)
	
run-pep:
	$(call execute_in_env, autopep8 */*.py */*/*.py --in-place)

run-flake:
	$(call execute_in_env, flake8  --exit-zero --docstring-convention google */*.py */*/*.py )

run-checks: login-dev security-test run-pep run-flake

## Build the (SAM) app
build: security-test run-pep run-flake #unit-test
	sam build --base-dir . --use-container 

## Start the API server locally
local-test:
	sam build --base-dir . --debug AllocatorLambdaFunction
	sam local invoke AllocatorLambdaFunction --event events/allocator_event.json --env-vars env.json --profile amx-dev

## Run the unit tests
unit-test:
	$(call execute_in_env, AWS_XRAY_SDK_ENABLED=false AWS_PROFILE=$(DEV_PROFILE) PYTHONPATH=${PYTHONPATH} $(PYTHON_INTERPRETER) -m pytest --cov-report="xml"  --cov=. )

## Package up the (SAM) app
package: build
	sam package --profile $(PROFILE) --s3-bucket $(CF_BUCKET) 

## Deploy the SAM app
deploy: package
	sam deploy --profile $(PROFILE) --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND --stack-name cf$(STACK_NAME) --region $(REGION) --s3-bucket $(CF_BUCKET) 
	##--parameter-overrides $(CF_OVERRIDES_DEV)


################################################################################################################
# Help

.DEFAULT_GOAL := help
# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
.PHONY: help
help:
	@echo "$$(tput bold)Makefile variables:$$(tput sgr0)"
	@echo "CI              > Boolean - True if running under CI/CD pipeline, False otherwise (default False)"
	@echo "FORCE_VENV 	> Boolean - True to force running in a virtual env (default is conda)"
	@echo "DOCKER_NO_CACHE > Boolean - True to force docker to build with no cache false otherwise (default is to use cache)"
	@echo "GIT Revision ${REVISION}"
	@echo
	@echo "$$(tput bold)Available targets:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
