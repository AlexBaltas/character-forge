output "ec2_public_ip" {
  description = "Public Ip address of the character forge EC2 instance"
  value       = aws_instance.character_forge.public_ip
}