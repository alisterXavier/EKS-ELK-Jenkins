resource "aws_efs_file_system" "EFS" {
  tags = {
    Name = "EFS"
  }
}

resource "aws_efs_mount_target" "EFS_mount" {
  count          = length(var.public_subnet_ids)
  subnet_id      = var.public_subnet_ids[count.index]
  file_system_id = aws_efs_file_system.EFS.id
}
resource "aws_efs_file_system_policy" "EFS_policy" {
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "Policy1614277390150",
    "Statement" : [
      {
        "Sid" : "AllowRootAccess",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.account_id}:role/FluentBitEFSAccessRole"
        },
        "Action" : [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ],
        "Resource" : "arn:aws:elasticfilesystem:${var.region}:${var.account_id}:file-system/${aws_efs_file_system.EFS.id}",
        "Condition" : {
          "Bool" : {
            "elasticfilesystem:AccessedViaMountTarget" : "true"
          }
        }
      }
    ]
    }
  )
  file_system_id = aws_efs_file_system.EFS.id
}
