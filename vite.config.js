import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import { bunny } from 'laravel-vite-plugin/fonts';
import tailwindcss from '@tailwindcss/vite';

const viteDomain = process.env.VITE_DOMAIN || 'vite.app.localhost';
const vitePort = Number(process.env.VITE_PORT || 5173);

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
            fonts: [
                bunny('Instrument Sans', {
                    weights: [400, 500, 600],
                }),
            ],
        }),
        tailwindcss(),
    ],
    server: {
        host: '0.0.0.0',
        port: vitePort,
        strictPort: true,
        origin: `https://${viteDomain}`,
        hmr: {
            protocol: 'wss',
            host: viteDomain,
            clientPort: 443,
        },
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
