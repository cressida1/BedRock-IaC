Here's the Terraform code to create the infrastructure based on the architecture diagram and requirements you've provided:

```hcl
provider "aws" {
  region = "us-west-2"  # Change this to your desired region
}

resource "aws_sqs_queue" "migration_queue" {
  name = "migration-queue"
}

resource "aws_lambda_function" "migration_lambda" {
  filename      = "lambda_function.zip"  # Ensure this file exists with your Lambda code
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

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.migration_queue.arn
  function_name    = aws_lambda_function.migration_lambda.arn
}

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

resource "aws_iam_role" "lambda_role" {
  name = "migration-lambda-role"

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

resource "aws_iam_role_policy_attachment" "lambda_sqs_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.migration_table.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.migration_lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}
```

This Terraform code creates all the required resources:

1. An SQS queue
2. A Lambda function with the specified runtime, timeout, and memory
3. A DynamoDB table with the specified configuration
4. An IAM role for the Lambda function with permissions to read from SQS and write to DynamoDB
5. CloudWatch logging for the Lambda function
6. The necessary event source mapping to trigger the Lambda function from the SQS queue

Make sure to replace the `lambda_function.zip` with your actual Lambda function code, and adjust the region if needed. Also, ensure that you have the AWS provider configured with the appropriate credentials before running this Terraform code.