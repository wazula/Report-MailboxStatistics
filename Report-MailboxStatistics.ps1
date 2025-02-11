$Group = "Domain Users"
$CountTopFolder = 10
$ReportMailboxSizeInMB = 5000

$SMTPServer = "smtp.domain.tld"
$From = "postfachbericht@domain.tld"
$Subject = "Postfach Übersicht"

[System.Collections.ArrayList]$MailboxStatistics = @()
$GroupMembers = Get-ADGroup $Group | Get-ADGroupMember -Recursive | Get-ADUser -Properties msExchMailboxGuid | where {$_.msExchMailboxGuid -ne $Null}
foreach ($GroupMember in $GroupMembers) {
 $Mailbox = get-mailbox $GroupMember.SamAccountName
 $EMail = $Mailbox.PrimarySmtpAddress.Address
 $Stats = $Mailbox | Get-MailboxStatistics | select displayname, @{label="Size"; expression={$_.TotalItemSize.Value.ToMB()}}
 $Displayname = $Stats.Displayname
 $MailboxSize = $Stats.Size
 if ($MailboxSize -ge $ReportMailboxSizeInMB) {
  $MailboxFolderStatistics = Get-MailboxFolderStatistics $mailbox | select FolderPath,FolderSize,ItemsInFolder
  $TopFoldersBySize = $MailboxFolderStatistics | Select-Object FolderPath,@{Name="Foldersize";Expression={ [long]$a = "{0:N2}" -f ((($_.FolderSize -replace "[0-9\.]+ [A-Z]* \(([0-9,]+) bytes\)","`$1") -replace ",","")); [math]::Round($a/1MB,2) }}  | sort foldersize -Descending | select -first $CountTopFolder
  $TopFoldersByItems = $MailboxFolderStatistics | sort ItemsInFolder -Descending | select -first $CountTopFolder
 
  $Statistic = [PSCustomObject]@{
	 DisplayName = $Displayname
	 EMail = $EMail
	 MailboxSize = $MailboxSize
	 TopFoldersBySize = $TopFoldersBySize
	 TopFoldersByItems = $TopFoldersByItems
	}
  $MailboxStatistics.Add($Statistic) | out-null
 }
}

foreach ($MailboxStatistic in $MailboxStatistics) {
 $MailBody = '<!DOCTYPE html>
 <html lang="de">
  <head>
   <title>Mailbox Report</title>
   <style>
    body {font-family: Calibri;}
    td {width:100px; max-width:300px; background-color:white;}
    table {width:100%;}
    th {text-align:left; font-size:12pt; background-color:lightgrey;}
   </style>
  </head>
 <body>
  <h2>Mailboxstatistik: '+ $Displayname +'</h2>'
 
 $MailboxSize = $MailboxStatistic.MailboxSize
 $MailBody += '<div><p>Ihr Postfach ist '
 $MailBody += $MailboxSize
 $MailBody += ' MB gro&szlig;, bitte l&ouml;schen Sie nicht mehr ben&ouml;tigte Daten aus Ihrem Postfach.</p></div>'
 
 $TopFoldersBySize = $MailboxStatistic.TopFoldersBySize | select @{label="Ordnerpfad"; expression={$_.Folderpath}}, @{label="Größe"; expression={$str = $_.Foldersize; [string]$str + " MB"}} | ConvertTo-Html -Fragment
 $MailBody += '<div><p>Dies ist eine &Uuml;bersicht ihrer '
 $MailBody += $CountTopFolder
 $MailBody += ' gr&ouml;&szlig;ten Ordner in ihrem Postfach:</p></div>'
 $MailBody += $TopFoldersBySize
 
 $TopFoldersByItems = $MailboxStatistic.TopFoldersByItems | select @{label="Ordnerpfad"; expression={$_.Folderpath}}, @{label="Anzahl Elemente"; expression={$_.ItemsInFolder}} | ConvertTo-Html -Fragment
 $MailBody += '<div><p>Ordner mit vielen Elementen beeintr&auml;chtigen die Outlook Geschwindigkeit, l&ouml;schen Sie nicht mehr ben&ouml;tigte Elemente um Outlook nicht zu verlangsamen. Dies sind Ihre '
 $MailBody += $CountTopFolder
 $MailBody +=' Ordner mit den meisten Elementen:</p></div>'
 $MailBody += $TopFoldersByItems
 
 $MailBody += '<div><p>Hier finden Sie weitere Informationen: https://www.frankysweb.de</p></div>'
 $MailBody += '<div><p>Vielen Dank f&uuml;r Ihre Mithilfe</p></div>'
 
 $MailBody += '</body>
  </html>'
 
 $To =  $MailboxStatistic.EMail
 Send-MailMessage -SmtpServer $SMTPServer -From $From -To $To -Body $MailBody -BodyAsHtml -Encoding UTF8 -Subject $Subject
}
