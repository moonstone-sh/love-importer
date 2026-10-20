package.path = "src/?.lua;src/?/init.lua;" .. package.path
local ballad = require("ballad")

return ballad.partiture(function(p)
	local moonstone = p:use(ballad.plugins.moonstone)
	local layout = p:use(ballad.plugins.layout)

	local project = moonstone.project({ root = "." })

	local build = moonstone:run("build", {
		inputs = {
			"scripts/build.lua",
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
		packages = { "moonstone/clingy", "moonstone/valua", "moonstone/alter", "moonstone/alter-jsonc", "moonstone/alter-json", "moonstone/luals-composer", "dkjson" },
		depends_on = build,
	})

	local artifact = moonstone.registry.package(app, {
		name = project.registry_name or "moonstone/love-importer",
		version = project.version,
		target = require("love_importer.util").host_target(),
		runtime = project.runtime or "lua@5.4",
		lua_abi = project.lua_abi or "5.4",
		description = project.description,
		dependencies = {
			{ name = "moonstone/clingy", constraint = "^0.8.0", role = "runtime" },
            { name = "dkjson", constraint = "^2.9-1", resolver = "rocks", role = "runtime" },
		},
	})

	p.sink.none(build)
	p.sink.directory(app, {
		out = "dist/love-importer",
		file_graph = true,
	})
	p.sink.artifact(artifact, { out = "dist/love-importer/registry-artifact" })
end)
