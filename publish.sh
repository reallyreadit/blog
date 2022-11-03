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

export JEKYLL_ENV

JEKYLL_ENV=production

bundle exec jekyll build

aws s3 sync _site s3://blog.readup.org --region us-east-2 --delete

JEKYLL_ENV=development

bundle exec jekyll build