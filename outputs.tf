/*
Module outputs
*/

output "ecs_service_arn" {
  value = aws_ecs_service.ecs_service.id
}

output "ecs_task_iam_role_name" {
  value = aws_iam_role.ecs_task_role.name
}

output "aws_ecs_task_definition_arn" {
  value = aws_ecs_task_definition.ecs_task_definition.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.target_group.arn
}

output "fully_qualified_domain_name" {
  value = var.create_route53_entry ? var.domain_name : aws_lb.ecs_alb.dns_name
}

output "efs_volume_dns_name" {
  value = aws_efs_file_system.ecs_service_storage.dns_name
}
