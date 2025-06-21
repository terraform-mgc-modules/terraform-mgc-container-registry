# Container Registry resource
resource "mgc_container_registries" "registry" {
  name = var.container_registry_name
}

# Data source for getting credentials (optional output)
data "mgc_container_credentials" "creds" {
  count = var.enable_credentials_output ? 1 : 0
}

# Data source for listing all registries (optional for reference)
data "mgc_container_registries" "all_registries" {
  count = var.enable_registries_list ? 1 : 0
}

# Data source for getting repositories in the created registry
data "mgc_container_repositories" "repositories" {
  count       = var.enable_repositories_data ? 1 : 0
  registry_id = mgc_container_registries.registry.id

  depends_on = [mgc_container_registries.registry]
}

# Data source for getting images from a specific repository (if repository name is provided)
data "mgc_container_images" "images" {
  count           = var.repository_name != null && var.enable_images_data ? 1 : 0
  registry_id     = mgc_container_registries.registry.id
  repository_name = var.repository_name

  depends_on = [mgc_container_registries.registry]
}
