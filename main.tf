# Shared IAM Role
resource "aws_iam_role" "scheduler" {
  name = "resource-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Combined IAM Policy
resource "aws_iam_policy" "scheduler" {
  name        = "ResourceSchedulerPolicy"
  description = "Combined permissions for ECS/EKS scheduling"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # ECS Permissions
      var.enable_ecs ? [{
        Effect = "Allow",
        Action = [
          "ecs:ListTasks",
          "ecs:StopTask",
          "ecs:ListServices",
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ],
        Resource = "*"
      }] : [],

      # EKS Permissions
      var.enable_eks ? [{
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:UpdateAutoScalingGroup",
          "eks:ListNodegroups",
          "eks:DescribeNodegroup"
        ],
        Resource = "*"
      }] : [],

      # DynamoDB Permissions
      (var.enable_ecs || var.enable_eks) ? [{
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:DeleteItem"
        ],
        Resource = aws_dynamodb_table.scheduler_config.arn
      }] : [],

      [{
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }]
    )
  })
}

resource "aws_iam_role_policy_attachment" "scheduler" {
  role       = aws_iam_role.scheduler.name
  policy_arn = aws_iam_policy.scheduler.arn
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "scale_down" {
  name                = "resource-scale-down"
  schedule_expression = var.schedule_scale_down
}

resource "aws_cloudwatch_event_rule" "scale_up" {
  name                = "resource-scale-up"
  schedule_expression = var.schedule_scale_up
}


resource "aws_dynamodb_table" "scheduler_config" {
  name         = local.config_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "resource_type"
  range_key    = "resource_arn"

  attribute {
    name = "resource_type"
    type = "S"
  }

  attribute {
    name = "resource_arn"
    type = "S"
  }
}