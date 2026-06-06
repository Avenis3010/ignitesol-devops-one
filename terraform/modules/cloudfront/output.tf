output "cloudfront_domain"  { value = aws_cloudfront_distribution.cdn.domain_name }
output "distribution_arn"   { value = aws_cloudfront_distribution.cdn.arn }
output "distribution_id"    { value = aws_cloudfront_distribution.cdn.id }
