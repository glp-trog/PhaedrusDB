param(
  [string]$BaseUrl = "http://localhost:4007",
  [string]$ApiKey  = "change-me-please",
  [string]$Subject = "lobstermax.org",
  [string]$Url     = "https://lobstermax.org/",
  [string[]]$Tags  = @("lobstermax","launch")
)

function CurlJson {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [Parameter(Mandatory=$true)][string]$Url,
    [string]$BodyJson = $null
  )

  $args = @("-sS", "-X", $Method, $Url)

  if ($ApiKey -and $ApiKey.Length -gt 0) {
    $args += @("-H", ("x-phaedrus-key: {0}" -f $ApiKey))
  }

  if ($BodyJson) {
    $args += @("-H", "Content-Type: application/json")
    $args += @("-d", $BodyJson)
  }

  $out = & curl.exe @args
  if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE) calling $Url" }

  return ($out | ConvertFrom-Json)
}

$BaseUrl = $BaseUrl.TrimEnd('/')

# 1) Create + sign entry
$claim = @{
  payload = @{
    kind = "claim"
    subject = $Subject
    claim = "Launched Lobstermax OpenClaw maxing guide"
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  sign = $true
} | ConvertTo-Json -Depth 10 -Compress

$entry = CurlJson -Method "POST" -Url ("{0}/entries" -f $BaseUrl) -BodyJson $claim
$contentId = ("" + $entry.content_id).Trim()

Write-Host ("Created entry: {0}" -f $contentId)
Write-Host ("content_id length: {0}" -f $contentId.Length)

# 2) Save receipt
$proof = CurlJson -Method "GET" -Url ("{0}/proof/{1}" -f $BaseUrl, $contentId)
$receiptPath = (".\receipt_{0}.json" -f $contentId)
($proof | ConvertTo-Json -Depth 10) | Out-File $receiptPath -Encoding utf8
Write-Host ("Saved receipt: {0}" -f $receiptPath)

# 3) Observe it
$obs = @{
  content_id = $contentId
  source = "demo-script"
  url = $Url
  tags = $Tags
  observed_at = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 10 -Compress

$obsRes = CurlJson -Method "POST" -Url ("{0}/observe" -f $BaseUrl) -BodyJson $obs
Write-Host ("Observed: {0}" -f $obsRes.id)

# 4) Stateless verify using saved receipt
$r = Get-Content $receiptPath | ConvertFrom-Json
$verify = @{
  content_id = ("" + $r.content_id).Trim()
  pubkey_b64 = $r.proof.pubkey_b64
  sig_b64    = $r.proof.sig_b64
} | ConvertTo-Json -Depth 10 -Compress

$verifyRes = CurlJson -Method "POST" -Url ("{0}/verify" -f $BaseUrl) -BodyJson $verify
Write-Host ("Detached verify: ok={0}" -f $verifyRes.ok)

# 5) Bundle
$bundleUrl = ("{0}/bundle/{1}?limit=20" -f $BaseUrl, $contentId)
Write-Host ("Bundle URL: {0}" -f $bundleUrl)

$bundle = CurlJson -Method "GET" -Url $bundleUrl
$bundle | ConvertTo-Json -Depth 10
