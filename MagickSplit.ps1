# 1. アセンブリロード
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# 2. 変数初期化
$script:dragging = $false
$script:mouseOffset = New-Object Drawing.Point(0,0)

# --- 設定 ---
$ImageMagick = "magick.exe"
$script:ImageExtensions = '.jpg','.jpeg','.png','.bmp','.gif','.tif','.tiff','.webp'
$script:splitDirection = "Vertical"
$script:offset = 0

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

$pnlTitle.Add_MouseDown({
    if ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
        $script:dragging = $true
        $script:mouseOffset = $_.Location
    }
})
$pnlTitle.Add_MouseMove({
    if ($script:dragging) {
        $currentPos = [Windows.Forms.Control]::MousePosition
        $form.Location = New-Object Drawing.Point(($currentPos.X - $script:mouseOffset.X), ($currentPos.Y - $script:mouseOffset.Y))
    }
})
$pnlTitle.Add_MouseUp({ $script:dragging = $false })

# 分割方向切替
$btnDirection = New-Object Windows.Forms.Button
$btnDirection.Text = "縦分割" ; $btnDirection.Size = New-Object Drawing.Size(64, 32) ; $btnDirection.Dock = "Right"
$btnDirection.FlatStyle = "Flat" ; $btnDirection.FlatAppearance.BorderSize = 0 ; $btnDirection.TabStop = $false
$btnDirection.Add_Click({
    if ($script:splitDirection -eq "Vertical") { $script:splitDirection = "Horizontal"; $btnDirection.Text = "横分割" }
    else { $script:splitDirection = "Vertical"; $btnDirection.Text = "縦分割" }
})

# オフセット入力 (日本語化 & 拡張操作)
$lblOffset = New-Object Windows.Forms.Label
$lblOffset.Text = "中心から:" ; $lblOffset.Location = New-Object Drawing.Point(265, 8) ; $lblOffset.AutoSize = $true
$lblOffset.Font = New-Object Drawing.Font("MS Gothic", 9)

$txtOffset = New-Object Windows.Forms.TextBox
$txtOffset.Text = "0" ; $txtOffset.Size = New-Object Drawing.Size(35, 20) ; $txtOffset.Location = New-Object Drawing.Point(325, 6)
$txtOffset.BackColor = [Drawing.Color]::FromArgb(60, 60, 60) ; $txtOffset.ForeColor = [Drawing.Color]::White
$txtOffset.BorderStyle = "FixedSingle" ; $txtOffset.TextAlign = "Center"
$txtOffset.Add_TextChanged({ if ($this.Text -match "^-?\d+$") { $script:offset = [int]$this.Text } })

# 拡張操作機能 (ホイール・矢印キー)
$txtOffset.Add_Enter({ $this.SelectAll() })
$txtOffset.Add_MouseWheel({
    [int]$v = 0 ; if ([int]::TryParse($this.Text, [ref]$v)) {
        if ($_.Delta -gt 0) { $this.Text = ($v + 1).ToString() } else { $this.Text = ($v - 1).ToString() }
    }
})
$txtOffset.Add_KeyDown({
    [int]$v = 0 ; if ([int]::TryParse($this.Text, [ref]$v)) {
        if ($_.KeyCode -eq "Up") { $this.Text = ($v + 1).ToString(); $_.Handled = $true }
        elseif ($_.KeyCode -eq "Down") { $this.Text = ($v - 1).ToString(); $_.Handled = $true }
    }
})

# 上下ボタン (MS Gothicで文字化け防止)
$btnUp = New-Object Windows.Forms.Button
$btnUp.Text = "▲" ; $btnUp.Size = New-Object Drawing.Size(18, 12) ; $btnUp.Location = New-Object Drawing.Point(362, 4)
$btnUp.FlatStyle = "Flat" ; $btnUp.FlatAppearance.BorderSize = 0 ; $btnUp.Font = New-Object Drawing.Font("MS Gothic", 5)
$btnUp.BackColor = [Drawing.Color]::FromArgb(60, 60, 60) ; $btnUp.TabStop = $false ; $btnUp.Tag = $txtOffset
$btnUp.Add_Click({ [int]$v = 0 ; if ([int]::TryParse($this.Tag.Text, [ref]$v)) { $this.Tag.Text = ($v + 1).ToString() } })

$btnDown = New-Object Windows.Forms.Button
$btnDown.Text = "▼" ; $btnDown.Size = New-Object Drawing.Size(18, 12) ; $btnDown.Location = New-Object Drawing.Point(362, 16)
$btnDown.FlatStyle = "Flat" ; $btnDown.FlatAppearance.BorderSize = 0 ; $btnDown.Font = New-Object Drawing.Font("MS Gothic", 5)
$btnDown.BackColor = [Drawing.Color]::FromArgb(60, 60, 60) ; $btnDown.TabStop = $false ; $btnDown.Tag = $txtOffset
$btnDown.Add_Click({ [int]$v = 0 ; if ([int]::TryParse($this.Tag.Text, [ref]$v)) { $this.Tag.Text = ($v - 1).ToString() } })

