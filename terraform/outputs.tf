output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.main.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${path.module}/generated-key.pem ubuntu@${aws_instance.main.public_ip}"
}

output "website_url" {
  description = "URL to access the Amazon Clone website"
  value       = "http://${aws_instance.main.public_ip}"
}

output "kind_cluster_name" {
  description = "Name of the Kind cluster"
  value       = var.kind_cluster_name
}

output "kubeconfig_path" {
  description = "Path to the downloaded kubeconfig file"
  value       = "${path.module}/kubeconfig"
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}
