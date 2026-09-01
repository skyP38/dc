global record Source
    url: string
    hash: string
end

global record PackageRecipe
    name: string
    version: string
    source: Source
    dependencies: {string}
end

