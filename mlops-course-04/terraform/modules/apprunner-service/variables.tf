variable "name" {
  description = "Resource name suffix."
  type        = string
}

variable "prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "ars"
}

variable "delimiter" {
  description = "Resource name delimiter."
  type        = string
  default     = "-"
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to attach to resource."
}

variable "source_configuration" {
  type        = any
  description = "The source to deploy to the App Runner service. Can be a code or an image repository."
}
