// Browser smoke test: loads the web export in the installed Chrome (headless), checks the boot line,
// fails on any console SCRIPT ERROR / engine ERROR, and (M1) waits for the campus check to show an
// open WebSocket with a round-trip time.
// Usage: node web_check.js <url> [mode]   (mode: campus)
// Playwright comes from Website\game-sim-server\node_modules (set NODE_PATH or run via the wrapper).
const { chromium } = require(process.env.PW_PATH || 'playwright');

const url = process.argv[2] || 'http://127.0.0.1:8611/index.html?campus';
const mode = process.argv[3] || 'campus';

(async () => {
	const browser = await chromium.launch({ channel: 'chrome' });
	const page = await browser.newPage({ deviceScaleFactor: 1.5 });
	const lines = [];
	const errors = [];
	page.on('console', (m) => {
		const t = m.text();
		lines.push(t);
		if (/SCRIPT ERROR|Parse Error|^ERROR|USER ERROR/.test(t)) errors.push(t);
	});
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	await page.goto(url);
	const deadline = Date.now() + 60000;
	while (Date.now() < deadline && !lines.some((l) => l.includes('bugs-and-lizards: boot ok'))) {
		await page.waitForTimeout(250);
	}
	const booted = lines.some((l) => l.includes('bugs-and-lizards: boot ok'));
	let ok = booted;
	if (mode === 'campus' && booted) {
		// The campus check prints its readout to the console every few seconds when BL_LOG is set in the URL.
		const d2 = Date.now() + 15000;
		while (Date.now() < d2 && !lines.some((l) => /campus: ws=open rtt=\d+/.test(l))) {
			await page.waitForTimeout(250);
		}
		const hit = lines.find((l) => /campus: ws=open rtt=\d+/.test(l));
		console.log('campus line:', hit || '(none)');
		ok = ok && !!hit;
	}
	await browser.close();
	console.log('booted:', booted, ' errors:', errors.length);
	errors.forEach((e) => console.log('  ', e));
	ok = ok && errors.length === 0;
	console.log(ok ? 'web_check: PASS' : 'web_check: FAIL');
	process.exit(ok ? 0 : 1);
})();
