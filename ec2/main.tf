data "template_file" "opensearch_script" {
  template = file("./ec2/user-data.sh")
  vars = {
    opensearch_domain = var.opensearch_domain
    cognito_domain    = var.cognito_domain
  }
}

resource "aws_instance" "opensearch_proxy" {
  ami                    = "ami-0ebfd941bbafe70c6"
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.opensearch_proxy_sg.id]
  subnet_id              = var.public_subnet_id
  user_data = data.template_file.opensearch_script.rendered
  tags = {
    Name = "opensearch_proxy"
  }
}

resource "aws_security_group" "opensearch_proxy_sg" {
  name   = "opensearch_proxy_sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "opensearch_proxy_sg"
  }
}
