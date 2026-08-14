variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2インスタンスのタイプ"
  type        = string
  default     = "t2.micro" 
}

variable "key_name" {
  description = "AWS EC2 Key Pair 名"
  type        = string
  default     = ""
}

variable "public_key_path" {
  description = "public keyパス"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "create_key_pair" {
  description = "Terraformで Key Pair を作成するかどうか（true の場合は key_name は無視される）"
  type        = bool
  default     = true
}

variable "ssh_private_key_path" {
  description = "private keyパス（Terraformで作成した Key Pair の private key を指定する）"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_user" {
  description = "ssh user（EC2のAMIによって異なる。Ubuntuならubuntu、Amazon Linuxならec2-user）"
  type        = string
  default     = "ubuntu"
}
