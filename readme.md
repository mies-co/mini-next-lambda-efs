# Serverless Deployment

This apps aims to test the best options for deployment of a Nextjs app

### Option 1 - S3
Add the whole .next bundle on S3 somehow

### Option 2 - Split
https://github.com/vincent-herlemont/next-aws-lambda-webpack-plugin

### Option 3 - Automated
https://github.com/serverless-nextjs/serverless-next.js

### Option 4 - EFS

To connect an EFS file system with a Lambda function, you use an EFS access point, an application-specific entry point into an EFS file system that includes the operating system user and group to use when accessing the file system, file system permissions, and can limit access to a specific path in the file system. This helps keeping file system configuration decoupled from the application code.

Sources:
- https://aws.amazon.com/blogs/aws/new-a-shared-file-system-for-your-lambda-functions/
- https://aws.amazon.com/blogs/compute/using-amazon-efs-for-aws-lambda-in-your-serverless-applications/
- https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem.html

# Troubleshooting

> Error occurred while GetObject. S3 Error Code: NoSuchKey. S3 Error Message: The specified key does not exist. (Service: AWSLambdaInternal; Status Code: 400; Error Code: InvalidParameterValueException; Request ID: f609e473-324a-4b50-8630-369ea6197e81; Proxy: null)

Cause: The file specified as a key does not exist inside your bucket.

```yml
CodeUri:
    Bucket: !Ref deployBucketName
    Key: !Sub "${xVersion}/pack-saas.zip"
```

Sources:
- https://stackoverflow.com/a/28654035/9077800