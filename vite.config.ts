import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');
    const port = Number(env.VITE_PORT || '5173');
    const domain = env.VITE_DOMAIN || 'localhost';

    return {
        plugins: [
            laravel({
                input: ['resources/css/app.css', 'resources/js/app.js'],
                refresh: true,
            }),
            tailwindcss(),
        ],
        server: {
            host: '0.0.0.0',
            port,
            strictPort: true,
            origin: `https://${domain}`,
            hmr: {
                host: domain,
                port: 443,
                protocol: 'wss',
            },
            watch: {
                ignored: ['**/storage/framework/views/**'],
            },
        },
    };
});
