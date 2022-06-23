#!/usr/bin/env bash

# Copyright (C) 2022 reallyread.it, inc.
#
# This file is part of Readup.
#
# Readup is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License version 3 as published by the Free Software Foundation.
#
# Readup is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License version 3 along with Foobar. If not, see <https://www.gnu.org/licenses/>.

export AWS_DEFAULT_PROFILE

AWS_DEFAULT_PROFILE=reallyreadit

# Builds into the _site dir in the current working dir.
docker run --rm \
  --env JEKYLL_ENV=production \
  --volume="$PWD:/srv/jekyll:Z" \
  jekyll/jekyll:4.1.0 \
  jekyll build

aws s3 sync _site s3://blog.readup.com --region us-east-2 --delete