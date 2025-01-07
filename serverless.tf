Here's the Terraform code to create the infrastructure as described:

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_sqs_queue" "migration_queue" {
  name = "migration-queue"
  visibility_timeout_seconds = 900  # 15 minutes to match Lambda timeout
}

resource "aws_lambda_function" "migration_processor" {
  filename      = "lambda_function.zip"  # Ensure this file exists
  function_name = "migration-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
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
  function_name    = aws_lambda_function.migration_processor.arn
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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "lambda_sqs_dynamodb_policy" {
  name = "lambda-sqs-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.migration_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.migration_table.arn
      }
    ]
  })
}
```

This Terraform code creates the following resources:

1. An SQS queue
2. A Lambda function
3. A DynamoDB table
4. An IAM role for the Lambda function
5. Necessary IAM policies for Lambda to access SQS and DynamoDB
6. An event source mapping to trigger the Lambda function from SQS

Note: You'll need to provide the `lambda_function.zip` file containing your Python code for the Lambda function. Make sure this file is in the same directory as your Terraform configuration or update the `filename` attribute in the `aws_lambda_function` resource accordingly.