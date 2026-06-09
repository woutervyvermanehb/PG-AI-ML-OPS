module "ecr_repository" {
  for_each = { for ecr in var.ecr_repositories : ecr.key => ecr }
  source   = "./modules/ecr-repository"

  name                         = join(var.delimiter, [each.value.key, var.environment])
  image_tag_mutability         = each.value.image_tag_mutability
  image_scanning_configuration = each.value.image_scanning_configuration
  tags                         = merge(try(each.value.tags, {}), { environment = var.environment })
}
