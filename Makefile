include .env
export

MAKEFLAGS += --silent
ABSOLUTE := $(realpath .)

# APP-SPECIFIC VARIABLES
xAppName := ${APP_NAME}
xVersion := ${APP_VERSION}

# AWS VARIABLES
profile := ${AWS_DEPLOYMENT_PROFILE}
region := ${AWS_DEPLOYMENT_REGION}
bucketProcessName := app-${xAppName}-buckets
deployProcessName := app-${xAppName}-deploy

deployBucketName := ${deployProcessName}
cdnBucketName := app-${xAppName}-cdn

fileLambdaLog := lambda.log.json
fileHandler := ${APP_HANDLER}

# TEMPLATES
tempBucket := buckets.yml
tempApp := app.yml
tempAppGenerated := app.generated.yml

n := \033[0m
b := \033[34m

# Install node-prune
init:
	curl -sf https://gobinaries.com/tj/node-prune | sh

save-timestamp:
	$(eval timestamp := $(shell date +%s))
	$(shell echo "${timestamp}" > deploy.timestamp)

runtime-variables:
	# Timestamp will help create a unique zip
	$(eval zipTimestamp := $(shell cat deploy.timestamp))
	$(eval fileZip := ${xAppName}-${zipTimestamp}.zip)

check: runtime-variables
	echo "zipTimestamp ${zipTimestamp}"
	echo "${n}profile: ${b}${profile}"
	echo "${n}region: ${b}${region}"
	echo "${n}bucketProcessName: ${b}${bucketProcessName}"
	echo "${n}deployProcessName: ${b}${deployProcessName}"
	echo "${n}deployBucketName: ${b}${deployBucketName}"
	echo "${n}cdnBucketName: ${b}${cdnBucketName}"
	echo "${n}fileZip: ${b}${fileZip}"
	echo "${n}fileLambdaLog: ${b}${fileLambdaLog}"
	echo "${n}tempBucket: ${b}${tempBucket}"
	echo "${n}tempApp: ${b}${tempApp}"
	echo "${n}tempAppGenerated: ${b}${tempAppGenerated}"
	echo "${n}"

# Create the initial buckets required by the app
saas-buckets:
	aws cloudformation \
		--profile ${profile} \
	deploy\
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--force-upload \
		--parameter-overrides \
			deployBucketName=${deployBucketName} \
			cdnBucketName=${cdnBucketName} \
		--stack-name ${bucketProcessName} \
		--template-file ${tempBucket}

saas-next-install-build:
	yarn
	rm -rf .next
	yarn build
	yarn --pure-lockfile --production
	node-prune node_modules

# Zip the files that will go in S3 and be used as the Lambda function
saas-zip:
	mkdir -p zips && mkdir -p .next
	ls -t zips/* | awk 'NR>2' | xargs rm -f
	zip -FS -r zips/${fileZip} ${fileHandler}.js next.config.js .next node_modules

# Upload zip to S3
saas-aws-upload:
	aws s3 sync \
	--profile ${profile} \
	--exclude .DS_Store \
	--delete \
	./zips s3://${deployBucketName}/${xVersion}/

saas-aws-sam:
	echo "Running AWS SAM to push the CodeUri and generate a template"
	aws cloudformation \
		--profile ${profile} \
	package \
		--output-template ${tempAppGenerated} \
		--s3-bucket ${deployProcessName} \
		--s3-prefix latest \
		--template ${tempApp}

# To update a Lambda function whose source code is in an Amazon S3 bucket, 
# you must trigger an update by updating the S3Bucket, S3Key, or S3ObjectVersion property. 
# Updating the source code alone doesn't update the function.
# https://stackoverflow.com/q/47426248/9077800
# https://aws.amazon.com/blogs/compute/new-deployment-options-for-aws-lambda/
saas-aws-deploy:
	echo "Deploying your stack to cloudformation ${fileZip}"
	aws cloudformation \
		--profile ${profile} \
	deploy \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--force-upload \
		--parameter-overrides \
			deployProcessName=${deployProcessName} \
			deployBucketName=${deployBucketName} \
			fileZip=${fileZip} \
			fileHandler=${fileHandler} \
			xAppName=${xAppName} \
			xHost=demo \
			xVersion=${xVersion} \
		--stack-name ${deployProcessName} \
		--template-file ${tempAppGenerated}

# Create necessary buckets, zip files, and generate the CloudFormation template
setup: save-timestamp runtime-variables check saas-buckets saas-next-install-build saas-zip saas-aws-sam
	echo "\n✅ Setup done\n"

# Only push the lambda function
push: runtime-variables saas-aws-deploy
	echo "\n⭐ Push done\n"

# Deploy the whole app
deploy: runtime-variables saas-aws-upload saas-aws-deploy
	echo "\n🚀⭐ Deployment done\n"

describe:
	aws cloudformation describe-stack-events --profile ${profile} --stack-name ${deployProcessName}

log:
	aws lambda invoke \
	--profile ${profile} \
	--function-name app-${xAppName} ${fileLambdaLog}
	echo "Your log is in ${fileLambdaLog}"

all: setup deploy
