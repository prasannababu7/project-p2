# output "repository_clone_url_http" {
#   value = aws_codecommit_repository.my_frontend_repo.clone_url_http
# }

# output "repository_clone_url_ssh" {
#   value = aws_codecommit_repository.my_frontend_repo.clone_url_ssh
# }

output "static_web_hosting_url" {
  value = aws_s3_bucket.myfrontendbucket.website_endpoint
}
