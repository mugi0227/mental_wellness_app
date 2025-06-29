const { configureGenkit } = require("genkit");
const { firebase } = require("@genkit-ai/firebase");
const { googleAI } = require("@genkit-ai/googleai");

configureGenkit({
  plugins: [
    // GenkitをFirebase上で動かすためのプラグイン
    firebase(),
    // Google AI (Gemini) を使うためのプラグイン
    googleAI({ apiVersion: "v1beta" }), // v1betaでSystem Promptに対応
  ],
  logLevel: "debug",
  enableTracingAndMetrics: true,
});
