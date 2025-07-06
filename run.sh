#!/bin/bash

set -e

/prepare_build.sh

/build.sh

/create_repository.sh

