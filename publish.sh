#!/usr/bin/env bash

export AWS_DEFAULT_PROFILE

AWS_DEFAULT_PROFILE=reallyreadit

export JEKYLL_ENV

JEKYLL_ENV=production

jekyll build

aws s3 sync _site s3://blog.reallyread.it --region us-east-2 --delete

JEKYLL_ENV=development