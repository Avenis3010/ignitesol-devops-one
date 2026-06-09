resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend-api-${var.env}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  tags = var.tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend-ui-${var.env}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  tags = var.tags
}
