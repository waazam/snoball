# Minimal static file server for the exported HTML5/WebAssembly build, bound
# to all network interfaces so devices on the same LAN/Wi-Fi can load it.
# Uses a raw TcpListener (not HttpListener) because HttpListener requires an
# administrator-elevated URL ACL to bind anything other than localhost.
# Single-threaded: requests are handled one at a time, which is plenty for a
# handful of players loading a small game build on a local network.
param(
    [int]$Port = 8060,
    [string]$Root = (Join-Path $PSScriptRoot "..\build\web")
)

$Root = (Resolve-Path $Root).Path.TrimEnd('\')

$mimeMap = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".js"   = "application/javascript"
    ".mjs"  = "application/javascript"
    ".wasm" = "application/wasm"
    ".pck"  = "application/octet-stream"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
}

function Handle-Client {
    param($client)
    try {
        $client.NoDelay = $true
        $stream = $client.GetStream()
        $buffer = New-Object byte[] 8192
        $read = $stream.Read($buffer, 0, $buffer.Length)
        if ($read -le 0) { return }
        $requestText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
        $firstLine = ($requestText -split "`r`n")[0]
        $parts = $firstLine -split ' '
        $reqPath = if ($parts.Length -ge 2) { $parts[1] } else { "/" }
        $reqPath = [System.Uri]::UnescapeDataString($reqPath.Split('?')[0])
        if ($reqPath -eq "/") { $reqPath = "/index.html" }

        $filePath = [System.IO.Path]::GetFullPath((Join-Path $Root ($reqPath.TrimStart('/'))))

        if ($filePath.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $filePath -PathType Leaf)) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = if ($mimeMap.ContainsKey($ext)) { $mimeMap[$ext] } else { "application/octet-stream" }
            $header = "HTTP/1.1 200 OK`r`n" +
                      "Content-Type: $mime`r`n" +
                      "Content-Length: $($bytes.Length)`r`n" +
                      "Cross-Origin-Opener-Policy: same-origin`r`n" +
                      "Cross-Origin-Embedder-Policy: require-corp`r`n" +
                      "Access-Control-Allow-Origin: *`r`n" +
                      "Cache-Control: no-cache`r`n" +
                      "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($bytes, 0, $bytes.Length)
        } else {
            $body = [System.Text.Encoding]::ASCII.GetBytes("404 Not Found")
            $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($body, 0, $body.Length)
        }
        $stream.Flush()
    } catch {
        Write-Host "Request error: $($_.Exception.Message)"
    } finally {
        $client.Close()
    }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Start()
Write-Host "Serving '$Root' on port $Port (all interfaces). Ctrl+C to stop."

while ($true) {
    $client = $listener.AcceptTcpClient()
    Handle-Client $client
}
