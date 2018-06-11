gci *.ps1 -path export,private -Recurse | %{
    . $_.FullName
}

gci *.ps1 -path export -Recurse | %{
    Export-ModuleMember $_.BaseName
}

