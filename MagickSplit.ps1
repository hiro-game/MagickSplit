# 1. アセンブリロード
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
# 2. ドラッグ移動用の変数初期化（APIを使わないためコンパイルなしで高速）
$script:dragging = $false
$script:mouseOffset = New-Object Drawing.Point(0,0)

# --- 設定 ---
$script:ImageExtensions = '.jpg','.jpeg','.png','.bmp','.gif','.tif','.tiff','.webp'

# --- フォーム構築 ---
$form = New-Object Windows.Forms.Form
$form.Text = "画像分割ツール"
$form.Size = New-Object Drawing.Size(520, 320)
$form.StartPosition = "CenterScreen"
$form.BackColor = [Drawing.Color]::FromArgb(34, 34, 34)
$form.ForeColor = [Drawing.Color]::White
$form.FormBorderStyle = "None"
$form.AllowDrop = $true

# --- タイトルバー ---
$pnlTitle = New-Object Windows.Forms.Panel
$pnlTitle.Height = 32 ; $pnlTitle.Dock = "Top" ; $pnlTitle.BackColor = [Drawing.Color]::FromArgb(51, 51, 51)

# ドラッグ移動ロジック（APIを使わずPowerShellのみで完結：最速）
$pnlTitle.Add_MouseDown({
    if ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:mouseOffset = $_.Location # クリックした位置を保持
    }
})
$pnlTitle.Add_MouseMove({
    if ($script:dragging) {
        $currentPos = [Windows.Forms.Control]::MousePosition
        $form.Location = New-Object Drawing.Point(($currentPos.X - $script:mouseOffset.X), ($currentPos.Y - $script:mouseOffset.Y))
    }
})
$pnlTitle.Add_MouseUp({ $script:dragging = $false })

# 1. 📌 ピンボタンを「先に」作成
$btnPin = New-Object Windows.Forms.Button
$btnPin.Text = "📌" 
$btnPin.Size = New-Object Drawing.Size(32, 32) 
$btnPin.Dock = "Right"
$btnPin.FlatStyle = "Flat" 
$btnPin.FlatAppearance.BorderSize = 0
$btnPin.Font = New-Object Drawing.Font("Segoe UI Emoji", 10)
$btnPin.ForeColor = [Drawing.Color]::FromArgb(120, 255, 255, 255)
$btnPin.Add_Click({
    $form.TopMost = -not $form.TopMost
    if ($form.TopMost) { $btnPin.Text = "📍"; $btnPin.ForeColor = [Drawing.Color]::White }
    else { $btnPin.Text = "📌"; $btnPin.ForeColor = [Drawing.Color]::FromArgb(120, 255, 255, 255) }
})

# 2. ✕ 閉じるボタンを「後から」作成（右端に来るように）
$btnClose = New-Object Windows.Forms.Button
$btnClose.Text = "✕" ; $btnClose.Size = New-Object Drawing.Size(32, 32) ; $btnClose.Dock = "Right"
$btnClose.FlatStyle = "Flat" ; $btnClose.FlatAppearance.BorderSize = 0 
$btnClose.Font = New-Object Drawing.Font("MS Gothic", 10)
$btnClose.Add_Click({ $form.Close() })

# 3. コントロールの追加
$pnlTitle.Controls.Add($btnPin)  
$pnlTitle.Controls.Add($btnClose) 

# タイトル文字
$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = "画像分割ツール" ; $lblTitle.Location = New-Object Drawing.Point(10, 8) ; $lblTitle.AutoSize = $true
$lblTitle.Font = New-Object Drawing.Font("MS Gothic", 9, [Drawing.FontStyle]::Bold) ; $lblTitle.Enabled = $false
$pnlTitle.Controls.Add($lblTitle)

# --- ログエリア ---
$logBox = New-Object Windows.Forms.TextBox
$logBox.Multiline = $true ; $logBox.ReadOnly = $true ; $logBox.BackColor = [Drawing.Color]::FromArgb(17, 17, 17)
$logBox.ForeColor = [Drawing.Color]::White ; $logBox.Dock = "Fill" ; $logBox.BorderStyle = "None"
$logBox.ScrollBars = "Vertical"

$container = New-Object Windows.Forms.Panel
$container.Dock = "Fill" ; $container.Padding = New-Object Windows.Forms.Padding(10) ; $container.Controls.Add($logBox)
$form.Controls.AddRange(@($container, $pnlTitle))

# --- ロジック ---
function Write-Log([string]$msg) {
    $logBox.AppendText("$msg`r`n")
    $logBox.ScrollToCaret()
}

function Split-Image-File([string]$File) {
    if (-not (Test-Path -LiteralPath $File)) { return }
    $identify = & magick identify -format "%w %h" -- $File 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $identify) { Write-Log "エラー: identify失敗 ($File)"; return }
    $parts = $identify -split '\s+'
    [int]$w = $parts[0] ; [int]$h = $parts[1]
    $dir = Split-Path $File -Parent ; $base = [System.IO.Path]::GetFileNameWithoutExtension($File) ; $ext = [System.IO.Path]::GetExtension($File)
    Write-Log "処理中: $base (${w}x${h})"
    if ($h -gt $w) {
        $half = [int]($h / 2)
        & magick $File -crop "100%x50%+0+0" (Join-Path $dir "${base}_top${ext}")
        & magick $File -crop "100%x50%+0+${half}" (Join-Path $dir "${base}_bottom${ext}")
    } else {
        $half = [int]($w / 2)
        & magick $File -crop "50%x100%+0+0" (Join-Path $dir "${base}_left${ext}")
        & magick $File -crop "50%x100%+${half}+0" (Join-Path $dir "${base}_right${ext}")
    }
    $processedDir = Join-Path $dir "Processed"
    if (-not (Test-Path -LiteralPath $processedDir)) { New-Item -ItemType Directory -Path $processedDir | Out-Null }
    Move-Item -LiteralPath $File -Destination $processedDir -Force
}

# --- ドロップ処理 ---
$form.Add_DragEnter({ if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = "Copy" } })
$form.Add_DragDrop({
    $paths = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p -PathType Container) {
            Get-ChildItem -LiteralPath $p -File | Where-Object { $script:ImageExtensions -contains $_.Extension.ToLower() } | ForEach-Object { Split-Image-File -File $_.FullName }
        } elseif ($script:ImageExtensions -contains [System.IO.Path]::GetExtension($p).ToLower()) {
            Split-Image-File -File $p
        }
    }
    Write-Log "=== 完了 ==="
})

[Windows.Forms.Application]::Run($form)
