variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "amazon-clone"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the instance (your public IP /32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = "amazon-clone-key"
}

variable "kind_cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "amazon-clone-cluster"
}

variable "kind_worker_nodes" {
  description = "Number of Kind worker nodes"
  type        = number
  default     = 1
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "amazon-clone"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}
