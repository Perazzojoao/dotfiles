param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Body
)

$appId = "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App"
$escapedTitle = [System.Security.SecurityElement]::Escape($Title)
$escapedBody = [System.Security.SecurityElement]::Escape($Body)
$toastXml = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedTitle</text>
      <text>$escapedBody</text>
    </binding>
  </visual>
</toast>
"@

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)

Start-Sleep -Milliseconds 500
