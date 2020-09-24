# Serverless Deployment

This apps aims to provide a viable solution to our deployment needs of a (currently) small Next.js SaaS and multiple simple apps generated with the same libraries. The main goal being not to overkill the deployment process at the current (early) stages of these projects, while still being able to serve a heavy bundle that cannot be deployed to Lambda due to its size restrictions.

# Getting started

1. Copy .env.sample to .env if it was not done automatically after installation. You will have tu update the environment variables values.
2. Make sure you have `make` installed. [macOS](https://stackoverflow.com/questions/10265742/how-to-install-make-and-gcc-on-a-mac) | [linux](https://askubuntu.com/questions/161104/how-do-i-install-make)

## Run the app

```sh
# Install dependencies
yarn install

# Try the server
yarn dev
```

## Build & start the app

```sh
# Build app
yarn build

# Start the app
yarn start
```

## Install some helpers for the deployment

```sh
yarn ini
```

## Deploy the whole app to AWS

First prepare it.

```sh
yarn prep
```

Now copy/paste the first part of the Public IPv4 DNS of your newly created EC2 instance in the .env file.
It will be something like `ec2-1-2-345-678`.

```sh
# .env file
# replace this value with yours
AWS_EC2_INSTANCE="ec2-1-2-345-678"
```
Time to setup and deploy.

```sh
yarn setup && yarn deploy
```

# Possible deployment solutions

## ❌ Solution 1 - Split each page in a Lambda function

We decided not to follow that path, due to the number of Lambdas being created additionally to the CloudFront setup. The might have to be reconsidered at a later stage of the development of our SaaS.

https://github.com/vincent-herlemont/next-aws-lambda-webpack-plugin

## ✅ Solution 2 - EFS file system

Mounting an EFS file system to our Lambda function is the way to go for now, considering the limited number of features of our SaaS and the simplicity of the other web apps. This solution enables to bypass the size limit of Lambda functions without bringing much complexity, other than creating the EFS and a tiny EC2 instance to upload our .next bundle to it, and manually interact with the EFS itself via SSH.

To connect an EFS file system with a Lambda function, you use an EFS access point, an application-specific entry point into an EFS file system that includes the operating system user and group to use when accessing the file system, file system permissions, and can limit access to a specific path in the file system. This helps keeping file system configuration decoupled from the application code.

# Troubleshooting

> Error occurred while GetObject. S3 Error Code: NoSuchKey. S3 Error Message: The specified key does not exist. (Service: AWSLambdaInternal; Status Code: 400; Error Code: InvalidParameterValueException; Request ID: f609e473-324a-4b50-8630-369ea6197e81; Proxy: null)

Cause: The file specified as a key does not exist inside your bucket.

```yml
CodeUri:
    Bucket: !Ref deployBucketName
    Key: !Sub "name-of-the-directory/name-of-the-zip-file.zip"
```

# VPC Subnets info

A virtual private cloud (VPC) is a virtual network dedicated to your AWS account. It is logically isolated from other virtual networks in the AWS Cloud. You can launch your AWS resources, such as Amazon EC2 instances, into your VPC.

When you create a VPC, you must specify a range of IPv4 addresses for the VPC in the form of a Classless Inter-Domain Routing (CIDR) block; for example, 10.0.0.0/16. This is the primary CIDR block for your VPC. For more information about CIDR notation, see RFC 4632.

It is required to have your EC2 function in the same VPC as your EFS file system.
Create a public subnet to enable access to it.

[VPCs and subnets](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)

# Sources

- [New – A Shared File System for Your Lambda Functions](https://aws.amazon.com/blogs/aws/new-a-shared-file-system-for-your-lambda-functions)
- [Using Amazon EFS for AWS Lambda in your serverless applications](https://aws.amazon.com/blogs/compute/using-amazon-efs-for-aws-lambda-in-your-serverless-applications)
- [Configuring file system access for Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem.html)
- [New for Amazon EFS – IAM Authorization and Access Points](https://aws.amazon.com/blogs/aws/new-for-amazon-efs-iam-authorization-and-access-points)
- [Unblocking new serverless use cases with EFS and Lambda](https://lumigo.io/blog/unlocking-more-serverless-use-cases-with-efs-and-lambda)
- [AWS Lambda Developer Guide - Sample Apps](https://github.com/awsdocs/aws-lambda-developer-guide/tree/main/sample-apps/efs-nodejs)
- [AWS Lambda EFS Samples](https://github.com/aws-samples/aws-lambda-efs-samples)
- [Access Points in IAM policies](https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html#access-points-iam-policy)
- [Sync files from S3 to EFS (video)](https://youtu.be/3cLDIidAxtE?t=608)
- [Upload files to EFS (video)](https://youtu.be/_snUm9g5jG0?t=1117)
- [Lambda with EFS (video)](https://youtu.be/4cquiuAQBco)
- [AWS EFS Tutorial: Create EFS and Mount it on Linux (video)](https://youtu.be/juvhVytI0Lg)
- [Mounting EFS outside of AWS](https://xan.manning.io/2016/09/08/mounting-efs-outside-of-aws.html)
