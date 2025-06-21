# Registry outputs
output "container_registry_id" {
  description = "The unique identifier of the created container registry"
  value       = mgc_container_registries.registry.id
}

output "container_registry_name" {
  description = "The name of the created container registry"
  value       = mgc_container_registries.registry.name
}

output "container_registry_created_at" {
  description = "The timestamp when the registry was created (available only when enable_registries_list is true)"
  value = var.enable_registries_list ? try(
    [for registry in data.mgc_container_registries.all_registries[0].registries :
    registry.created_at if registry.id == mgc_container_registries.registry.id][0],
    null
  ) : null
}

output "container_registry_updated_at" {
  description = "The timestamp when the registry was last updated (available only when enable_registries_list is true)"
  value = var.enable_registries_list ? try(
    [for registry in data.mgc_container_registries.all_registries[0].registries :
    registry.updated_at if registry.id == mgc_container_registries.registry.id][0],
    null
  ) : null
}

output "container_registry_storage_usage_bytes" {
  description = "The storage usage in bytes of the registry (available only when enable_registries_list is true)"
  value = var.enable_registries_list ? try(
    [for registry in data.mgc_container_registries.all_registries[0].registries :
    registry.storage_usage_bytes if registry.id == mgc_container_registries.registry.id][0],
    null
  ) : null
}

# Credentials outputs (optional)
output "container_credentials" {
  description = "Container registry authentication credentials"
  value = var.enable_credentials_output ? {
    username = try(data.mgc_container_credentials.creds[0].username, null)
    email    = try(data.mgc_container_credentials.creds[0].email, null)
    password = try(data.mgc_container_credentials.creds[0].password, null)
  } : null
  sensitive = true
}

# All registries output (optional)
output "all_registries" {
  description = "List of all container registries in the account"
  value       = var.enable_registries_list ? try(data.mgc_container_registries.all_registries[0].registries, []) : []
}

# Repositories output (optional)
output "repositories" {
  description = "List of repositories in the created registry"
  value       = var.enable_repositories_data ? try(data.mgc_container_repositories.repositories[0].repositories, []) : []
}

# Images output (optional)
output "images" {
  description = "List of images in the specified repository"
  value       = var.repository_name != null && var.enable_images_data ? try(data.mgc_container_images.images[0].images, []) : []
}

