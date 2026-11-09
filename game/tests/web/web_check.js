// Browser smoke test (installed Chrome, headless, throwaway profile). Fails on any console SCRIPT ERROR / ERROR.
// Usage: node web_check.js <page-url> [mode] [ws-url]
//   mode campus: the campus check shows an open WebSocket with a round-trip time.
//   mode play (default): this script plays teacher over a raw WebSocket; the browser tab joins with the on-screen
//   pad, hunts one Stage 2 round as the only lizard, and must show the hunt start and the round summary.
// Needs PW_PATH = <game-sim-server>\node_modules\playwright, a server on ws-url, and the export served at page-url.
const { chromium } = require(process.env.PW_PATH || 'playwright');

const url = process.argv[2] || 'http://127.0.0.1:8611/index.html';
const mode = process.argv[3] || 'play';
const wsUrl = process.argv[4] || 'ws://127.0.0.1:3311';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function teacher() {
	const ws = new WebSocket(wsUrl);
	const inbox = [];
	ws.onmessage = (e) => inbox.push(JSON.parse(e.data));
	const opened = new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });
	const send = (t, f = {}) => ws.send(JSON.stringify({ t, ...f }));
	async function waitFor(t, ms = 10000) {
		const end = Date.now() + ms;
		while (Date.now() < end) {
			const i = inbox.findIndex((m) => m.t === t);
			if (i >= 0) return inbox.splice(i, 1)[0];
			await sleep(50);
		}
		throw new Error('teacher: no ' + t);
	}
	return { ws, opened, send, waitFor };
}

(async () => {
	const browser = await chromium.launch({ channel: 'chrome' });
	const page = await browser.newPage({ viewport: { width: 1180, height: 640 } });
	const lines = [];
	const errors = [];
	page.on('console', (m) => {
		const t = m.text();
		lines.push(t);
		if (/SCRIPT ERROR|Parse Error|^ERROR|USER ERROR/.test(t)) errors.push(t);
	});
	page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
	const waitLine = async (re, ms) => {
		const end = Date.now() + ms;
		while (Date.now() < end) {
			const hit = lines.find((l) => re.test(l));
			if (hit) return hit;
			await sleep(200);
		}
		return null;
	};
	const checks = [];
	const check = (name, ok, detail = '') => { checks.push(ok); console.log((ok ? 'ok   ' : 'FAIL ') + name + (detail ? '  ' + detail : '')); };
	try {
		if (mode === 'campus') {
			await page.goto(url + (url.includes('?') ? '&' : '?') + 'campus');
			check('boot line', !!(await waitLine(/bugs-and-lizards: boot ok/, 60000)));
			check('campus websocket open with rtt', !!(await waitLine(/campus: ws=open rtt=\d+/, 20000)));
		} else {
			const t = teacher();
			await t.opened;
			t.send('create_session', { names: ['Web1', 'Web2'] });
			const sc = await t.waitFor('session_created');
			const tok = { token: sc.token };
			t.send('configure', { ...tok, config: { stage: 2, rooms: 1, bugs_start: 75, lizards_start: 1, hunt_seconds: 15, bug_budget: 600 }, assign: {} });
			await page.goto(url);
			check('boot line', !!(await waitLine(/bugs-and-lizards: boot ok/, 60000)));
			await sleep(1500);
			await page.mouse.click(590, 30); // focus the canvas
			await page.keyboard.type(sc.code, { delay: 50 }); // physical digit keys on the join pad
			await sleep(500);
			await page.mouse.click(585, 544); // Join
			await sleep(1500);
			await page.mouse.click(148, 155); // first name on the roster: Web1
			check('joined', !!(await waitLine(/client: joined room 0/, 10000)));
			t.send('set_lizards', { ...tok, room: 0, lizards: ['Web1'] });
			await sleep(300);
			t.send('start_hunt', tok);
			check('hunt start reached the hunter', !!(await waitLine(/client: hunt_start round 1 bugs 75/, 10000)));
			await page.keyboard.down('KeyW'); await sleep(800); await page.keyboard.up('KeyW');
			await page.keyboard.press('Space');
			await sleep(500);
			t.send('stop_hunt', tok);
			const sum = await waitLine(/client: summary round 1 /, 10000);
			check('summary shown', !!sum, sum || '');
			check('summary numbers (0 caught: BUGS 75, next 225, LIZARDS 0)', !!sum && /BUGS 75 next 225 LIZARDS 0/.test(sum));
			t.ws.close();
		}
	} catch (e) {
		check('no exception', false, e.message);
	}
	await browser.close();
	check('no console errors', errors.length === 0, errors.slice(0, 5).join(' | '));
	const ok = checks.every(Boolean);
	console.log(ok ? `web_check: PASS ${checks.length}/${checks.length}` : 'web_check: FAIL');
	process.exit(ok ? 0 : 1);
})();
