// This server does not serve Next.js apps.
// It is usefull to debug deployment issues.
// Just replace all occurences of `expressWithNext.js` with `expressOnly.js` in .env
// in order to use this as your main lambda function.
const express = require("express");
const serverless = require("serverless-http");

function getServer() {
	return new Promise((resolve, reject) => {
		const server = express();

		server.all("*", (req, res) => {
			return res.end("Hello world!!!");
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
