variable "name" {
  description = "Resource name suffix."
  type        = string
}

variable "prefix" {
  description = "Resource name prefix."
  type        = string
  default     = "ecr"
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

variable "image_tag_mutability" {
  type        = string
  description = "The tag mutability setting for the repository."
  default     = "MUTABLE"
}

variable "image_scanning_configuration" {
  type        = map(string)
  description = "Configuration block that defines image scanning configuration for the repository."
  default     = {}
}
