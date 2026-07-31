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

data "aws_vpc" "default" {
  default = true
}


# Deploy Free-Tier EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t3.micro" # Free Tier eligible

  # Attach the Security Group
  vpc_security_group_ids = [module.http_80_security_group.id]

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

module "http_80_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 6.0"

  name        = "http-80"
  description = "Security group for http-80"
  vpc_id      = data.aws_vpc.default.id

  # Opens HTTP (port 80) to the Internet
  ingress_cidr_ipv4 = {
    internet = "0.0.0.0/0"
  }

  # Allow all outbound traffic
  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
    }
  }
}

# 4. Output the public URL to easily click and test
output "tomcat_url" {
  value       = "http://${aws_instance.web.public_ip}:8080"
  description = "The public web address for your Tomcat server"
}
