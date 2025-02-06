# Lambda Code Definitions
data "archive_file" "ecs_scale_down" {
  count = var.enable_ecs ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/ecs_scale_down.zip"

  source {
    content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    ecs = boto3.client('ecs')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['CONFIG_TABLE'])
    
    clusters = os.environ['CLUSTER_NAMES'].split(',')
    
    for cluster in clusters:
        try:
            # List all services
            services = ecs.list_services(clusterName=cluster)['serviceArns']
            
            for service_arn in services:
                # Get current service configuration
                service = ecs.describe_services(
                    cluster=cluster,
                    services=[service_arn]
                )['services'][0]
                
                if service['desiredCount'] > 0:
                    # Store original configuration
                    table.put_item(Item={
                        'resource_type': 'ecs_service',
                        'resource_arn': service_arn,
                        'cluster_name': cluster,
                        'desired_count': service['desiredCount']
                    })
                    
                    # Scale down to 0
                    ecs.update_service(
                        cluster=cluster,
                        service=service_arn,
                        desiredCount=0
                    )
        
        except Exception as e:
            print(f"Error processing {cluster}: {str(e)}")
            continue
    
    return {"status": "success"}
EOF
    filename = "ecs_scale_down.py"
  }
}

data "archive_file" "ecs_scale_up" {
  count = var.enable_ecs ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/ecs_scale_up.zip"

  source {
    content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    ecs = boto3.client('ecs')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['CONFIG_TABLE'])
    
    # Get all ECS service configurations
    response = table.scan(
        FilterExpression="resource_type = :rtype",
        ExpressionAttributeValues={":rtype": "ecs_service"}
    )
    
    for item in response['Items']:
        try:
            # Restore original desired count
            ecs.update_service(
                cluster=item['cluster_name'],
                service=item['resource_arn'],
                desiredCount=int(item['desired_count'])
            )
            
            # Remove entry from DynamoDB
            table.delete_item(Key={
                'resource_type': item['resource_type'],
                'resource_arn': item['resource_arn']
            })
        
        except Exception as e:
            print(f"Error restoring {item['resource_arn']}: {str(e)}")
            continue
    
    return {"status": "success"}
EOF
    filename = "ecs_scale_up.py"
  }
}

data "archive_file" "eks_scale_down" {
  count = var.enable_eks ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/eks_scale_down.zip"

  source {
    content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    eks = boto3.client('eks')
    asg = boto3.client('autoscaling')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['CONFIG_TABLE'])
    
    clusters = os.environ['CLUSTER_NAMES'].split(',')
    
    for cluster in clusters:
        try:
            # Get all nodegroups in the cluster
            nodegroups = eks.list_nodegroups(clusterName=cluster)['nodegroups']
            
            for ng in nodegroups:
                # Get nodegroup details
                ng_info = eks.describe_nodegroup(
                    clusterName=cluster,
                    nodegroupName=ng
                )['nodegroup']
                
                # Find associated Auto Scaling Groups
                asg_names = []
                for resource in ng_info['resources']['autoScalingGroups']:
                    asg_names.append(resource['name'])
                
                # Process each ASG
                for asg_name in asg_names:
                    # Get current ASG config
                    asg_config = asg.describe_auto_scaling_groups(
                        AutoScalingGroupNames=[asg_name]
                    )['AutoScalingGroups'][0]
                    
                    # Save original config to DynamoDB
                    table.put_item(Item={
                        'nodegroup_name': ng,
                        'cluster_name': cluster,
                        'min_size': asg_config['MinSize'],
                        'max_size': asg_config['MaxSize'],
                        'desired_capacity': asg_config['DesiredCapacity']
                    })
                    
                    # Scale down to 0
                    asg.update_auto_scaling_group(
                        AutoScalingGroupName=asg_name,
                        MinSize=0,
                        MaxSize=0,
                        DesiredCapacity=0
                    )
        
        except Exception as e:
            print(f"Error processing {cluster}: {str(e)}")
            continue
    
    return {"status": "success"}
EOF
    filename = "eks_scale_down.py"
  }
}

data "archive_file" "eks_scale_up" {
  count = var.enable_eks ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/eks_scale_up.zip"

  source {
    content  = <<EOF
import boto3
import os

def lambda_handler(event, context):
    asg = boto3.client('autoscaling')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['CONFIG_TABLE'])
    
    # Get all stored configurations
    items = table.scan()['Items']
    
    for item in items:
        try:
            # Restore original configuration
            asg.update_auto_scaling_group(
                AutoScalingGroupName=item['nodegroup_name'],
                MinSize=item['min_size'],
                MaxSize=item['max_size'],
                DesiredCapacity=item['desired_capacity']
            )
            
            # Remove entry from DynamoDB
            table.delete_item(Key={'nodegroup_name': item['nodegroup_name']})
        
        except Exception as e:
            print(f"Error restoring {item['nodegroup_name']}: {str(e)}")
            continue
    
    return {"status": "success"}
EOF
    filename = "eks_scale_up.py"
  }
}
