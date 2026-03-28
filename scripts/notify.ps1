param(
  [Parameter(Position = 0)]
  [string]$Text = '任务完成'
)

Import-Module BurntToast -ErrorAction Stop
New-BurntToastNotification -Text $Text
