# AWS Resource Scheduler for ECS & EKS

Terraform module to automatically scale ECS services and EKS nodegroups during off-hours to reduce costs.

## Features

- **ECS Support**
  - Scales services to 0 desired tasks at specified time
  - Restores original desired task count from DynamoDB
  - Handles standalone tasks

- **EKS Support**
  - Scales nodegroup ASGs to 0 capacity
  - Restores original min/max/desired ASG values
  - Works with multiple nodegroups per cluster

- **Unified Architecture**
  - Single DynamoDB table for both ECS/EKS configurations
  - Shared IAM role and EventBridge rules
  - Configurable schedules
  - Error handling and logging

## Prerequisites

- Terraform 1.0+
- AWS provider configured with proper credentials
- Existing ECS clusters/EKS clusters
- EKS nodegroups using Auto Scaling Groups
- Nodegroups must allow scaling to 0 (adjust min_size if needed)

## Installation

1. Clone repository:
```bash
git clone git@github.com:geek0ps/terraform_automation.git
cd modules/automated_ecs_eks_downsizing_module
```

2. Initialize Terraform:
```bash
terraform init
```

## Usage

### Basic Configuration (terraform.tfvars)
```hcl
enable_ecs         = true
enable_eks         = true
ecs_cluster_names  = ["ecs-production"]
eks_cluster_names  = ["eks-production"]
schedule_scale_down = "cron(30 14 * * ? *)" # 2:30 PM GMT
schedule_scale_up   = "cron(0 4 * * ? *)"   # 4:00 AM GMT
```

### Apply Configuration
```bash
terraform plan
terraform apply
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_ecs` | Enable ECS scheduling | bool | `false` |
| `enable_eks` | Enable EKS scheduling | bool | `false` |
| `ecs_cluster_names` | List of ECS cluster names | list(string) | `[]` |
| `eks_cluster_names` | List of EKS cluster names | list(string) | `[]` |
| `schedule_scale_down` | Scale-down cron schedule | string | `"cron(30 14 * * ? *)"` |
| `schedule_scale_up` | Scale-up cron schedule | string | `"cron(0 4 * * ? *)"` |

## Outputs

| Name | Description |
|------|-------------|
| `dynamodb_table` | Configuration storage table name |
| `scale_down_lambda` | ARN of scale-down Lambda function |
| `scale_up_lambda` | ARN of scale-up Lambda function |

## Notes

1. **Existing Resources**
   - Does not create ECS/EKS clusters - manages existing resources
   - Ensure clusters are properly tagged if using tag-based filtering

2. **Scaling Operations**
   - ECS: Services return to original desired count
   - EKS: ASGs restore original min/max/desired values
   - Operations take 5-15 minutes to complete

3. **Error Handling**
   - Failed operations logged to CloudWatch
   - Partial failures don't block other resources
   - Retained DynamoDB entries indicate failed restorations

4. **Cost Considerations**
   - EKS control plane costs still apply
   - DynamoDB costs negligible for typical usage
   - Lambda costs minimal (<$1/month)

## Troubleshooting

1. **Check CloudWatch Logs**
   - `/aws/lambda/ecs-scale-down`
   - `/aws/lambda/ecs-scale-up`
   - `/aws/lambda/eks-scale-down`
   - `/aws/lambda/eks-scale-up`

2. **Common Issues**
   - **Permissions**: Verify Lambda execution role has required policies
   - **Cluster Names**: Ensure exact cluster name matches
   - **DynamoDB**: Confirm table exists and has proper schema

3. **Manual Testing**
```bash
# Test scale-down
aws lambda invoke --function-name ecs-scale-down response.json
aws lambda invoke --function-name eks-scale-down response.json

# Test scale-up 
aws lambda invoke --function-name ecs-scale-up response.json
aws lambda invoke --function-name eks-scale-up response.json
```

## License

Apache 2.0 Licensed. See [LICENSE](LICENSE) for full details.
