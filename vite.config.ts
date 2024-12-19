import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		fs: { allow: ["./triplit"] },
		host: true,
		port: 3000,
		watch: {
			usePolling: true,
			interval: 100,
		},
	},
});
