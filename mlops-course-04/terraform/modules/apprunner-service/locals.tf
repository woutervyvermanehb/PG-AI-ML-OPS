locals {
  service_name = join(var.delimiter, [var.prefix, var.name])
}
