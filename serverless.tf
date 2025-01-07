Here's the Terraform code based on the architecture diagram and requirements you've provided:

```hcl
# Configure the AWS provider
provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}

# Configure S3 backend for storing Terraform state
terraform {
  backend "s3" {
    bucket = "bedrock-poc-test1"
    key    = "terraform.tfstate"
    region = "us-west-2"  # Replace with your S3 bucket's region
  }
}

# Create SQS queue
resource "aws_sqs_queue" "migration_queue" {
  name = "migration-queue"
}

# Create DynamoDB table
resource "aws_dynamodb_table" "migration_table" {
  name           = "Migration"
  billing_mode   = "PROVISIONED"
  read_capacity  = 10
  write_capacity = 30
  hash_key       = "MigrationId"
  range_key      = "Entity"

  attribute {
    name = "MigrationId"
    type = "S"
  }

  attribute {
    name = "Entity"
    type = "S"
  }
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_migration_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambda_role.name
}

# Create Lambda function
resource "aws_lambda_function" "migration_lambda" {
  filename      = "lambda_function.zip"  # Replace with your Lambda function code
  function_name = "migration-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"
  timeout       = 900  # 15 minutes
  memory_size   = 512

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.migration_table.name
    }
  }
}

# Create event source mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.migration_queue.arn
  function_name    = aws_lambda_function.migration_lambda.arn
}

# Create CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.migration_lambda.function_name}"
  retention_in_days = 14
}
```

This Terraform code creates the necessary resources based on the architecture diagram and requirements you provided. It includes:

1. AWS provider configuration
2. S3 backend configuration for storing the Terraform state
3. SQS queue
4. DynamoDB table with the specified configuration
5. IAM role for Lambda with necessary permissions
6. Lambda function with the specified runtime, timeout, and memory
7. Event source mapping to trigger Lambda from SQS
8. CloudWatch log group for Lambda logs

Make sure to replace the `filename` in the `aws_lambda_function` resource with the actual path to your Lambda function code. Also, adjust the region in the provider and backend configuration if needed.