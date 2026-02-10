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

function CurlJson([string]$method, [string]$url, [string]$bodyJson=$null) {
  $args = @('-sS', '-X', $method, $url)
  if ($ApiKey -and $ApiKey.Length -gt 0) { $args += @('-H', "x-phaedrus-key: $ApiKey") }
  if ($bodyJson) { $args += @('-H', 'Content-Type: application/json'); $args += @('-d', $bodyJson) }
  $out = & curl.exe @args
  if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE) calling $url" }
  return ($out | ConvertFrom-Json)
}

function Get-LatestContentIdForUrl([string]$u) {
  # Best-effort: fetch recent observations and pick the newest one for this URL.
  $recentUrl = "$BaseUrl/observations/recent?source=demo-scraper&tag=scrape&limit=200"
  $recent = CurlJson 'GET' $recentUrl
  foreach ($o in $recent.observations) {
    if ($o.url -eq $u) { return ("" + $o.content_id).Trim() }
  }
  return $null
}

function Get-Entry([string]$contentId) {
  CurlJson 'GET' "$BaseUrl/entries/$contentId"
}

$lines = New-Object System.Collections.Generic.List[string]
foreach ($u in $urls) {
  try {
    $obj = Get-PageSummary $u

    # Change detection: if latest entry for this URL has the same content_sha256, only append an observation.
    $latestCid = Get-LatestContentIdForUrl $u
    if ($latestCid) {
      try {
        $entry = Get-Entry $latestCid
        $prevSha = $entry.payload.content_sha256
        $newSha = $obj.payload.content_sha256

        if ($prevSha -and $newSha -and ($prevSha -eq $newSha)) {
          $obj = @{
            content_id = $latestCid
            source = $obj.source
            url = $obj.url
            tags = $obj.tags
            meta = $obj.meta
            observed_at = $obj.meta.fetched_at
          }
        }
      } catch {
        # ignore lookup failures; fall back to payload ingest
      }
    }

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
