Based on the architecture diagram and the provided specifications, here's the Terraform code to create the infrastructure:

```hcl
provider "aws" {
  region = "us-west-2"  # Change this to your preferred region
}

resource "aws_sqs_queue" "migration_queue" {
  name                        = "migration-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  # Other default settings will be applied
}

resource "aws_iam_role" "lambda_role" {
  name = "migration_lambda_role"

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

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_lambda_function" "migration_lambda" {
  filename      = "lambda_function.zip"  # You need to create this ZIP file with your Lambda code
  function_name = "migration_lambda"
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

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.migration_lambda.function_name}"
  retention_in_days = 14
}
```

This Terraform code creates the following resources:

1. An SQS FIFO queue
2. An IAM role for the Lambda function with permissions to read from SQS and write to DynamoDB
3. A Lambda function with the specified settings
4. A DynamoDB table with the specified configuration
5. An event source mapping to trigger the Lambda function from the SQS queue
6. A CloudWatch log group for Lambda function logs

Note that you'll need to create a ZIP file containing your Lambda function code and update the `filename` attribute in the `aws_lambda_function` resource accordingly.