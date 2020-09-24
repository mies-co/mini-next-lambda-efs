include .env
export

# Hide the commands being run
MAKEFLAGS += --silent

# Define an ABSOLUTE variable in case this files moves somewhere in your computer along with the config files.
ABSOLUTE := $(realpath .)

# APP-SPECIFIC VARIABLES
xAppName := ${APP_NAME}
xDevUsername := ${DEV_USERNAME}
xAppVersion := ${APP_VERSION}
xTestFile := ${X_TEST_FILE}

# AWS VARIABLES
## Variables used mostly by the CLI
profile := ${AWS_DEPLOYMENT_PROFILE}
region := ${AWS_DEPLOYMENT_REGION}

## Variables used to define stack names
bucketProcessName := app-${xAppName}-buckets
deployProcessName := app-${xAppName}-deploy
ec2efsProcessName := datasync-ec2-efs

## S3 Bucket names
deployBucketName := ${deployProcessName}
cdnBucketName := app-${xAppName}-cdn

## Some EC2 variables
ec2KeyName := app_ec2_${xDevUsername}
ec2Instance := ${AWS_EC2_INSTANCE}
ec2User := ec2-user

## Local files references
fileHandler := ${APP_HANDLER}
fileLambdaLog := lambda.log.json


# TEMPLATES
tempBucket := app_buckets.yml
tempEC2EFS := app_ec2_efs.yml
tempApp := app.yml
tempAppGenerated := app.generated.yml

# COLORS
n := \033[0m
b := \033[34m

# Install node-prune
init:
	curl -sf https://gobinaries.com/tj/node-prune | sh

# To update a Lambda function whose source code is in an Amazon S3 bucket, 
# you must trigger an update by updating the S3Bucket, S3Key, or S3ObjectVersion property. 
# Updating the source code alone doesn't update the function.
# https://stackoverflow.com/q/47426248/9077800
# https://aws.amazon.com/blogs/compute/new-deployment-options-for-aws-lambda/
# However, a timestamp in the zip's name solves it! As the reference of Lambda changes, it will update.
save-timestamp:
	$(eval timestamp := $(shell date +%s))
	$(shell echo "${timestamp}" > deploy.timestamp)

runtime-variables:
	# Timestamp will help create a unique zip
	$(eval zipTimestamp := $(shell cat deploy.timestamp))
	$(eval fileZip := ${xAppName}-${zipTimestamp}.zip)
	$(eval ec2Host := ${ec2User}@${ec2Instance}.${region}.compute.amazonaws.com)

check: runtime-variables
	echo "${n}ec2Host: ${b}${ec2Host}"
	echo "${n}zip file S3 location: ${b}${xAppVersion}/${fileZip}"
	echo "${n}zipTimestamp: ${b}${zipTimestamp}"
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
	deploy \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--force-upload \
		--parameter-overrides \
			deployBucketName=${deployBucketName} \
			cdnBucketName=${cdnBucketName} \
		--stack-name ${bucketProcessName} \
		--template-file ${tempBucket}

# Create EC2 Key Pairs
saas-ec2-keys:
	@if [[ -f "${ec2KeyName}.pem" ]]; then \
		echo "File ${ec2KeyName} already exists, creation skipped."; \
	else \
		aws ec2 \
			--profile ${profile} \
		create-key-pair \
			--key-name ${ec2KeyName} \
			--query 'KeyMaterial' \
			--output text > ${ec2KeyName}.pem; \
		chmod 400 ${ec2KeyName}.pem; \
	fi 

# Create EC2 and EFS resources
saas-ec2-efs: saas-ec2-keys
	aws cloudformation \
		--profile ${profile} \
	deploy \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--template-file ${tempEC2EFS} \
		--stack-name ${ec2efsProcessName} \
		--parameter-overrides \
			KeyName=${ec2KeyName} \
			InstanceType=t2.micro
	echo "Created ec2 instance!"

# Option `-o` prevents from having to verify the authenticity of the host
ssh: runtime-variables
	ssh -o "StrictHostKeyChecking no" -i ${ec2KeyName}.pem ${ec2Host}

# Build the nextjs app and handle its dependencies
saas-next-install-build:
	yarn
	rm -rf .next
	yarn build
	yarn --pure-lockfile --production
	node-prune node_modules

# Add a sample helloworld.json file to /myEFSvolume
# Push the nextjs bundle to EFS
saas-push-bundle: runtime-variables
	ssh -o "StrictHostKeyChecking no" -i ${ec2KeyName}.pem ${ec2Host} 'echo "{ \"hello\": \"world 02\" }" > /myEFSvolume/helloworld.json' \
	rsync -avz -e "ssh -i ${ec2KeyName}.pem" .next/ ${ec2Host}:/myEFSvolume/.next/

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
	./zips s3://${deployBucketName}/${xAppVersion}/

# Generate the template with SAM
saas-aws-sam:
	echo "Running AWS SAM to push the CodeUri and generate a template"
	aws cloudformation \
		--profile ${profile} \
	package \
		--output-template ${tempAppGenerated} \
		--s3-bucket ${deployProcessName} \
		--s3-prefix latest \
		--template ${tempApp}

# Deploy our Lambda function
saas-aws-deploy:
	echo "Deploying your stack to cloudformation ${fileZip}"
	aws cloudformation \
		--profile ${profile} \
	deploy \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--force-upload \
		--parameter-overrides \
			deployProcessName=${deployProcessName} \
			ec2efsProcessName=${ec2efsProcessName} \
			deployBucketName=${deployBucketName} \
			fileZip=${fileZip} \
			fileHandler=${fileHandler} \
			xAppName=${xAppName} \
			xTestFile=${xTestFile} \
			xHost=demo \
			xAppVersion=${xAppVersion} \
		--stack-name ${deployProcessName} \
		--template-file ${tempAppGenerated}

# Create the buckets, ec2 instance, and efs that are necessary to our deployment
prepare: check saas-buckets saas-ec2-efs
	echo "\n🛠 Prepare done\n"

# Create necessary buckets, zip files, and generate the CloudFormation template
setup: save-timestamp runtime-variables check saas-next-install-build saas-push-bundle saas-zip saas-aws-sam
	echo "\n✅ Setup done\n"

# Only push the lambda function
push: runtime-variables check saas-aws-sam saas-aws-deploy
	echo "\n✨ Push done\n"

# Deploy the whole app
deploy: runtime-variables saas-aws-upload saas-aws-deploy
	echo "\n🚀⭐ Deployment done\n"

# Describe errors when the deployment fails
describe:
	aws cloudformation describe-stack-events --profile ${profile} --stack-name ${deployProcessName}

# Get the logs, useful for Internal Server Errors.
log:
	aws lambda invoke \
	--profile ${profile} \
	--function-name app-${xAppName} ${fileLambdaLog}
	echo "Your log is in ${fileLambdaLog}"

# Run all necessary commands to deploy this thing
all: prepare setup deploy
