resource "aws_opensearch_domain" "opensearch" {
  domain_name     = "thunder"
  ip_address_type = "ipv4"
  vpc_options {
    security_group_ids = [aws_security_group.opensearch_sg.id]
    subnet_ids         = [var.public_ids[0]]
  }
  cluster_config {
    instance_type                 = "t3.medium.search"
    instance_count                = 1
    multi_az_with_standby_enabled = false
    warm_enabled                  = false
  }
  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 50
  }
  cognito_options {
    enabled          = true
    identity_pool_id = var.identity_pool_id
    user_pool_id     = var.user_pool_id
    role_arn         = var.cognito_for_opensearch_role_arn
  }
  domain_endpoint_options {
    enforce_https = true
  }
  access_policies = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [var.cognito_role_arn, "arn:aws:iam::${var.account_id}:role/FluentBitRole", "arn:aws:iam::${var.account_id}:role/eks-node-group"]
        },
        "Action" : "es:*",
        "Resource" : "arn:aws:es:us-east-1:${var.account_id}:domain/thunder/*"
      }
    ]
  })
}

resource "aws_security_group" "opensearch_sg" {
  name   = "opensearch_sg"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "opensearch_sg"
  }
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["es:*"]
    resources = ["${aws_opensearch_domain.opensearch.arn}/*"]
  }
}
