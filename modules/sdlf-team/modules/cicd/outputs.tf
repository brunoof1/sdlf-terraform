output "datalake_library_layer_repo_clone_url" {
  value = aws_codecommit_repository.datalake_library_layer.clone_url_ssh
}

output "pip_libraries_repo_clone_url" {
  value = aws_codecommit_repository.pip_libraries.clone_url_ssh
}
