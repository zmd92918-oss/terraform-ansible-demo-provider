output "instance_public_ip" {
  description = "EC2 publicIP"
  value       = aws_instance.web.public_ip
}

output "nginx_url" {
  description = "Nginx URL"
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${aws_instance.web.public_ip}"
}

# ansible playbookの実行結果を出力するための output
output "ansible_playbook_stdout" {
  description = "Ansible playbookの実行結果の stdout"
  value       = ansible_playbook.web.ansible_playbook_stdout
}

output "ansible_playbook_stderr" {
  description = "Ansible playbookの実行結果の stderr"
  value       = ansible_playbook.web.ansible_playbook_stderr
}
