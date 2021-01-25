#!/bin/bash

STACK_NAME=awsbootstrap
REGION=eu-west-2
CLI_PROFILE=Administrator
EC2_INSTANCE_TYPE=t2.micro
# get AWS account ID
AWS_ACCOUNT_ID=`aws sts get-caller-identity --profile $CLI_PROFILE \
  --query "Account" --output text`
# S3 bucket name must be globally unique
# adding our AWS account id helps prevent name conflicts
CODEPIPELINE_BUCKET="$STACK_NAME-$REGION-codepipeline-$AWS_ACCOUNT_ID"

# Generate a personal access token with repo and admin:repo_hook
#   permissions from https://github.com/settings/tokens
GH_ACCESS_TOKEN=$(cat ~/.github/aws-bootstrap-access-token)
GH_OWNER=$(cat ~/.github/aws-bootstrap-owner)
GH_REPO=$(cat ~/.github/aws-bootstrap-repo)
GH_BRANCH=master

CFN_BUCKET="$STACK_NAME-cfn-$AWS_ACCOUNT_ID"

# DEPLOY STATIC RESOURCES
# - S3 bucket for CodePipeline artifacts
# - The S3 bucket for CloudFormation templates
echo -e "\n\n=========== Deploying setup.yml ============"

aws cloudformation deploy \
   --region $REGION \
   --profile $CLI_PROFILE \
   --stack-name $STACK_NAME-setup \
   --template-file setup.yml \
   --no-fail-on-empty-changeset \
   --capabilities CAPABILITY_NAMED_IAM \
   --parameter-overrides \
     CodePipelineBucket=$CODEPIPELINE_BUCKET \
     CloudFormationBucket=$CFN_BUCKET
     
# PACKAGE UP CLOUDFORMATION TEMPLATES INTO AN S3 BUCKET
echo -e "\n\n=========== Packaging main.yml ============"
mkdir -p ./cfn_output

PACKAGE_ERR="$(aws cloudformation package \
   --region $REGION \
   --profile $CLI_PROFILE \
   --template main.yml \
   --s3-bucket $CFN_BUCKET \
   --output-template-file ./cfn_output/main.yml 2>&1)"

if ! [[ $PACKAGE_ERR =~ "Successfully packaged artifacts" ]]; then
  echo "ERROR while running 'aws cloudformation package' command:"
  echo $PACKAGE_ERR
  exit 1
fi

# DEPLOY THE CLOUDFORMATION TEMPLATE
echo -e "\n\n=========== Deploying main.yml ============"

aws cloudformation deploy \
   --region $REGION \
   --profile $CLI_PROFILE \
   --stack-name $STACK_NAME \
   --template-file ./cfn_output/main.yml \
   --no-fail-on-empty-changeset \
   --capabilities CAPABILITY_NAMED_IAM \
   --parameter-overrides \
     EC2InstanceType=$EC2_INSTANCE_TYPE \
     GitHubOwner=$GH_OWNER \
     GitHubRepo=$GH_REPO \
     GitHubBranch=$GH_BRANCH \
     GitHubPersonalAccessToken=$GH_ACCESS_TOKEN \
     CodePipelineBucket=$CODEPIPELINE_BUCKET

# If the deployment succeeded, show the DNS name of the created instance
if [ $? -eq 0 ]; then
  aws cloudformation list-exports \
    --profile $CLI_PROFILE \
    --query "Exports[?ends_with(Name,'LBEndpoint')].Value"
fi