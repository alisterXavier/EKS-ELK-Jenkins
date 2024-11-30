output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "lb_security_group_id" {
  value = aws_security_group.lb.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "Vpc_Id" {
  value = aws_vpc.vpc.id
}
output "node_group_sg_id" {
  value = aws_security_group.node_group.id
}
