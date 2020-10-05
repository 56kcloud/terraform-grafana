# Grafana on ECS Fargate

This Terraform Module deploys Grafana on ECS Fargate with an ALB on top of an ECS Cluster.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.

## What is an ECS Service?

To run Docker containers with ECS, you first define an [ECS
Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_defintions.html), which is a JSON file that
describes what container(s) to run, the resources (memory, CPU) those containers need, the volumes to mount, the
environment variables to set, and so on. To actually run an ECS Task, you define an ECS Service, which can:

1. Deploy the requested number of Tasks across an ECS cluster based on the `desired_number_of_tasks` input variable.
1. Restart tasks if they fail.

## What is an ALB?

An [Application Load Balancer](http://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) is
a "Layer 7" load balancer managed by AWS that forwards incoming requests to the ECS Tasks (Docker containers) in your ECS
Service which are running in your ECS Cluster.

It automatically discovers new ECS Tasks as they launch. A single ALB is shared among potentially many ECS Services.

