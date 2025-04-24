# ==========================================
# Azure Files デモ一式 – PowerShell 7 以上推奨
# ==========================================
# ================== 1) 変数定義 ==================
$RG       = "FileDemoRG"
$Location = "japaneast"

$Storage  = "filesdemo$([Guid]::NewGuid().ToString('N').Substring(0,8))"
$Share    = "config"

$VmName   = "winfilesvm"
$VmSize   = "Standard_B2ms"
$AdminUser= "azureuser"
$AdminPass= "P@ssw0rd123456!"          # 要件を満たす強力なパスワード

# ================== 2) リソース作成 ==================
az group create --name $RG --location $Location | Out-Null

az storage account create `
  --name $Storage --resource-group $RG --location $Location `
  --sku Standard_LRS --kind StorageV2 --https-only true | Out-Null

az storage share-rm create `
  --resource-group $RG --storage-account $Storage `
  --name $Share --quota 10 | Out-Null

$vm = az vm create `
  --resource-group $RG --name $VmName `
  --image MicrosoftWindowsServer:WindowsServer:2022-datacenter-smalldisk:latest `
  --size $VmSize --admin-username $AdminUser --admin-password $AdminPass `
  --public-ip-sku Standard -o json

# ================== 3) キー取得 ==================
$StorageKey = az storage account keys list `
  --resource-group $RG --account-name $Storage `
  --query '[0].value' -o tsv

# ================== 4) 貼り付け用スクリプト生成 ==================
$PasteBlock = @"
############################################
#  ★★ VM に RDP ⇒ 管理者 PowerShell で貼り付け ★★
#  (そのままコピペで OK)
############################################
`$Storage = '$Storage'
`$Share   = '$Share'
`$Key     = '$StorageKey'

# --- net use---
net use Z: "\\`$Storage.file.core.windows.net\`$Share" /user:`$Storage `$Key /persistent:yes

# --- SmbGlobalMapping ---
`$user = "`$env:COMPUTERNAME\`$Storage"
`$sec  = ConvertTo-SecureString `$Key -AsPlainText -Force
`$cred = [pscredential]::new(`$user,`$sec)

New-SmbGlobalMapping ``
    -RemotePath "\\`${Storage}.file.core.windows.net\`$Share" ``
    -LocalPath  X: ``
    -Credential `$cred ``
    -Persistent `$true

Write-Host "`n✅ ドライブ マッピング完了！Z: = net use、X: = SmbGlobalMapping" -ForegroundColor Green
############################################
"@

# ========= 5) 画面に出力 =========
Write-Host ""
Write-Host "===== ★ コピーして VM に貼り付け！★ =====" -ForegroundColor Cyan
Write-Host $PasteBlock -ForegroundColor Yellow
Write-Host "===== ★ 以上 ★ =====" -ForegroundColor Cyan

# ========= 6) 完了メッセージ =========
$ip = ($vm | ConvertFrom-Json).publicIpAddress
Write-Host "`n🚀 準備完了！RDP → $ip (ユーザー: $AdminUser)" -ForegroundColor Green