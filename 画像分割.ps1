Add-Type -AssemblyName PresentationFramework

#---------------- XAML ----------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="画像分割ツール"
        Height="320" Width="520"
        Background="#222" Foreground="White"
        WindowStyle="None" ResizeMode="CanResize"
        AllowsTransparency="False"
        AllowDrop="True">
    <Border BorderBrush="#444" BorderThickness="1" CornerRadius="4" Background="#222">
        <Grid Margin="0">
            <Grid.RowDefinitions>
                <RowDefinition Height="32"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <!-- カスタムタイトルバー -->
            <Grid Grid.Row="0" Background="#333" Name="TitleBar">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <TextBlock Text="画像分割ツール"
                           VerticalAlignment="Center"
                           Margin="10,0,0,0"
                           FontWeight="Bold"/>

                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,4,0">
                    <Button x:Name="PinButton"
                            Width="22" Height="22"
                            Margin="0,0,4,0"
                            ToolTip="最前面固定"
                            Background="Transparent"
                            BorderBrush="Transparent"
                            Foreground="White"
                            FontSize="14"
                            Opacity="0.5">
                        <TextBlock Text="📌" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Button>
                    <Button x:Name="CloseButton"
                            Width="22" Height="22"
                            Background="Transparent"
                            BorderBrush="Transparent"
                            Foreground="White"
                            FontSize="12"
                            ToolTip="閉じる">
                        <TextBlock Text="✕" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Button>
                </StackPanel>
            </Grid>

            <!-- 本体 -->
            <Grid Grid.Row="1" Margin="10" AllowDrop="True">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <TextBlock Text="画像ファイルやフォルダをここにドラッグ＆ドロップ"
                           FontSize="16"
                           HorizontalAlignment="Center"
                           Margin="0,4,0,8"/>

                <Border Grid.Row="1" BorderBrush="Gray" BorderThickness="1"
                        CornerRadius="6" Padding="6">
                    <TextBox Name="LogBox"
                             Background="#111" Foreground="White"
                             IsReadOnly="True"
                             TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto"
                             AllowDrop="True"/>
                </Border>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

#------------- XAML 読み込み -------------
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$LogBox    = $window.FindName("LogBox")
$PinButton = $window.FindName("PinButton")
$CloseBtn  = $window.FindName("CloseButton")
$TitleBar  = $window.FindName("TitleBar")

#------------- ログ -------------
function Write-Log {
    param([string]$Message)
    $LogBox.AppendText("$Message`n")
    $LogBox.ScrollToEnd()
}

# 対象拡張子
$script:ImageExtensions = '.jpg','.jpeg','.png','.bmp','.gif','.tif','.tiff','.webp'

function Get-ImageFilesFromDrop {
    param([string[]]$Paths)

    $result = @()

    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) {
            Write-Log "存在しないパスをスキップ: $p"
            continue
        }

        if (Test-Path $p -PathType Container) {
            # フォルダ → 中の画像（再帰）
            Write-Log "フォルダ内を検索: $p"
            $files = Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue |
                     Where-Object { $script:ImageExtensions -contains $_.Extension.ToLower() } |
                     Select-Object -ExpandProperty FullName
            $result += $files
        }
        else {
            # 単一ファイル
            $ext = [System.IO.Path]::GetExtension($p).ToLower()
            if ($script:ImageExtensions -contains $ext) {
                $result += (Resolve-Path $p).Path
            }
            else {
                Write-Log "画像拡張子ではないためスキップ: $p"
            }
        }
    }

    $result | Sort-Object -Unique
}

#------------- 画像分割 -------------
function Split-Image {
    param([string]$File)

    if (-not (Test-Path $File)) {
        Write-Log "ファイルが存在しません: $File"
        return
    }

    # identify でサイズ取得
    $identify = & magick identify -format "%w %h" -- "$File" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $identify) {
        Write-Log "identify 失敗のためスキップ: $File"
        return
    }

    $parts = $identify -split '\s+'
    if ($parts.Count -lt 2) {
        Write-Log "サイズ情報不正のためスキップ: $File"
        return
    }

    [int]$w = $parts[0]
    [int]$h = $parts[1]

    $dir  = Split-Path $File -Parent
    $base = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $ext  = [System.IO.Path]::GetExtension($File)

    Write-Log "処理中: $File"
    Write-Log "  サイズ: ${w}x${h}"

    if ($h -gt $w) {
        Write-Log "  縦長 → 上下に分割"
        $half = [int]($h / 2)

        $topOut    = Join-Path $dir "${base}_top${ext}"
        $bottomOut = Join-Path $dir "${base}_bottom${ext}"

        & magick "$File" -crop "100%x50%+0+0"          "$topOut"    2>$null
        & magick "$File" -crop "100%x50%+0+${half}"   "$bottomOut" 2>$null
    }
    else {
        Write-Log "  横長 → 左右に分割"
        $half = [int]($w / 2)

        $leftOut  = Join-Path $dir "${base}_left${ext}"
        $rightOut = Join-Path $dir "${base}_right${ext}"

        & magick "$File" -crop "50%x100%+0+0"          "$leftOut"   2>$null
        & magick "$File" -crop "50%x100%+${half}+0"    "$rightOut"  2>$null
    }

    # Processed フォルダへ元画像を移動
    $processedDir = Join-Path $dir "Processed"
    if (-not (Test-Path $processedDir)) {
        New-Item -ItemType Directory -Path $processedDir | Out-Null
    }

    Move-Item -Path $File -Destination $processedDir -Force
    Write-Log "  → 元画像を Processed に移動"
}

#------------- ドロップ処理 -------------
# ドラッグ中の見た目（コピー可能かどうか）もここで制御
$window.Add_PreviewDragOver({
    if ($_.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $_.Effects = [System.Windows.DragDropEffects]::Copy
    } else {
        $_.Effects = [System.Windows.DragDropEffects]::None
    }
    $_.Handled = $true
})

$window.Add_PreviewDrop({
    $data = $_.Data.GetData([Windows.DataFormats]::FileDrop)
    if (-not $data) { return }

    $paths = @($data)
    Write-Log "ドロップ検出: $($paths.Count) 件"

    $files = Get-ImageFilesFromDrop -Paths $paths
    if (-not $files -or $files.Count -eq 0) {
        Write-Log "処理対象となる画像がありません。"
        return
    }

    foreach ($f in $files) {
        Split-Image -File $f
    }

    Write-Log "=== 処理完了 ==="

    $_.Handled = $true
})

#------------- タイトルバー動作 -------------
# ウィンドウドラッグ
$TitleBar.Add_MouseLeftButtonDown({
    if ($_.ClickCount -eq 1) {
        $window.DragMove()
    }
})

# 最前面固定トグル
$PinButton.Add_Click({
    $window.Topmost = -not $window.Topmost
    if ($window.Topmost) {
        $PinButton.Opacity = 1.0
    }
    else {
        $PinButton.Opacity = 0.5
    }
})

# 閉じる
$CloseBtn.Add_Click({
    $window.Close()
})

#------------- 起動 -------------
$window.ShowDialog() | Out-Null