# ピンボタン (Segoe UI Emojiで文字化け防止)
$btnPin = New-Object Windows.Forms.Button
$btnPin.Text = "📌" ; $btnPin.Size = New-Object Drawing.Size(32, 32) ; $btnPin.Dock = "Right"
$btnPin.FlatStyle = "Flat" ; $btnPin.FlatAppearance.BorderSize = 0 ; $btnPin.TabStop = $false
$btnPin.Font = New-Object Drawing.Font("Segoe UI Emoji", 10)
$btnPin.ForeColor = [Drawing.Color]::FromArgb(120, 255, 255, 255)
$btnPin.Add_Click({
    $form.TopMost = -not $form.TopMost
    if ($form.TopMost) { $btnPin.Text = "📍"; $btnPin.ForeColor = [Drawing.Color]::White }
    else { $btnPin.Text = "📌"; $btnPin.ForeColor = [Drawing.Color]::FromArgb(120, 255, 255, 255) }
})

# 閉じるボタン
$btnClose = New-Object Windows.Forms.Button
$btnClose.Text = "✕" ; $btnClose.Size = New-Object Drawing.Size(32, 32) ; $btnClose.Dock = "Right"
$btnClose.FlatStyle = "Flat" ; $btnClose.FlatAppearance.BorderSize = 0 ; $btnClose.TabStop = $false
$btnClose.Font = New-Object Drawing.Font("MS Gothic", 10)
$btnClose.Add_Click({ $form.Close() })

$pnlTitle.Controls.AddRange(@($lblOffset, $txtOffset, $btnUp, $btnDown, $btnDirection, $btnPin, $btnClose))

$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = "画像分割ツール (0/0)" ; $lblTitle.Location = New-Object Drawing.Point(10, 8) ; $lblTitle.AutoSize = $true
$lblTitle.Font = New-Object Drawing.Font("MS Gothic", 9, [Drawing.FontStyle]::Bold)
$pnlTitle.Controls.Add($lblTitle)

# --- ログエリア ---
$logBox = New-Object Windows.Forms.TextBox
$logBox.Multiline = $true ; $logBox.ReadOnly = $true ; $logBox.BackColor = [Drawing.Color]::FromArgb(17, 17, 17)
$logBox.ForeColor = [Drawing.Color]::White ; $logBox.Dock = "Fill" ; $logBox.BorderStyle = "None"
$logBox.ScrollBars = "Vertical" ; $logBox.Font = New-Object Drawing.Font("Consolas", 9)
$logBox.TabStop = $false

$container = New-Object Windows.Forms.Panel
$container.Dock = "Fill" ; $container.Padding = New-Object Windows.Forms.Padding(10) ; $container.Controls.Add($logBox)
$form.Controls.AddRange(@($container, $pnlTitle))

# --- ロジック関数群 ---
function Add-Log([string]$Message) {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $logBox.AppendText("$timestamp  $Message`r`n")
    $logBox.ScrollToCaret()
}

function Get-ValidImageFilesFromDrop {
    param([string[]]$Paths)
    $valid = @()
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p -PathType Container) {
            $valid += Get-ChildItem -LiteralPath $p -File | Where-Object { $script:ImageExtensions -contains $_.Extension.ToLower() }
        } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($p).ToLower()
            if ($script:ImageExtensions -contains $ext) { $valid += Get-Item -LiteralPath $p }
        }
    }
    return $valid
}

function Split-Images {
    param([System.IO.FileInfo[]]$Images, [int]$Total)
    $current = 0
    foreach ($f in $Images) {
        $File = $f.FullName
        $identify = & $ImageMagick identify -format "%w %h" -- $File 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $identify) { continue }
        $parts = $identify -split '\s+'
        [int]$w = $parts[0] ; [int]$h = $parts[1]
        $dir = $f.DirectoryName ; $base = $f.BaseName ; $ext = $f.Extension
        
        if ($script:splitDirection -eq "Vertical") {
            Add-Log "縦分割(左右) 中心から:$script:offset : $($f.Name)"
            $mid = [int]($w / 2)
            $leftWidth = $mid - $script:offset
            $rightStart = $mid + $script:offset
            $rightWidth = $w - $rightStart
            & $ImageMagick $File -crop "${leftWidth}x${h}+0+0" (Join-Path $dir "${base}_1${ext}")
            & $ImageMagick $File -crop "${rightWidth}x${h}+${rightStart}+0" (Join-Path $dir "${base}_0${ext}")
        } else {
            Add-Log "横分割(上下) 中心から:$script:offset : $($f.Name)"
            $mid = [int]($h / 2)
            $topHeight = $mid - $script:offset
            $bottomStart = $mid + $script:offset
            $bottomHeight = $h - $bottomStart
            & $ImageMagick $File -crop "${w}x${topHeight}+0+0" (Join-Path $dir "${base}_0${ext}")
            & $ImageMagick $File -crop "${w}x${bottomHeight}+0+${bottomStart}" (Join-Path $dir "${base}_1${ext}")
        }
        $processedDir = Join-Path $dir "Processed"
        if (-not (Test-Path -LiteralPath $processedDir)) { New-Item -ItemType Directory -Path $processedDir | Out-Null }
        Move-Item -LiteralPath $File -Destination $processedDir -Force
        $current++ ; $lblTitle.Text = "画像分割ツール ($current/$Total)" ; $lblTitle.Refresh()
    }
}

$form.Add_DragEnter({ if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = "Copy" } })
$form.Add_DragDrop({
    $paths = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
    $validImages = Get-ValidImageFilesFromDrop -Paths $paths
    $total = $validImages.Count
    if ($total -gt 0) { Split-Images -Images $validImages -Total $total ; Add-Log "=== 完了 ===" }
})

[Windows.Forms.Application]::Run($form)