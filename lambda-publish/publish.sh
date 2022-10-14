#!/bin/bash

# This file publishes a new AWS Lambda layer on AWS using the AWS CLI.
# We rely on AWS CLI because it is installed by default on AWS CodeBuild.
#
# Environment variables:
# - `LAYER_NAME`: **required**
# - `REGION`: **required** Region to publish to.
# - `ONLY_REGION`: If provided, only this region will be published

# Fail on error
set -e

if [ -z "$LAYER_NAME" ]; then
    echo "\$LAYER_NAME must be set"
    exit 1
fi
if [ -z "$REGION" ]; then
    echo "\$REGION must be set"
    exit 1
fi
# If $ONLY_REGION is set and different from $REGION, then we skip this region
if [ -z "$ONLY_REGION" ] && [ "$REGION" != "$ONLY_REGION" ]; then
    echo "Skipping $REGION"
    exit 0
fi


echo "[Publish] Publishing layer $LAYER_NAME to $REGION..."

VERSION=$(aws lambda publish-layer-version \
   --region $REGION \
   --layer-name $LAYER_NAME \
   --description "Bref PHP Runtime" \
   --license-info MIT \
   --zip-file fileb://../layers/bref-zip/$LAYER_NAME.zip \
   --compatible-runtimes provided.al2 \
   --output text \
   --query Version)

echo "[Publish] Layer $LAYER_NAME uploaded, adding permissions..."

aws lambda add-layer-version-permission \
    --region $REGION \
    --layer-name $LAYER_NAME \
    --version-number $VERSION \
    --statement-id public \
    --action lambda:GetLayerVersion \
    --principal "*"

echo "[Publish] Layer $LAYER_NAME published to $REGION"
