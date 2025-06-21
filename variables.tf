variable "mgc_api_key" {
  description = "API Key da Magalu Cloud para testes"
  type        = string
  sensitive   = true
}

variable "mgc_region" {
  description = "Região da Magalu Cloud (ex: br-se1)"
  type        = string
  default     = "br-se1"
}

variable "container_registry_name" {
  description = "The name of the container registry to create."
  type        = string
  default     = "my-container-registry"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.container_registry_name)) && length(var.container_registry_name) >= 2 && length(var.container_registry_name) <= 63
    error_message = "Container registry name must be between 2-63 characters, start and end with alphanumeric characters, and contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = !can(regex("--", var.container_registry_name))
    error_message = "Container registry name cannot contain consecutive hyphens."
  }
}

variable "enable_credentials_output" {
  description = "Whether to output container registry credentials. Set to true if you need access credentials."
  type        = bool
  default     = false
}

variable "enable_registries_list" {
  description = "Whether to fetch a list of all container registries. Useful for reference or comparison."
  type        = bool
  default     = false
}

variable "enable_repositories_data" {
  description = "Whether to fetch repositories data from the created registry."
  type        = bool
  default     = false
}

variable "repository_name" {
  description = "Name of a specific repository to fetch images data from. Leave null if not needed."
  type        = string
  default     = null

  validation {
    condition     = var.repository_name == null || can(regex("^[a-z0-9][a-z0-9._/-]*[a-z0-9]$", var.repository_name))
    error_message = "Repository name must start and end with alphanumeric characters and can contain lowercase letters, numbers, dots, underscores, hyphens, and forward slashes."
  }

  validation {
    condition     = var.repository_name == null || length(var.repository_name) <= 256
    error_message = "Repository name must be 256 characters or less."
  }
}

variable "enable_images_data" {
  description = "Whether to fetch images data from the specified repository. Requires repository_name to be set."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_images_data || var.repository_name != null
    error_message = "enable_images_data requires repository_name to be specified."
  }
}
