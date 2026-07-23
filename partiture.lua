local ballad = require("ballad")

return ballad.partiture(function(p)
	local moonstone = p:use(ballad.plugins.moonstone)
	local layout = p:use(ballad.plugins.layout)

	local project = moonstone.project({ root = "." })

	local build = moonstone:run("build", {
		inputs = {
			"src/main.moon",
			"src/love_importer/*.moon",
			"src/love_importer/*.lua",
		},
		outputs = { "build/src" },
	})

	local app = layout.libexec(project, {
		name = "love-importer",
		entry = "build/src/main.lua",
		bin = "love-importer",
		interpreter = "lua",
		bundle_runtime = true,
		include = { "build/src/**" },
		lua_paths = { "lua", "build/src" },
		packages = { "argparse" },
		depends_on = build,
	})

	local artifact = moonstone.registry.package(app, {
		name = project.registry_name or "moonstone/love-importer",
		version = project.version,
		target = "any",
		runtime = project.runtime or "lua@5.1",
		lua_abi = project.lua_abi or "5.1",
		description = project.description,
	})

	p.sink.none(build)
	p.sink.directory(app, {
		out = "dist/love-importer",
		file_graph = true,
	})
	p.sink.artifact(artifact, { out = "dist/love-importer/registry-artifact" })
end)
