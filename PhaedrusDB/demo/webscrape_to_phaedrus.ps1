param(
  [string]$BaseUrl = "http://localhost:4007",
  [string]$ApiKey  = "change-me-please"
)

$BaseUrl = $BaseUrl.TrimEnd('/')

# URLs to scrape (edit as needed)
$urls = @(
  "https://lobstermax.org/",
  "https://lobstermax.org/promptmaxing.html",
  "https://lobstermax.org/safetymaxing.html"
)

function Sha256Hex([string]$s) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
  } finally {
    $sha.Dispose()
  }
}

function Get-PageSummary([string]$u) {
  $started = (Get-Date).ToUniversalTime().ToString("o")

  $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 25
  $html = $resp.Content

  $title = ""
  if ($html -match "(?is)<title>(.*?)</title>") {
    $title = ($matches[1] -replace "\s+"," ").Trim()
  }

  # crude text extract: strip scripts/styles, strip tags, collapse whitespace
  $text = ($html -replace "(?is)<script.*?</script>"," " -replace "(?is)<style.*?</style>"," ")
  $text = ($text -replace "(?is)<[^>]+>"," " -replace "\s+"," ").Trim()

  $excerpt = $text
  if ($excerpt.Length -gt 280) { $excerpt = $excerpt.Substring(0,280) }

  # Stable entry payload: do NOT include volatile timestamps
  $payload = @{
    kind = "webpage"
    url = $u
    title = $title
    excerpt = $excerpt
    content_sha256 = (Sha256Hex $html)
  }

  # Volatile scrape metadata belongs on the observation
  $etag = $null
  $lastmod = $null
  try {
    if ($resp.Headers["ETag"]) { $etag = ("" + $resp.Headers["ETag"]) }
    if ($resp.Headers["Last-Modified"]) { $lastmod = ("" + $resp.Headers["Last-Modified"]) }
  } catch {}

  $meta = @{
    fetched_at = $started
    status_code = $resp.StatusCode
    etag = $etag
    last_modified = $lastmod
    user_agent = "Invoke-WebRequest"
  }

  return @{
    payload = $payload
    sign = $true
    source = "demo-scraper"
    url = $u
    tags = @("demo","scrape")
    meta = $meta
  }
}

$lines = New-Object System.Collections.Generic.List[string]
foreach ($u in $urls) {
  try {
    $obj = Get-PageSummary $u
    $lines.Add(($obj | ConvertTo-Json -Depth 10 -Compress))
    Write-Host "Scraped: $u"
  } catch {
    Write-Host "Failed: $u ($($_.Exception.Message))"
  }
}

$ndjson = ($lines -join "`n") + "`n"

curl.exe -sS -X POST "$BaseUrl/observe/ndjson?mode=ndjson" `
  -H "Content-Type: application/x-ndjson" `
  -H "x-phaedrus-key: $ApiKey" `
  --data-binary $ndjson
