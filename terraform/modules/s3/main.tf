resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${var.env}-${random_id.suffix.hex}"
  tags   = var.tags
}

resource "random_id" "suffix" {
  byte_length = 4
}
