# Load all the functions in
$global:moduleRoot = split-path $MyInvocation.MyCommand.Path
$filesToLoad = gci *.ps1 -path export,private -Recurse

$FilesToLoad | %{
    . $_.Fullname

    if (-not ($_.FullName.Contains("Private"))) {
        write-host "Exporting $($_.Name)"
        Export-ModuleMember $_.BaseName
    }
}

