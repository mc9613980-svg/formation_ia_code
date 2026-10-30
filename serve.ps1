$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 8765)
$listener.Start()
Write-Output "serving $root on http://localhost:8765/"
while ($true) {
  try {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
    $requestLine = $reader.ReadLine()
    while ($true) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrEmpty($line)) { break }
    }
    $parts = $requestLine -split ' '
    $path = if ($parts.Length -ge 2) { $parts[1] } else { '/' }
    $path = $path.Split('?')[0].TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($path)) { $path = 'index.html' }
    $file = Join-Path $root $path
    $status = '200 OK'
    $type = 'application/octet-stream'
    $bytes = [byte[]]@()
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      switch ($ext) {
        '.html' { $type = 'text/html; charset=utf-8' }
        '.css'  { $type = 'text/css; charset=utf-8' }
        '.js'   { $type = 'application/javascript; charset=utf-8' }
        '.svg'  { $type = 'image/svg+xml' }
      }
      $bytes = [System.IO.File]::ReadAllBytes($file)
    } else {
      $status = '404 Not Found'
      $bytes = [System.Text.Encoding]::UTF8.GetBytes('not found')
      $type = 'text/plain; charset=utf-8'
    }
    $head = "HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
    $client.Close()
  } catch {
    try { $client.Close() } catch {}
  }
}
