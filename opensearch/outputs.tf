output "opensearch_domain" {
  value = aws_opensearch_domain.opensearch.endpoint
}
output "opensearch_domain_name" {
  value = aws_opensearch_domain.opensearch.domain_name
}