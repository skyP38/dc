local PR = require("package")

return {
    name = "hello",
    version = "1.0.0",
    source = {
        url = "https://www.lua.org/ftp/lua-5.4.4.tar.gz",
        hash = "sha256:164c7849653b80ae67bec4b7473b884bf5cc8d2dca05653475ec2ed27b9ebf61"
    },
    dependencies = {"lib1", "lib2"}
}
