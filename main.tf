# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A GRAFANA SERVICE ON ECS FARGATE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELASTIC FILE SYSTEM (NFS) TO PROVIDE PERMANENT STORAGE FOR GRAFANA 
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_efs_file_system" "ecs_service_storage" {
  tags = {
    Name = "${var.service_name}-efs"
  }
}

resource "aws_efs_mount_target" "ecs_service_storage" {
  count           = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.ecs_service_storage.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE CLOUDWATCH LOG GROUP FOR THIS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs_service" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 30
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS TASK TO RUN THE DOCKER CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

# Define the Assume Role IAM Policy Document for the ECS Service Scheduler IAM Role
data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Create the IAM roles for the ECS Task
resource "aws_iam_role" "ecs_task_execution_role" {
  name                 = "${var.service_name}-task-execution-role"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task.json
}
resource "aws_iam_role" "ecs_task_role" {
  name                 = "${var.service_name}-task-role"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task.json
}

# This template_file defines the Docker containers we want to run in our ECS Task
data "template_file" "ecs_task_container_definitions" {
  template = file("${path.module}/container-definition/container-definition.json")

  vars = {
    aws_region = var.aws_region
    container_name = var.service_name
    service_name = var.service_name
    image = var.image
    version = var.image_version
    cloudwatch_log_group_name = var.cloudwatch_log_group_name
    cpu = var.cpu
    memory = var.memory
    container_port = var.container_port
  }
}

# Create the actual task definition by passing it the container definition from above
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                    = var.service_name
  container_definitions     = data.template_file.ecs_task_container_definitions.rendered
  network_mode              = "awsvpc"
  cpu                       = var.cpu
  memory                    = var.memory
  requires_compatibilities  = ["FARGATE", "EC2"]
  task_role_arn             = aws_iam_role.ecs_task_role.arn
  execution_role_arn        = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "grafana-db"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.ecs_service_storage.id
      root_directory = "/grafana"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE EXTRA IAM POLICIES FOR THE ECS SERVICE AND TASK
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_policy" "ecs_task_custom_policy" {
  name = "${var.service_name}-ecs-task-custom-policy"
  path = "/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadingTagsInstancesRegionsFromEC2",
      "Effect": "Allow",
      "Action": ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingResourcesForTags",
      "Effect": "Allow",
      "Action": "tag:GetResources",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_custom" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}
resource "aws_iam_role_policy_attachment" "task_ecr" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_iam_role_policy_attachment" "task_cloudwatch" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}
resource "aws_iam_role_policy_attachment" "task_ssm_ro" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "task_execution_custom" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_custom_policy.arn
}
resource "aws_iam_role_policy_attachment" "task_execution_ecr" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_iam_role_policy_attachment" "task_execution_cloudwatch" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}
resource "aws_iam_role_policy_attachment" "task_execution_ssm_ro" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS SERVICE TO RUN THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

# Create the ECS service
resource "aws_ecs_service" "ecs_service" {
  name                                = var.service_name
  cluster                             = var.ecs_cluster
  task_definition                     = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count                       = var.desired_number_of_tasks
  deployment_maximum_percent          = var.deployment_maximum_percent
  deployment_minimum_healthy_percent  = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds   = var.health_check_grace_period_seconds
  launch_type                         = "FARGATE"
  platform_version                    = var.platform_version
  depends_on                          = [aws_lb_target_group.target_group]

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets             = var.private_subnet_ids
    security_groups     = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip    = var.assign_public_ip
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LB TARGET GROUP TO WHICH THE SERVICE ABOVE WILL ATTACH
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb_target_group" "target_group" {
  name                  = var.service_name
  port                  = var.container_port
  protocol              = var.alb_target_group_protocol
  target_type           = "ip"
  vpc_id                = var.vpc_id
  deregistration_delay  = var.alb_target_group_deregistration_delay

  health_check {
    enabled             = true
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = var.container_port
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = var.health_check_matcher
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE APPLICATION LOAD BALANCER FOR THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

# Define a S3 bucket for the ALB logs
resource "aws_s3_bucket" "alb_logs_s3_bucket" {
  bucket_prefix = "${var.service_name}-alb-logs"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_policy" "alb_logs_s3_bucket" {
  bucket = aws_s3_bucket.alb_logs_s3_bucket.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "enable_load_balancer_to_write_logs",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com",
        "AWS": "arn:aws:iam::127311923021:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.alb_logs_s3_bucket.bucket}/*"
    }
  ]
}
POLICY
}

# Create the actual ALB
resource "aws_lb" "ecs_alb" {
  name                              = "${var.service_name}-alb"
  internal                          = false
  load_balancer_type                = "application"
  security_groups                   = ["${aws_security_group.alb_sg.id}"]
  subnets                           = var.public_subnet_ids
  enable_cross_zone_load_balancing  = true
  enable_http2                      = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs_s3_bucket.bucket
    enabled = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE HTTP(S) LISTENERS
# These will accept the HTTP(S) requests and forward them to the proper target groups
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}
