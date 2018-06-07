function Filter-Data(){
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)][string] $Name
    )

    Begin {
        write-host "Begin" -ForegroundColor Yellow
    }
    Process {
        if (($Name.Length %2) -eq 0) {
            return $Name
        }
        return;
    }
    End {
        write-host "End" -ForegroundColor Yellow
    }
}