module "apprunner_service" {
  for_each = { for ars in var.apprunner_services : ars.key => ars }
  source   = "./modules/apprunner-service"

  name                 = join(var.delimiter, [each.value.key, var.environment])
  source_configuration = each.value.source_configuration
  tags                 = merge(try(each.value.tags, {}), { environment = var.environment })
}
