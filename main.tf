terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "ansible" {}

# Key pair作成
resource "aws_key_pair" "demo" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = "terraform-ansible-demo-key"
  public_key = file(var.public_key_path)
}

locals {
  key_name = var.create_key_pair ? aws_key_pair.demo[0].key_name : var.key_name
}

# SG作成、port 22/80開放
resource "aws_security_group" "demo" {
  name        = "terraform-ansible-demo-sg"
  description = "Allow SSH and HTTP"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # demo 用，正式环境请收紧到你的 IP
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "terraform-ansible-demo-sg"
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical 官方账号

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 作成
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = local.key_name
  vpc_security_group_ids = [aws_security_group.demo.id]

  tags = {
    Name = "terraform-ansible-demo"
  }
}

# ssh 接続可能になるまで待つための null_resource（Terraform state に残る）
resource "null_resource" "wait_for_ssh" {
  triggers = {
    instance_id = aws_instance.web.id
  }

  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]

    connection {
      type        = "ssh"
      host        = aws_instance.web.public_ip
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      timeout     = "3m"
    }
  }
}

# ansible_host 作成（Ansible provider 用の inventory）
resource "ansible_host" "web" {
  name   = aws_instance.web.public_ip
  groups = ["web"]

  variables = {
    ansible_user                 = var.ssh_user
    ansible_ssh_private_key_file = var.ssh_private_key_path
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }

  depends_on = [null_resource.wait_for_ssh]
}

# ansible_playbook 実行
resource "ansible_playbook" "web" {
  playbook   = "${path.module}/ansible/playbook.yml"
  name       = ansible_host.web.name
  replayable = true # 毎回applyでplaybookを実行するために replayable を true に設定

  ignore_playbook_failure = false
  verbosity               = 0

  depends_on = [ansible_host.web]
}
