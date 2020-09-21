const express = require("express");
const next = require("next");
const serverless = require("serverless-http");

function getServer() {
	return new Promise(async (resolve, reject) => {
		const server = express();
		const app = next({ dev: process.env.NODE_ENV !== "production", dir: "." });

		await app.prepare();
		const handle = app.getRequestHandler();

		server.all("*", (req, res) => {
			return handle(req, res);
		});

		return resolve(server);
	});
}

if (process.env.X_HOST === "local") {
	(async () => {
		const server = await getServer();
		server.listen({ port: process.env.APP_PORT }, "localhost", function(error) {
			if (error) throw new Error(error);
			const appUrl = "http://localhost:" + process.env.APP_PORT;
			console.log("Running on", appUrl);
		});
	})();
}

exports.handler = async (event, context) => {
	const server = await getServer();
	const handler = serverless(server);
	const result = await handler(event, context);
	return result;
};
