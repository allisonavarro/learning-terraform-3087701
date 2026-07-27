# 1. Fetch the latest official and free Ubuntu 24.04 AMI
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Create the Security Group for Web Access
resource "aws_security_group" "tomcat_sg" {
  name        = "tomcat-web-access"
  description = "Allow inbound traffic for Tomcat server"

  # HTTP Traffic (Standard Web)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tomcat Specific Port
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to your IP (e.g., "1.2.3.4/32") for better security
  }

  # SSH Traffic (Optional, for server management)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Highly recommended to change this to your specific public IP
  }

  # Outbound Rules (Allows instance to download internet updates/packages)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Deploy Free-Tier EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t2.micro" # Free Tier eligible

  # Attach the Security Group
  vpc_security_group_ids = [aws_security_group.tomcat_sg.id]

  # Automatically install Tomcat 10 on boot
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y tomcat10 tomcat10-admin
              sudo systemctl start tomcat10
              sudo systemctl enable tomcat10
              EOF

  tags = {
    Name = "Tomcat-Free-Tier"
  }
}

# 4. Output the public URL to easily click and test
output "tomcat_url" {
  value       = "http://${aws_instance.web.public_ip}:8080"
  description = "The public web address for your Tomcat server"
}
