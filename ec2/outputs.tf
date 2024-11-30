output "opensearch_proxy_dns" {
  value = aws_instance.opensearch_proxy.public_dns
}