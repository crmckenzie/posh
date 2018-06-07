function Out-Data(){
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Name,

        [Alias("Value")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Title
    )
    
    Begin {
        write-host "Begin" -ForegroundColor Green
    }

    Process {
        write-host "Name: $Name; Title: $Title;"
        return $Name
    }

    End {
        write-host "End" -ForegroundColor Green
    }
}