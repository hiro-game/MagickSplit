# MagickSplit

当アプリは、ImageMagickのフロントエンドです。

---
## このアプリについて
本アプリは **Microsoft Copilot によって作成された Copilot 製アプリ**です。  
Windows 11 + PowerShell 7.5.4 で動作確認済みですで、5.1でも動作します。

![MagickSplit](https://github.com/user-attachments/assets/10258794-00bf-4337-952b-26ff77151d7c "アプリウィンドウ")
---
## 本アプリはPowerShell と WPFで動作します、.NET Frameworkが動作する環境であれば別途ランタイム等のインストールは必要ありません。
ImageMagickをインストールし、コマンドから使用できるようにしてください。

---
### 使用方法

- 画像ファイルか画像の含まれるフォルダをドロップすると対応形式の画像を分割します。
- 分割は画像が縦長であれば上下に、横長であれば左右に分割します。
- 対応形式以外のファイルは全て無視されます。
- 分割後の画像は元フォルダに保存され、元の画像は自動的に `Processed` フォルダへ移動されます。

---

## 特徴

- ドラッグ＆ドロップのみで操作可能
- 左右分割 / 上下分割を自動判定
- ImageMagick のmagick -crop を内部で使用
- PowerShell + WPF による軽量 GUI
- Processed フォルダへ自動整理
- MIT License で公開

---

## 動作要件

- Windows 10 / 11
- PowerShell 7.x
- ImageMagick（`magick.exe` が PATH に通っていること）
- .NET Framework / WPF が動作する環境

---

## インストール

1. リポジトリをクローンまたは ZIP ダウンロード  
2. `画像分割.ps1` を任意の場所に配置  
3. ImageMagick がインストールされていることを確認  
4. PowerShell 7 で起動

```powershell
pwsh ./画像分割.ps1
# PowerShell 5.1 の場合
powershell ./画像分割.ps1
```
```
#ショートカットで使用する場合
pwsh -WindowStyle Hidden -ExecutionPolicy Bypass -File .\画像分割.ps1
```

## ライセンス
本プロジェクトは MIT License のもとで公開されています。

## 注意事項
- ImageMagick のインストールが必須です
- 分割処理は magick -crop を使用しています

