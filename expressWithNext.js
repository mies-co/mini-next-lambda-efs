const express = require("express");
const next = require("next");
const serverless = require("serverless-http");

const path = require("path");
const fs = require("fs").promises;

const { X_MOUNT_PATH, X_TEST_FILE } = process.env;

const testFilePath = path.resolve(X_MOUNT_PATH, X_TEST_FILE);

function getServer() {
	return new Promise(async (resolve, reject) => {
		const server = express();
		const app = next({ dev: process.env.NODE_ENV !== "production", dir: "." });

		await app.prepare();
		const handle = app.getRequestHandler();

		// When ready with the initial setups, you may uncomment this in order to serve the Next.js app
		//
		// server.all("*", (req, res) => {
		// 	return handle(req, res);
		// });

		server.all("*", async (req, res) => {
			let filePaths = [];
			const errors = [];
			const content = [];

			// Demonstrate that Lambda can access files from inside the EFS mounted volume
			try {
				const fileContent = require(testFilePath);
				content.push(fileContent);
			} catch (err) {
				errors.push("require error:" + err.message);
			}

			try {
				const files = await fs.readdir(X_MOUNT_PATH);
				filePaths = filePaths.concat(files || []);
			} catch (err) {
				errors.push("readdir error:" + err.message);
			}

			return res.end(JSON.stringify({ testFilePath, filePaths, content, errors }, null, "\t"));
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
