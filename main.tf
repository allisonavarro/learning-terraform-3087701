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
  vpc_id  = data.aws_vpc.default.id

  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

# 4. Output the public URL to easily click and test
output "tomcat_url" {
  value       = "http://${aws_instance.web.public_ip}:8080"
  description = "The public web address for your Tomcat server"
}
