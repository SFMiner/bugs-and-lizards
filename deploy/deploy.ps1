# Bugs & Lizards deploy (PowerShell 7, from the desktop). Touches only this project's own folder, user and unit:
#   /srv/bugs-and-lizards (www/, logs/, godot), user bugsliz, /etc/systemd/system/bugs-and-lizards.service.
# It never touches nginx: the nginx snippet + include line is a shared-layer change done separately, after
# MainCircleAgent agrees (see deploy/nginx-location.conf).
# Needs the root key loaded in the Windows ssh-agent (supervised window: plain `ssh-add`; the agent refuses -t; end with `ssh-add -D`).
#   pwsh deploy/deploy.ps1 -Setup     first time: user, folders, Linux Godot binary, unit
#   pwsh deploy/deploy.ps1            export the web build, upload it, restart the server
param(
	[switch]$Setup,
	[switch]$NoExport
)
$ErrorActionPreference = "Stop"
$Vps = "root@209.46.126.230"
$Root = Split-Path -Parent $PSScriptRoot
$Game = Join-Path $Root "game"
$Godot = "C:\Users\seanm\Nextcloud2\Gamedev\Godot_v4.7.2-stable_win64_console.exe"
$GodotUrl = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"

if ($Setup) {
	$setupScript = @'
set -eu
id bugsliz >/dev/null 2>&1 || useradd --system --home-dir /srv/bugs-and-lizards --shell /usr/sbin/nologin bugsliz
mkdir -p /srv/bugs-and-lizards/www /srv/bugs-and-lizards/logs /srv/bugs-and-lizards/.local
if [ ! -x /srv/bugs-and-lizards/godot ]; then
	curl -sSL -o /tmp/bl-godot.zip "GODOT_URL"
	python3 -c "import zipfile,sys; z=zipfile.ZipFile('/tmp/bl-godot.zip'); n=[x for x in z.namelist() if x.endswith('linux.x86_64')][0]; open('/srv/bugs-and-lizards/godot','wb').write(z.read(n))"
	chmod 755 /srv/bugs-and-lizards/godot
	rm -f /tmp/bl-godot.zip
fi
chown -R bugsliz:bugsliz /srv/bugs-and-lizards/logs /srv/bugs-and-lizards/.local
chown root:root /srv/bugs-and-lizards /srv/bugs-and-lizards/www /srv/bugs-and-lizards/godot
'@.Replace("GODOT_URL", $GodotUrl)
	$setupScript | ssh $Vps "bash -s"
	scp (Join-Path $PSScriptRoot "bugs-and-lizards.service") "${Vps}:/etc/systemd/system/bugs-and-lizards.service"
	ssh $Vps "systemctl daemon-reload && systemctl enable bugs-and-lizards.service"
}

if (-not $NoExport) {
	$out = Join-Path $Game "build\web"
	New-Item -ItemType Directory -Force $out | Out-Null
	& $Godot --headless --path $Game --export-release "Web" (Join-Path $out "index.html")
	if ($LASTEXITCODE -ne 0) { throw "export failed" }
}

$web = Join-Path $Game "build\web"
ssh $Vps "rm -rf /srv/bugs-and-lizards/www.new && mkdir -p /srv/bugs-and-lizards/www.new"
$files = Get-ChildItem $web -File | Where-Object Name -ne "keytest.html" | ForEach-Object FullName # keytest.html is a local debug page
scp -q @files "${Vps}:/srv/bugs-and-lizards/www.new/"
# Pre-compressed .gz beside each file, so nginx gzip_static sends them as they are and need not gzip 40 MB per student.
ssh $Vps "cd /srv/bugs-and-lizards && gzip -k -9 -f www.new/*.wasm www.new/*.pck www.new/*.js www.new/*.html && chmod -R a+rX www.new && rm -rf www.old && mv www www.old && mv www.new www && systemctl restart bugs-and-lizards.service && sleep 2 && systemctl is-active bugs-and-lizards.service && journalctl -u bugs-and-lizards.service -n 5 --no-pager"
$line = ssh $Vps "journalctl -u bugs-and-lizards.service -n 20 --no-pager -o cat | grep 'server: listening' | tail -1"
if ($line -notmatch "catch log off, teacher key required") { throw "server did not start with the teacher key: $line" }
Write-Host "deployed"
