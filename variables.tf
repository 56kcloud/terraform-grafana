#---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which the ECS Service will be created."
  type        = string
}

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
}

variable "platform_version" {
  description = "The ECS Fargate version to run Grafana on"
  type        = string
}

variable "ecs_cluster" {
  description = "The ECS cluster to run the service on"
  type        = string
}

# Docker image configuration

variable "image" {
  description = "The Docker image to run"
  type        = string
}

variable "image_version" {
  description = "Which version (AKA tag) of the var.image Docker image to deploy (e.g. 0.57)"
  type        = string
}

variable "container_port" {
  description = "The port number on which this service's Docker container accepts incoming HTTP or HTTPS traffic."
  type        = number
}

variable "cloudwatch_log_group_name" {
  description = "The name of the cloudwatch log group where the application will send logs to"
  type        = string
}

# Runtime properties of this ECS Service in the ECS Cluster

variable "cpu" {
  description = "The number of CPU units to allocate to the ECS Service."
  type        = number
}

variable "memory" {
  description = "How much memory, in MB, to give the ECS Service."
  type        = number
}

variable "desired_number_of_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster"
  type        = number
}

variable "allow_inbound_from_cidr_blocks" {
  description = "A list of IP CIDR blocks allowed to access the service"
  type        = list
}

# VPC information

variable "vpc_id" {
  description = "The VPC ID in which to deploy the resources"
  type        = string
}

variable "private_subnet_ids" {
  description = "The list of private subnet IDs"
  type        = list
}

variable "public_subnet_ids" {
  description = "The list of public subnet IDs"
  type        = list
}

variable "ssl_cert_arn" {
  description = "The ARN of the SSL certificate to use on the ALB"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 1800. Only valid for services configured to use load balancers."
  type        = number
  default     = 15
}

# ALB options

variable "alb_target_group_protocol" {
  description = "The network protocol to use for routing traffic from the ALB to the Targets. Must be one of HTTP or HTTPS. Note that if HTTPS is used, per https://goo.gl/NiOVx7, the ALB will use the security settings from ELBSecurityPolicy2015-05."
  type        = string
  default     = "HTTP"
}

variable "alb_target_group_deregistration_delay" {
  description = "The amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds."
  type        = number
  default     = 15
}

# Deployment Options

variable "deployment_maximum_percent" {
  description = "The upper limit, as a percentage of var.desired_number_of_tasks, of the number of running ECS Tasks that can be running in a service during a deployment. Setting this to more than 100 means that during deployment, ECS will deploy new instances of a Task before undeploying the old ones."
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The lower limit, as a percentage of var.desired_number_of_tasks, of the number of running ECS Tasks that must remain running and healthy in a service during a deployment. Setting this to less than 100 means that during deployment, ECS may undeploy old instances of a Task before deploying new ones."
  type        = number
  default     = 100
}

# Health check options

variable "health_check_interval" {
  description = "The approximate amount of time, in seconds, between health checks of an individual Target. Minimum value 5 seconds, Maximum value 300 seconds."
  type        = number
  default     = 30
}

variable "health_check_protocol" {
  description = "The protocol the ALB uses when performing health checks on Targets. Must be one of HTTP and HTTPS."
  type        = string
  default     = "HTTP"
}

variable "health_check_timeout" {
  description = "The amount of time, in seconds, during which no response from a Target means a failed health check. The acceptable range is 2 to 60 seconds."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successful health checks required before considering an unhealthy Target healthy. The acceptable range is 2 to 10."
  type        = number
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failed health checks required before considering a target unhealthy. The acceptable range is 2 to 10."
  type        = number
  default     = 2
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from a Target. You can specify multiple values (e.g. '200,202') or a range of values (e.g. '200-299')."
  type        = string
  default     = "200"
}

