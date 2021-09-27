Get-ChildItem -Recurse -Filter * | Where-Object {$_.PsIsContainer -eq $True -and ($_.Name -NotLike ".git*" -and $_.Name -NotLike "images*" -and $_.Name -NotLike "tanzu-clusters*") } | 
Foreach-Object { 
	$folder=$_.FullName
	Write-Output "processing dir ... $folder"

	Get-ChildItem $folder\* -Include *.sh, *.yaml |
		Foreach-Object {
			$original_file =$_.FullName
			Write-Output "processing $original_file..."
			$text = [IO.File]::ReadAllText($original_file) -replace "`r`n", "`n"
			[IO.File]::WriteAllText($original_file, $text)
		}
}