vim.filetype.add({
  extension = {
    gotmpl = "gotmpl",
    templ = "templ",
    tfvars = "terraform-vars",
  },
  filename = {
    ["go.work"] = "gowork",
    ["docker-compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["compose.yaml"] = "yaml.docker-compose",
  },
})
