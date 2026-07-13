data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg"
  description = "Security group for Amazon Clone EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

resource "tls_private_key" "deployer" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.deployer.public_key_openssh
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = aws_subnet.public.id

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    kind_cluster_name = var.kind_cluster_name
    kind_worker_nodes = var.kind_worker_nodes
    project_name      = var.project_name
  }))

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.deployer.private_key_pem
    host        = self.public_ip
    port        = var.ssh_port
  }

  provisioner "file" {
    source      = "${path.root}/../"
    destination = "/home/ubuntu/${var.project_name}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/${var.project_name}/scripts/setup-cluster.sh",
      "sudo /home/ubuntu/${var.project_name}/scripts/setup-cluster.sh '${var.kind_cluster_name}' '${var.project_name}' '${var.kubernetes_namespace}' '${var.app_replicas}'"
    ]
  }

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.deployer.private_key_pem
  filename        = "${path.module}/generated-key.pem"
  file_permission = "0600"
}

resource "null_resource" "download_kubeconfig" {
  depends_on = [aws_instance.main, local_file.private_key]

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${path.module}/generated-key.pem ubuntu@${aws_instance.main.public_ip}:/home/ubuntu/.kube/config ${path.module}/kubeconfig"
  }
}
