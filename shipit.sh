#!/bin/bash

set -e

# tag
image_name="hyperngn/webpipe"
aws_account="$AWS_ACCOUNT"
aws_region="us-east-2"

image_tag="$(git rev-parse HEAD)"
aws_url="${aws_account}.dkr.ecr.${aws_region}.amazonaws.com"

# login to aws ecr
echo "> logging into aws ecr"
aws ecr get-login-password --region "$aws_region" \
  | docker login --username AWS  \
    --password-stdin "${aws_url}/${image_name}"

# build our image
echo "> building our image"
docker build -t "${image_name}:${image_tag}" .

# tag the image
echo "> tagging our image"
docker tag "${image_name}:${image_tag}" "${aws_url}/${image_name}:${image_tag}"

# push the image
echo "> pushing to ECR"
docker push "${aws_url}/${image_name}:${image_tag}"

echo "> DONE"
