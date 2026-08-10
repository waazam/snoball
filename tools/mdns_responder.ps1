# Minimal mDNS (Bonjour/zeroconf) responder that answers "A" queries for
# <HostName>.local with this machine's LAN IP, so other devices on the same
# Wi-Fi can reach the game by name instead of typing an IP address. Works
# out of the box on Windows, macOS and iOS (built-in mDNS resolution);
# Android's browsers generally do NOT resolve .local names, so give Android
# users the plain IP link as a fallback.
param(
    [string]$HostName = "sno-ball-siege",
    [string]$IPAddress = "192.168.1.93",
    [switch]$DebugLog
)

$fqdn = "$HostName.local"
$mcastGroup = [System.Net.IPAddress]::Parse("224.0.0.251")
$mcastEndpoint = New-Object System.Net.IPEndPoint($mcastGroup, 5353)
$targetIpBytes = [System.Net.IPAddress]::Parse($IPAddress).GetAddressBytes()

function Encode-DnsName([string]$name) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($label in $name.Split('.')) {
        $labelBytes = [System.Text.Encoding]::ASCII.GetBytes($label)
        $bytes.Add([byte]$labelBytes.Length)
        $bytes.AddRange($labelBytes)
    }
    $bytes.Add([byte]0)
    # Comma-prefix to stop PowerShell from unrolling the array into loose
    # objects as it crosses the function's output pipeline (a classic
    # gotcha - without it $nameBytes below becomes an Object[], not byte[]).
    return ,($bytes.ToArray())
}

function Read-DnsName([byte[]]$data, [ref]$offset) {
    $labels = @()
    while ($true) {
        $len = $data[$offset.Value]
        $offset.Value++
        if ($len -eq 0) { break }
        if (($len -band 0xC0) -eq 0xC0) {
            # compression pointer - skip 1 more byte, stop (not needed for questions we care about)
            $offset.Value++
            break
        }
        $label = [System.Text.Encoding]::ASCII.GetString($data, $offset.Value, $len)
        $labels += $label
        $offset.Value += $len
    }
    return ($labels -join '.')
}

$socket = New-Object System.Net.Sockets.Socket(
    [System.Net.Sockets.AddressFamily]::InterNetwork,
    [System.Net.Sockets.SocketType]::Dgram,
    [System.Net.Sockets.ProtocolType]::Udp)
$socket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$socket.Bind((New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 5353)))
$socket.SetSocketOption(
    [System.Net.Sockets.SocketOptionLevel]::IP,
    [System.Net.Sockets.SocketOptionName]::AddMembership,
    (New-Object System.Net.Sockets.MulticastOption($mcastGroup, [System.Net.IPAddress]::Parse($IPAddress))))

Write-Host "mDNS responder answering for $fqdn -> $IPAddress"

$buffer = New-Object byte[] 2048
while ($true) {
    $remoteEp = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
    $remoteEpRef = [System.Net.EndPoint]$remoteEp
    try {
        $len = $socket.ReceiveFrom($buffer, [ref]$remoteEpRef)
    } catch {
        continue
    }
    if ($DebugLog) { Write-Host "recv $len bytes from $remoteEpRef" }
    if ($len -lt 12) { continue }

    $data = $buffer[0..($len - 1)]
    $flags = ([int]$data[2] -shl 8) -bor [int]$data[3]
    $isQuery = (($flags -band 0x8000) -eq 0)
    $qdcount = ([int]$data[4] -shl 8) -bor [int]$data[5]
    if ($DebugLog) { Write-Host "  isQuery=$isQuery qdcount=$qdcount flags=0x$('{0:X4}' -f $flags)" }
    if (-not $isQuery -or $qdcount -lt 1) { continue }

    $offset = 12
    $offsetRef = [ref]$offset
    $matched = $false
    for ($q = 0; $q -lt $qdcount; $q++) {
        if ($offsetRef.Value -ge $data.Length) { break }
        $qname = Read-DnsName $data $offsetRef
        if ($offsetRef.Value + 4 -gt $data.Length) { break }
        $qtype = ([int]$data[$offsetRef.Value] -shl 8) -bor [int]$data[$offsetRef.Value + 1]
        $offsetRef.Value += 4  # QTYPE(2) + QCLASS(2)
        if ($DebugLog) { Write-Host "  q$q qname='$qname' qtype=$qtype" }
        if ($qname.ToLower() -eq $fqdn.ToLower() -and ($qtype -eq 1 -or $qtype -eq 255)) {
            $matched = $true
        }
    }
    if (-not $matched) { continue }
    if ($DebugLog) { Write-Host "  MATCH -> replying" }

    # Build a minimal mDNS response: same transaction id, QR+AA set, 1 answer.
    $nameBytes = Encode-DnsName $fqdn
    $resp = New-Object System.Collections.Generic.List[byte]
    $resp.Add($data[0]); $resp.Add($data[1])          # transaction ID (mirrored)
    $resp.Add(0x84); $resp.Add(0x00)                  # flags: response, authoritative
    $resp.Add(0x00); $resp.Add(0x00)                  # QDCOUNT = 0
    $resp.Add(0x00); $resp.Add(0x01)                  # ANCOUNT = 1
    $resp.Add(0x00); $resp.Add(0x00)                  # NSCOUNT = 0
    $resp.Add(0x00); $resp.Add(0x00)                  # ARCOUNT = 0
    $resp.AddRange($nameBytes)
    $resp.Add(0x00); $resp.Add(0x01)                  # TYPE = A
    $resp.Add(0x80); $resp.Add(0x01)                  # CLASS = IN with cache-flush bit
    $resp.Add(0x00); $resp.Add(0x00); $resp.Add(0x00); $resp.Add(0x78)  # TTL = 120s
    $resp.Add(0x00); $resp.Add(0x04)                  # RDLENGTH = 4
    $resp.AddRange($targetIpBytes)

    $respBytes = $resp.ToArray()
    [void]$socket.SendTo($respBytes, $mcastEndpoint)
}
